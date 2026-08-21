from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.db import get_session
from app.deps import require_role
from app.models import AstResult, Doctor, IsolateStrainLink, LabIsolate, StrainCluster
from app.schemas import (
    IsolateCreate,
    IsolateOut,
    LabSummary,
    StrainClusterCreate,
    StrainClusterOut,
)
from app.services.antibiotics import antibiotic_class, is_mdr

router = APIRouter(prefix="/lab", tags=["lab"])

# A laboratory user owns this workflow. Admin no longer gets a lab-access
# backdoor here: its role is facility onboarding, not patient/isolate data.
lab_user = require_role("lab")


def _decorate(isolate: LabIsolate) -> IsolateOut:
    """Attach derived counts so every caller reads the same definitions."""
    scored = [a for a in isolate.ast_results if a.ast_result in ("Resistant", "Susceptible", "Intermediate")]
    resistant = [a for a in scored if a.ast_result == "Resistant"]
    resistant_classes = {antibiotic_class(a.antibiotic) or a.antibiotic for a in resistant}

    out = IsolateOut.model_validate(isolate)
    out.tested_count = len(scored)
    out.resistant_count = len(resistant)
    out.is_mdr = is_mdr(resistant_classes)
    return out


@router.post("/isolates", response_model=IsolateOut, status_code=status.HTTP_201_CREATED)
def create_isolate(
    body: IsolateCreate,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Record a culture result and its susceptibility panel."""
    duplicates = {a.antibiotic for a in body.ast_results}
    if len(duplicates) != len(body.ast_results):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Each antibiotic may appear only once in a panel.",
        )

    isolate = LabIsolate(
        report_id=body.report_id,
        patient_id=body.patient_id,
        facility_id=user.facility_id,
        lab_user_id=user.doctor_id,
        accession_no=body.accession_no,
        collection_date=body.collection_date,
        test_date=body.test_date or date.today(),
        specimen_type=body.specimen_type,
        specimen_type_other=body.specimen_type_other,
        culture_result=body.culture_result,
        culture_result_other=body.culture_result_other,
        pathogen=body.pathogen,
        pathogen_other=body.pathogen_other,
        infection_origin=body.infection_origin,
        status=body.status,
        notes=body.notes,
    )

    for entry in body.ast_results:
        isolate.ast_results.append(
            AstResult(
                antibiotic=entry.antibiotic,
                # Derive the class when the caller omits it, so MDR counting
                # and class-level analytics stay consistent.
                antibiotic_class=entry.antibiotic_class or antibiotic_class(entry.antibiotic),
                ast_result=entry.ast_result,
                mic_value=entry.mic_value,
                mic_operator=entry.mic_operator,
                zone_diameter_mm=entry.zone_diameter_mm,
                method=entry.method,
            )
        )

    db.add(isolate)
    db.commit()
    db.refresh(isolate)
    return _decorate(isolate)


@router.get("/isolates", response_model=list[IsolateOut])
def list_isolates(
    status_filter: str | None = Query(default=None, alias="status"),
    pathogen: str | None = None,
    q: str | None = Query(default=None, description="Accession number fragment"),
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Isolates for the caller's own facility, newest first."""
    query = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.facility_id == user.facility_id)
    )

    if status_filter:
        query = query.filter(LabIsolate.status == status_filter)
    if pathogen:
        query = query.filter(LabIsolate.pathogen == pathogen)
    if q:
        query = query.filter(func.lower(func.coalesce(LabIsolate.accession_no, "")).like(f"%{q.lower()}%"))

    rows = query.order_by(LabIsolate.created_at.desc()).limit(limit).all()
    return [_decorate(r) for r in rows]


