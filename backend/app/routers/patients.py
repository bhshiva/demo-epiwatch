from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import require_role
from app.models import Doctor, LabResult, Patient, PatientIdentity, PatientReport
from app.schemas import (
    AbhaVerifyRequest,
    AbhaVerifyResponse,
    PatientHistoryEntry,
    PatientMatchCandidate,
    PatientMatchRequest,
    PatientSearchResult,
)
from app.services.crypto import PGCRYPTO_KEY, decrypt_date, decrypt_field
from app.services.patient_matching import MatchCriteria, find_candidates
from app.services.abha import (
    AbdmClient,
    AbdmNotConfigured,
    AbdmUnavailable,
    validate_abha,
)

router = APIRouter(prefix="/patients", tags=["patients"])
# Health authority and admin have their own surfaces; identifiable patient
# data is a doctor/lab clinical concern.
clinical_user = require_role("doctor", "lab", "health_authority", "admin")


@router.get("/search", response_model=list[PatientSearchResult])
def search_patients(
    q: str = Query("", description="Name or facility MRN fragment"),
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    """
    Find patients previously seen at the caller's facility (or across facilities for health authority/admin).
    If no query is provided, returns the most recent 25 patients.
    """
    term = f"%{q.strip().lower()}%" if q.strip() else ""
    decrypted_name = func.pgp_sym_decrypt(PatientIdentity.full_name, PGCRYPTO_KEY)
    decrypted_mrn = func.pgp_sym_decrypt(PatientIdentity.facility_mrn, PGCRYPTO_KEY)
    decrypted_contact = func.pgp_sym_decrypt(PatientIdentity.contact_number, PGCRYPTO_KEY)

    report_stats = (
        select(
            PatientReport.patient_id.label("patient_id"),
            func.count(PatientReport.report_id).label("report_count"),
            func.max(PatientReport.report_date).label("last_visit"),
        )
        .group_by(PatientReport.patient_id)
        .subquery()
    )

    base_query = (
        db.query(PatientIdentity, Patient, report_stats.c.report_count, report_stats.c.last_visit)
        .join(Patient, Patient.patient_id == PatientIdentity.patient_id)
        .outerjoin(report_stats, report_stats.c.patient_id == PatientIdentity.patient_id)
    )

    facility_query = base_query
    if doctor.facility_id is not None:
        facility_query = base_query.filter(PatientIdentity.facility_id == doctor.facility_id)

    if term:
        filter_expr = (
            func.lower(decrypted_name).like(term)
            | func.lower(func.coalesce(decrypted_mrn, "")).like(term)
            | func.coalesce(PatientIdentity.abha_id, "").like(term)
            | func.right(
                func.regexp_replace(func.coalesce(decrypted_contact, ""), r"\D", "", "g"),
                10,
            ).like(term)
        )
        rows = (
            facility_query.filter(filter_expr)
            .order_by(report_stats.c.last_visit.desc().nullslast(), decrypted_name)
            .limit(25)
            .all()
        )
        if not rows and doctor.facility_id is not None:
            rows = (
                base_query.filter(filter_expr)
                .order_by(report_stats.c.last_visit.desc().nullslast(), decrypted_name)
                .limit(25)
                .all()
            )
    else:
        rows = (
            facility_query.order_by(report_stats.c.last_visit.desc().nullslast(), decrypted_name)
            .limit(25)
            .all()
        )
        if not rows and doctor.facility_id is not None:
            rows = (
                base_query.order_by(report_stats.c.last_visit.desc().nullslast(), decrypted_name)
                .limit(25)
                .all()
            )

    return [
        PatientSearchResult(
            patient_id=identity.patient_id,
            full_name=decrypt_field(db, identity.full_name),
            exact_age=_current_age(patient, decrypt_date(db, identity.date_of_birth)),
            age_group=patient.age_group,
            sex=patient.sex,
            district=patient.district,
            facility_mrn=decrypt_field(db, identity.facility_mrn),
            abha_id=identity.abha_id,
            report_count=count or 0,
            last_visit=last_visit,
        )
        for identity, patient, count, last_visit in rows
    ]


@router.post("/match", response_model=list[PatientMatchCandidate])
def match_patients(
    body: PatientMatchRequest,
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    """
    Possible duplicates for a patient about to be registered, scored and
    explained. Advisory only -- the enforcement lives in POST /reports, so a
    client that skips this call still cannot create a duplicate silently.
    """
    candidates = find_candidates(
        db,
        doctor.facility_id,
        MatchCriteria(
            full_name=body.full_name,
            date_of_birth=body.date_of_birth,
            exact_age=body.exact_age,
            sex=body.sex,
            contact_number=body.contact_number,
            facility_mrn=body.facility_mrn,
            abha_id=body.abha_id,
            district=body.district,
        ),
    )
    return [PatientMatchCandidate(**vars(c)) for c in candidates]


@router.post("/verify-abha", response_model=AbhaVerifyResponse)
async def verify_abha(
    body: AbhaVerifyRequest,
    doctor: Doctor = Depends(clinical_user),
):
    """
    Check an ABHA number: format and checksum locally, then the national
    registry when ABDM is configured and reachable.

    Never fails the request outright. A clinic with no connectivity, or before
    ABDM credentials are issued, still gets the offline checksum result and can
    continue working -- refusing to register a patient because a government API
    is down would be worse than the problem it solves.
    """
    validation = validate_abha(body.abha_number)

    if not validation.is_valid:
        return AbhaVerifyResponse(
            abha_number=validation.normalised,
            is_valid=False,
            message=validation.reason,
        )

    client = AbdmClient()
    if not client.is_configured:
        return AbhaVerifyResponse(
            abha_number=validation.normalised,
            is_valid=True,
            verified=False,
            message="Number format is valid. ABDM verification is not configured.",
        )

    try:
        profile = await client.verify_abha(validation.normalised or "")
    except (AbdmUnavailable, AbdmNotConfigured) as exc:
        return AbhaVerifyResponse(
            abha_number=validation.normalised,
            is_valid=True,
            verified=False,
            message=str(exc),
        )

    return AbhaVerifyResponse(
        abha_number=profile.abha_number,
        is_valid=True,
        verified=True,
        name=profile.name,
        gender=profile.gender,
        date_of_birth=profile.date_of_birth,
        state_name=profile.state_name,
        district_name=profile.district_name,
        message="Verified against ABDM.",
    )


@router.get("/{patient_id}/history", response_model=list[PatientHistoryEntry])
def patient_history(
    patient_id: str,
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    """Prior reports for one patient, restricted to the caller's facility."""
    identity = (
        db.query(PatientIdentity)
        .filter(PatientIdentity.patient_id == patient_id)
        .first()
    )

    # Refuse rather than leak: a patient registered at another facility is not
    # this doctor's to read, and an unregistered id has no clinical record here.
    if identity is None or identity.facility_id != doctor.facility_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    reports = (
        db.query(PatientReport, LabResult)
        .outerjoin(LabResult, LabResult.report_id == PatientReport.report_id)
        .filter(PatientReport.patient_id == patient_id)
        .order_by(PatientReport.report_date.desc())
        .all()
    )

    return [
        PatientHistoryEntry(
            report_id=report.report_id,
            report_date=report.report_date,
            diagnosis=report.diagnosis,
            diagnosis_status=report.diagnosis_status,
            complaints=decrypt_field(db, report.complaints),
            pathogen=lab.pathogen if lab else None,
            culture_result=lab.culture_result if lab else None,
            ast_result=lab.ast_result if lab else None,
        )
        for report, lab in reports
    ]


def _current_age(patient: Patient, dob: date | None) -> int | None:
    """
    Prefer age derived from date of birth so it stays correct on return
    visits; fall back to the age recorded at registration.

    Takes an already-decrypted date rather than the PatientIdentity row
    directly -- date_of_birth is encrypted at rest, and this stays a plain
    date-arithmetic function rather than also owning the decrypt call.
    """
    if dob is not None:
        today = date.today()
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return patient.exact_age
