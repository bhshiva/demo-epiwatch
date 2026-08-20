from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import get_current_doctor
from app.models import Doctor, LabResult, Patient, PatientIdentity, PatientReport
from app.schemas import (
    AbhaVerifyRequest,
    AbhaVerifyResponse,
    PatientHistoryEntry,
    PatientMatchCandidate,
    PatientMatchRequest,
    PatientSearchResult,
)
from app.services.patient_matching import MatchCriteria, find_candidates
from app.services.abha import (
    AbdmClient,
    AbdmNotConfigured,
    AbdmUnavailable,
    validate_abha,
)

router = APIRouter(prefix="/patients", tags=["patients"])


@router.get("/search", response_model=list[PatientSearchResult])
def search_patients(
    q: str = Query(min_length=1, description="Name or facility MRN fragment"),
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(get_current_doctor),
):
    """
    Find patients previously seen at the caller's own facility.

    Facility scoping comes from the authenticated doctor, never from the
    request, so one facility cannot enumerate another's patients.
    """
    term = f"%{q.strip().lower()}%"

    report_stats = (
        select(
            PatientReport.patient_id.label("patient_id"),
            func.count(PatientReport.report_id).label("report_count"),
            func.max(PatientReport.report_date).label("last_visit"),
        )
        .group_by(PatientReport.patient_id)
        .subquery()
    )

    rows = (
        db.query(PatientIdentity, Patient, report_stats.c.report_count, report_stats.c.last_visit)
        .join(Patient, Patient.patient_id == PatientIdentity.patient_id)
        .outerjoin(report_stats, report_stats.c.patient_id == PatientIdentity.patient_id)
        .filter(PatientIdentity.facility_id == doctor.facility_id)
        .filter(
            func.lower(PatientIdentity.full_name).like(term)
            | func.lower(func.coalesce(PatientIdentity.facility_mrn, "")).like(term)
            | func.coalesce(PatientIdentity.abha_id, "").like(term)
            # A clinician holding the phone number should not have to guess
            # the spelling of the name.
            | func.right(
                func.regexp_replace(
                    func.coalesce(PatientIdentity.contact_number, ""), r"\D", "", "g"
                ),
                10,
            ).like(term)
        )
        .order_by(PatientIdentity.full_name)
        .limit(20)
        .all()
    )

    return [
        PatientSearchResult(
            patient_id=identity.patient_id,
            full_name=identity.full_name,
            exact_age=_current_age(patient, identity),
            age_group=patient.age_group,
            sex=patient.sex,
            district=patient.district,
            facility_mrn=identity.facility_mrn,
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
    doctor: Doctor = Depends(get_current_doctor),
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
    doctor: Doctor = Depends(get_current_doctor),
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
    doctor: Doctor = Depends(get_current_doctor),
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
            complaints=report.complaints,
            pathogen=lab.pathogen if lab else None,
            culture_result=lab.culture_result if lab else None,
            ast_result=lab.ast_result if lab else None,
        )
        for report, lab in reports
    ]


def _current_age(patient: Patient, identity: PatientIdentity) -> int | None:
    """
    Prefer age derived from date of birth so it stays correct on return
    visits; fall back to the age recorded at registration.
    """
    if identity.date_of_birth is not None:
        today = date.today()
        dob = identity.date_of_birth
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
    return patient.exact_age
