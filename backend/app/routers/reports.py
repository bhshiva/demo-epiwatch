from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import require_role
from app.models import (
    AstResult,
    Doctor,
    LabIsolate,
    LabResult,
    Patient,
    PatientIdentity,
    PatientReport,
    Prescription,
)
from app.services.antibiotics import ANTIBIOTIC_CLASS
from app.schemas import PatientMatchCandidate, ReportCreateRequest, ReportResponse
from app.services.crypto import decrypt_field, encrypt_date, encrypt_field, hash_field
from app.services.patient_matching import (
    MatchCriteria,
    blocking_candidates,
    find_candidates,
    normalise_digits,
)
from sqlalchemy.exc import IntegrityError

router = APIRouter(prefix="/reports", tags=["reports"])

# Health authority and admin have their own surfaces; reports are a
# doctor/lab clinical concern.
clinical_user = require_role("doctor", "lab")


@router.post("", response_model=ReportResponse)
def create_report(
    body: ReportCreateRequest,
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    patient = _resolve_patient(body, db, doctor)

    report = PatientReport(
        patient_id=patient.patient_id,
        doctor_id=doctor.doctor_id,
        facility_id=doctor.facility_id,
        report_date=body.report_date,
        complaints=encrypt_field(db, body.complaints),
        medical_history=encrypt_field(db, body.medical_history),
        symptoms={"items": body.symptoms},
        diagnosis=body.diagnosis,
        diagnosis_status=body.diagnosis_status,
        treatment=encrypt_field(db, body.treatment),
        infection_syndrome=body.infection_syndrome,
        infection_syndrome_other=body.infection_syndrome_other,
        infection_origin=body.infection_origin,
        patient_outcome=body.patient_outcome,
        patient_outcome_other=body.patient_outcome_other,
    )
    db.add(report)
    db.flush()

    for rx in body.prescriptions:
        db.add(Prescription(report_id=report.report_id, drug_name=rx.drug_name, dosage=rx.dosage, duration=rx.duration))

    if body.lab_result is not None:
        lr = body.lab_result
        db.add(LabResult(
            report_id=report.report_id,
            facility_id=doctor.facility_id,
            test_date=lr.test_date,
            specimen_type=lr.specimen_type,
            specimen_type_other=lr.specimen_type_other,
            culture_result=lr.culture_result,
            culture_result_other=lr.culture_result_other,
            pathogen=lr.pathogen,
            pathogen_other=lr.pathogen_other,
            antibiotic=lr.antibiotic,
            ast_result=lr.ast_result,
        ))

        # Dual-write into the isolate/AST model. raw.lab_results is kept in
        # step for one release so the existing doctor client keeps working
        # unchanged, while analytics reads only the new shape.
        isolate = LabIsolate(
            report_id=report.report_id,
            patient_id=patient.patient_id,
            facility_id=doctor.facility_id,
            lab_user_id=doctor.doctor_id,
            test_date=lr.test_date,
            specimen_type=lr.specimen_type,
            specimen_type_other=lr.specimen_type_other,
            culture_result=lr.culture_result,
            culture_result_other=lr.culture_result_other,
            pathogen=lr.pathogen,
            pathogen_other=lr.pathogen_other,
            infection_origin=body.infection_origin,
            status="final",
        )
        db.add(isolate)
        db.flush()

        # A doctor-entered result carries at most one drug; a full panel comes
        # from the laboratory via /lab/isolates.
        if lr.antibiotic:
            db.add(AstResult(
                isolate_id=isolate.isolate_id,
                antibiotic=lr.antibiotic,
                antibiotic_class=ANTIBIOTIC_CLASS.get(lr.antibiotic),
                ast_result=lr.ast_result,
            ))

    db.commit()
    db.refresh(report)
    return _decorate_report(db, report)


@router.get("", response_model=list[ReportResponse])
def list_reports(
    db: Session = Depends(get_session),
    doctor: Doctor = Depends(clinical_user),
):
    reports = (
        db.query(PatientReport)
        .filter_by(doctor_id=doctor.doctor_id)
        .order_by(PatientReport.created_at.desc())
        .all()
    )
    return [_decorate_report(db, r) for r in reports]


def _decorate_report(db: Session, report: PatientReport) -> ReportResponse:
    """complaints is encrypted at rest; decrypt it for the response here
    rather than relying on FastAPI's automatic ORM-to-Pydantic pass-through,
    which would otherwise hand back raw ciphertext bytes."""
    patient_name = None
    age_gender = None
    if report.patient_id:
        patient = db.get(Patient, report.patient_id)
        if patient:
            identity = (
                db.query(PatientIdentity)
                .filter(PatientIdentity.patient_id == report.patient_id)
                .first()
            )
            if identity and identity.full_name:
                patient_name = decrypt_field(db, identity.full_name)

            age_val = f"{patient.exact_age}" if patient.exact_age is not None else (patient.age_group or "")
            sex_val = patient.sex[0].upper() if patient.sex else ""
            if age_val and sex_val:
                age_gender = f"{age_val} / {sex_val}"
            elif age_val:
                age_gender = age_val
            elif sex_val:
                age_gender = sex_val

    return ReportResponse(
        report_id=report.report_id,
        report_date=report.report_date,
        diagnosis=report.diagnosis,
        diagnosis_status=report.diagnosis_status,
        complaints=decrypt_field(db, report.complaints),
        patient_name=patient_name,
        age_gender=age_gender,
        created_at=report.created_at,
    )


def _resolve_patient(body: ReportCreateRequest, db: Session, doctor: Doctor) -> Patient:
    """
    Reuse an existing patient when one is named, otherwise create a new record.

    Creating a patient row unconditionally was producing a duplicate person on
    every visit, which both breaks continuity of care and inflates case counts.
    """
    if body.patient_id is not None:
        patient = db.get(Patient, body.patient_id)
        if patient is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found"
            )

        # Only the owning facility may attach reports to a known patient.
        identity = (
            db.query(PatientIdentity)
            .filter(PatientIdentity.patient_id == patient.patient_id)
            .first()
        )
        if identity is not None and identity.facility_id != doctor.facility_id:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found"
            )

        # Keep the aggregation key current as the patient ages.
        patient.age_group = body.patient_age_group
        if body.patient_exact_age is not None:
            patient.exact_age = body.patient_exact_age
        db.flush()
        return patient

    # Guard duplicates here rather than in the client, so a caller that never
    # asks /patients/match still cannot create a second copy of a person.
    if body.patient_identity is not None:
        identity_in = body.patient_identity
        candidates = find_candidates(
            db,
            doctor.facility_id,
            MatchCriteria(
                full_name=identity_in.full_name,
                date_of_birth=identity_in.date_of_birth,
                exact_age=body.patient_exact_age or identity_in.exact_age,
                sex=body.patient_sex,
                contact_number=identity_in.contact_number,
                facility_mrn=identity_in.facility_mrn,
                abha_id=identity_in.abha_id,
                district=identity_in.district or body.patient_district,
            ),
        )

        exact = [c for c in candidates if c.match_type != "probabilistic"]
        if exact:
            # A national ID or facility record number collision is not a
            # judgement call, so confirmed_new cannot override it.
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "reason": "exact_match",
                    "candidates": [
                        PatientMatchCandidate(**vars(c)).model_dump(mode="json")
                        for c in exact
                    ],
                },
            )

        blocking = blocking_candidates(candidates)
        if blocking and not body.confirmed_new:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "reason": "possible_duplicate",
                    "candidates": [
                        PatientMatchCandidate(**vars(c)).model_dump(mode="json")
                        for c in blocking
                    ],
                },
            )

    patient = Patient(
        age_group=body.patient_age_group,
        sex=body.patient_sex,
        district=body.patient_district,
        exact_age=body.patient_exact_age,
    )
    db.add(patient)
    db.flush()

    if body.patient_identity is not None:
        identity_in = body.patient_identity
        mrn = identity_in.facility_mrn.strip() if identity_in.facility_mrn else None
        db.add(
            PatientIdentity(
                patient_id=patient.patient_id,
                facility_id=doctor.facility_id,
                full_name=encrypt_field(db, identity_in.full_name.strip()),
                date_of_birth=encrypt_date(db, identity_in.date_of_birth),
                contact_number=encrypt_field(db, identity_in.contact_number),
                facility_mrn=encrypt_field(db, mrn),
                facility_mrn_hash=hash_field(mrn.lower()) if mrn else None,
                abha_id=normalise_digits(identity_in.abha_id),
            )
        )
        try:
            db.flush()
        except IntegrityError:
            # The pre-check above is racy under concurrent submission, and a
            # unique-index violation here previously surfaced as a 500.
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"reason": "exact_match", "candidates": []},
            )

    return patient
