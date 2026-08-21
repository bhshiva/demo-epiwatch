from datetime import date
from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import require_role
from app.models import Doctor, PatientReport
from app.schemas import DashboardSummary

router = APIRouter(prefix="/dashboard", tags=["dashboard"])

# Health authority and admin have their own surfaces (surveillance API,
# application review); this dashboard is a doctor/lab clinical view.
clinical_user = require_role("doctor", "lab")


@router.get("/summary", response_model=DashboardSummary)
def summary(
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    today = date.today()

    patients_today = (
        db.query(func.count(PatientReport.report_id))
        .filter(PatientReport.doctor_id == doctor.doctor_id, PatientReport.report_date == today)
        .scalar()
    )

    reports_total = (
        db.query(func.count(PatientReport.report_id))
        .filter(PatientReport.doctor_id == doctor.doctor_id)
        .scalar()
    )

    active_conditions = (
        db.query(func.count(func.distinct(PatientReport.diagnosis)))
        .filter(PatientReport.doctor_id == doctor.doctor_id, PatientReport.diagnosis.isnot(None))
        .scalar()
    )

    return DashboardSummary(
        patients_today=patients_today or 0,
        reports_submitted_total=reports_total or 0,
        active_conditions=active_conditions or 0,
    )