@router.get("/worklist", response_model=list[IsolateOut])
def worklist(
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Cultures still awaiting a final result, oldest first."""
    rows = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.facility_id == user.facility_id)
        .filter(LabIsolate.status.in_(["pending", "preliminary"]))
        .order_by(LabIsolate.created_at.asc())
        .all()
    )
    return [_decorate(r) for r in rows]


@router.get("/summary", response_model=LabSummary)
def summary(
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Headline counts for the laboratory dashboard."""
    today = date.today()
    week_ago = today - timedelta(days=7)
    facility = user.facility_id

    isolates_today = (
        db.query(func.count(LabIsolate.isolate_id))
        .filter(LabIsolate.facility_id == facility, LabIsolate.test_date == today)
        .scalar()
        or 0
    )

    pending = (
        db.query(func.count(LabIsolate.isolate_id))
        .filter(LabIsolate.facility_id == facility, LabIsolate.status.in_(["pending", "preliminary"]))
        .scalar()
        or 0
    )

    recent = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.facility_id == facility, LabIsolate.test_date >= week_ago)
        .all()
    )

    mdr = sum(1 for i in recent if _decorate(i).is_mdr)

    tested = sum(
        1
        for i in recent
        for a in i.ast_results
        if a.ast_result in ("Resistant", "Susceptible", "Intermediate")
    )
    resistant = sum(1 for i in recent for a in i.ast_results if a.ast_result == "Resistant")

    return LabSummary(
        isolates_today=isolates_today,
        pending_cultures=pending,
        mdr_isolates_week=mdr,
        # "Not tested" is excluded from the denominator; including it would
        # understate resistance whenever a panel is partially run.
        resistance_rate_week=round(resistant / tested, 4) if tested else None,
    )


@router.get("/isolates/{isolate_id}", response_model=IsolateOut)
def get_isolate(
    isolate_id: str,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    isolate = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.isolate_id == isolate_id)
        .first()
    )
    if isolate is None or isolate.facility_id != user.facility_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Isolate not found")
    return _decorate(isolate)


@router.patch("/isolates/{isolate_id}", response_model=IsolateOut)
def amend_isolate(
    isolate_id: str,
    body: IsolateCreate,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """
    Supersede a result with a corrected one.

    Written as a new row linked by amended_from rather than an in-place update:
    an AST result a clinician already prescribed against is exactly what an
    audit has to be able to reconstruct.
    """
    original = db.query(LabIsolate).filter(LabIsolate.isolate_id == isolate_id).first()
    if original is None or original.facility_id != user.facility_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Isolate not found")
    if original.status == "amended":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This result has already been superseded; amend the current one.",
        )

    corrected = LabIsolate(
        report_id=body.report_id or original.report_id,
        patient_id=body.patient_id or original.patient_id,
        facility_id=original.facility_id,
        lab_user_id=user.doctor_id,
        accession_no=body.accession_no or original.accession_no,
        collection_date=body.collection_date or original.collection_date,
        test_date=body.test_date or original.test_date,
        specimen_type=body.specimen_type,
        specimen_type_other=body.specimen_type_other,
        culture_result=body.culture_result,
        culture_result_other=body.culture_result_other,
        pathogen=body.pathogen,
        pathogen_other=body.pathogen_other,
        infection_origin=body.infection_origin,
        status=body.status if body.status != "preliminary" else "final",
        notes=body.notes,
        amended_from=original.isolate_id,
    )
    for entry in body.ast_results:
        corrected.ast_results.append(
            AstResult(
                antibiotic=entry.antibiotic,
                antibiotic_class=entry.antibiotic_class or antibiotic_class(entry.antibiotic),
                ast_result=entry.ast_result,
                mic_value=entry.mic_value,
                mic_operator=entry.mic_operator,
                zone_diameter_mm=entry.zone_diameter_mm,
                method=entry.method,
            )
        )

    original.status = "amended"
    db.add(corrected)
    db.commit()
    db.refresh(corrected)
    return _decorate(corrected)


