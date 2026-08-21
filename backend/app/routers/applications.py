"""
Facility onboarding: a hospital/clinic applies for access, admin reviews and
approves/rejects it.

Submission is unauthenticated -- the applicant has no account yet. Review is
admin-only. There is no email/notification infrastructure in this project,
so approval returns a one-time generated password directly in the response;
admin communicates it out-of-band, and the account must change it on first
login (Doctor.must_change_password, enforced via POST /auth/change-password).
"""

import secrets
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import require_role
from app.auth import hash_password
from app.models import Doctor, Facility, FacilityApplication
from app.schemas import (
    ApplicationApproveResponse,
    ApplicationRejectRequest,
    FacilityApplicationCreate,
    FacilityApplicationOut,
)

router = APIRouter(tags=["applications"])

admin_user = require_role("admin")


@router.post(
    "/applications",
    response_model=FacilityApplicationOut,
    status_code=status.HTTP_201_CREATED,
)
def submit_application(body: FacilityApplicationCreate, db: Session = Depends(get_session)):
    """Public: a facility with no account yet requests access."""
    application = FacilityApplication(
        facility_name=body.facility_name,
        facility_type=body.facility_type,
        district=body.district,
        state=body.state,
        contact_name=body.contact_name,
        contact_email=body.contact_email,
        contact_phone=body.contact_phone,
        license_no=body.license_no,
        requested_role=body.requested_role,
    )
    db.add(application)
    db.commit()
    db.refresh(application)
    return application


@router.get("/admin/applications", response_model=list[FacilityApplicationOut])
def list_applications(
    status_filter: str | None = None,
    db: Session = Depends(get_session),
    user: Doctor = Depends(admin_user),
):
    query = db.query(FacilityApplication)
    if status_filter:
        query = query.filter(FacilityApplication.status == status_filter)
    return query.order_by(FacilityApplication.submitted_at.desc()).all()


def _get_pending_application(db: Session, application_id: str) -> FacilityApplication:
    application = (
        db.query(FacilityApplication)
        .filter(FacilityApplication.application_id == application_id)
        .first()
    )
    if application is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Application not found")
    if application.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Application has already been {application.status}.",
        )
    return application


@router.post("/admin/applications/{application_id}/approve", response_model=ApplicationApproveResponse)
def approve_application(
    application_id: str,
    db: Session = Depends(get_session),
    user: Doctor = Depends(admin_user),
):
    """
    Provisions a Facility (if this applicant's facility doesn't already
    exist) and a Doctor account with the requested role, plus a one-time
    password the caller must relay to the applicant out-of-band.
    """
    application = _get_pending_application(db, application_id)

    if db.query(Doctor).filter_by(email=application.contact_email).first() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account already exists for this email.",
        )

    facility = (
        db.query(Facility)
        .filter_by(name=application.facility_name, district=application.district)
        .first()
    )
    if facility is None:
        facility = Facility(
            name=application.facility_name,
            type=application.facility_type,
            district=application.district,
            state=application.state,
        )
        db.add(facility)
        db.flush()

    temporary_password = secrets.token_urlsafe(12)
    doctor = Doctor(
        name=application.contact_name,
        facility_id=facility.facility_id,
        license_no=application.license_no,
        role=application.requested_role,
        email=application.contact_email,
        password_hash=hash_password(temporary_password),
        must_change_password=True,
    )
    db.add(doctor)
    db.flush()

    application.status = "approved"
    application.reviewed_by = user.doctor_id
    application.reviewed_at = datetime.utcnow()
    application.created_facility_id = facility.facility_id
    application.created_doctor_id = doctor.doctor_id

    db.commit()
    db.refresh(application)

    return ApplicationApproveResponse(
        application=FacilityApplicationOut.model_validate(application),
        facility_id=facility.facility_id,
        doctor_id=doctor.doctor_id,
        email=doctor.email,
        temporary_password=temporary_password,
    )


@router.post("/admin/applications/{application_id}/reject", response_model=FacilityApplicationOut)
def reject_application(
    application_id: str,
    body: ApplicationRejectRequest,
    db: Session = Depends(get_session),
    user: Doctor = Depends(admin_user),
):
    application = _get_pending_application(db, application_id)

    application.status = "rejected"
    application.reviewed_by = user.doctor_id
    application.reviewed_at = datetime.utcnow()
    application.rejection_reason = body.reason

    db.commit()
    db.refresh(application)
    return application