@router.post("/isolates/{isolate_id}/link", response_model=IsolateOut)
def link_to_report(
    isolate_id: str,
    report_id: str,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Attach a standalone lab result to a clinician's report after the fact."""
    isolate = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.isolate_id == isolate_id)
        .first()
    )
    if isolate is None or isolate.facility_id != user.facility_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Isolate not found")

    isolate.report_id = report_id
    db.commit()
    db.refresh(isolate)
    return _decorate(isolate)


def _decorate_strain(strain: StrainCluster) -> StrainClusterOut:
    out = StrainClusterOut.model_validate(strain)
    out.isolate_count = len(strain.links)
    return out


@router.post("/strains", response_model=StrainClusterOut, status_code=status.HTTP_201_CREATED)
def create_strain(
    body: StrainClusterCreate,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Name a new strain cluster, e.g. once sequencing/epi-linkage identifies one."""
    strain = StrainCluster(
        pathogen=body.pathogen,
        designation=body.designation,
        clonal_group=body.clonal_group,
        facility_id=user.facility_id,
        notes=body.notes,
    )
    db.add(strain)
    db.commit()
    db.refresh(strain)
    return _decorate_strain(strain)


@router.get("/strains", response_model=list[StrainClusterOut])
def list_strains(
    pathogen: str | None = None,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """
    Strains visible to this facility: ones it started, plus any it has since
    linked an isolate to (a cluster can span facilities once recognised).
    """
    query = (
        db.query(StrainCluster)
        .options(selectinload(StrainCluster.links))
        .outerjoin(IsolateStrainLink, IsolateStrainLink.strain_id == StrainCluster.strain_id)
        .outerjoin(LabIsolate, LabIsolate.isolate_id == IsolateStrainLink.isolate_id)
        .filter(
            (StrainCluster.facility_id == user.facility_id)
            | (LabIsolate.facility_id == user.facility_id)
        )
        .distinct()
    )
    if pathogen:
        query = query.filter(StrainCluster.pathogen == pathogen)
    rows = query.order_by(StrainCluster.first_detected_at.desc()).all()
    return [_decorate_strain(s) for s in rows]


@router.post("/isolates/{isolate_id}/strain-link", response_model=StrainClusterOut)
def link_isolate_to_strain(
    isolate_id: str,
    strain_id: str,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """Assign an isolate to a strain cluster. Reassignment adds a new link row."""
    isolate = db.query(LabIsolate).filter(LabIsolate.isolate_id == isolate_id).first()
    if isolate is None or isolate.facility_id != user.facility_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Isolate not found")

    strain = (
        db.query(StrainCluster)
        .options(selectinload(StrainCluster.links))
        .filter(StrainCluster.strain_id == strain_id)
        .first()
    )
    if strain is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Strain not found")

    existing = (
        db.query(IsolateStrainLink)
        .filter_by(isolate_id=isolate.isolate_id, strain_id=strain.strain_id)
        .first()
    )
    if existing is None:
        db.add(
            IsolateStrainLink(
                isolate_id=isolate.isolate_id,
                strain_id=strain.strain_id,
                assigned_by=user.doctor_id,
            )
        )
        db.commit()
        db.refresh(strain)

    return _decorate_strain(strain)


@router.get("/strains/{strain_id}/isolates", response_model=list[IsolateOut])
def strain_isolates(
    strain_id: str,
    db: Session = Depends(get_session),
    user: Doctor = Depends(lab_user),
):
    """
    This facility's isolates linked to the strain, for outbreak-cluster review.

    Deliberately facility-scoped, matching every other lab.py read: a lab
    user sees its own facility's data, never another facility's, even for a
    strain that spans multiple facilities. The cross-facility view of a
    strain's full spread belongs to the Health Authority surveillance
    endpoints, not here.
    """
    rows = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .join(IsolateStrainLink, IsolateStrainLink.isolate_id == LabIsolate.isolate_id)
        .filter(IsolateStrainLink.strain_id == strain_id)
        .filter(LabIsolate.facility_id == user.facility_id)
        .order_by(LabIsolate.created_at.desc())
        .all()
    )
    return [_decorate(r) for r in rows]
