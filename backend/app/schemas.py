from __future__ import annotations
import uuid
from datetime import date, datetime
import datetime as dt
from pydantic import BaseModel


class LoginRequest(BaseModel):
    email: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    role: str = "doctor"
    token_type: str = "bearer"
    doctor_id: uuid.UUID
    name: str
    # None for health_authority/admin accounts, which aren't tied to one
    # facility.
    facility_id: uuid.UUID | None
    must_change_password: bool = False


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class PrescriptionIn(BaseModel):
    drug_name: str
    dosage: str | None = None
    duration: str | None = None


class LabResultIn(BaseModel):
    test_date: date | None = None
    specimen_type: str | None = None
    specimen_type_other: str | None = None
    culture_result: str | None = None
    culture_result_other: str | None = None
    pathogen: str | None = None
    pathogen_other: str | None = None
    antibiotic: str | None = None
    ast_result: str | None = None  # "Resistant" | "Susceptible" | "Intermediate"


class PatientIdentityIn(BaseModel):
    """Identifiable details supplied when registering a new patient."""

    full_name: str
    date_of_birth: date | None = None
    exact_age: int | None = None
    contact_number: str | None = None
    facility_mrn: str | None = None
    abha_id: str | None = None
    district: str | None = None


class ReportCreateRequest(BaseModel):
    # Supply patient_id to continue an existing patient's record, or
    # patient_identity to register a new one. Sending patient_id is what
    # prevents a fresh duplicate patient row per visit.
    patient_id: uuid.UUID | None = None
    patient_identity: PatientIdentityIn | None = None
    patient_exact_age: int | None = None
    # Set only after a clinician has seen the near-match candidates and
    # decided this is genuinely a different person.
    confirmed_new: bool = False

    patient_age_group: str
    patient_sex: str
    patient_district: str
    report_date: date
    # BCP-47 language code of the UI at submission time (e.g. "hi", "mr").
    # Passed to the translation layer so GoogleTranslator uses the exact
    # source language rather than relying on auto-detect.
    source_language: str = "auto"
    complaints: str | None = None
    medical_history: str | None = None
    symptoms: list[str] = []
    diagnosis: str | None = None
    diagnosis_status: str | None = None  # "Suspected" | "Probable" | "Confirmed"
    treatment: str | None = None
    infection_syndrome: str | None = None
    infection_syndrome_other: str | None = None
    infection_origin: str | None = None
    patient_outcome: str | None = None
    patient_outcome_other: str | None = None
    prescriptions: list[PrescriptionIn] = []
    lab_result: LabResultIn | None = None


class ReportResponse(BaseModel):
    report_id: uuid.UUID
    report_date: date
    diagnosis: str | None
    diagnosis_status: str | None
    complaints: str | None
    patient_name: str | None = None
    age_gender: str | None = None
    created_at: datetime

    class Config:
        from_attributes = True


class DashboardSummary(BaseModel):
    patients_today: int
    reports_submitted_total: int
    active_conditions: int


# --- Patient identity & continuity ---


class PatientSearchResult(BaseModel):
    """A patient match, with enough context to pick the right person."""

    patient_id: uuid.UUID
    full_name: str
    exact_age: int | None
    age_group: str
    sex: str
    district: str
    facility_mrn: str | None
    abha_id: str | None = None
    report_count: int
    last_visit: date | None


class PatientHistoryEntry(BaseModel):
    report_id: uuid.UUID
    report_date: date
    diagnosis: str | None
    diagnosis_status: str | None
    complaints: str | None
    pathogen: str | None
    culture_result: str | None
    ast_result: str | None


# --- Duplicate detection ---


class PatientMatchRequest(BaseModel):
    """
    Criteria for finding possible duplicates. POST rather than GET so
    identifiers are not written into URLs or server access logs.
    """

    full_name: str
    date_of_birth: date | None = None
    exact_age: int | None = None
    sex: str | None = None
    contact_number: str | None = None
    facility_mrn: str | None = None
    abha_id: str | None = None
    district: str | None = None


class PatientMatchCandidate(PatientSearchResult):
    score: float
    confidence: str          # "auto" | "review" | "weak"
    match_type: str          # "exact_abha" | "exact_mrn" | "probabilistic"
    # Which signals agreed, so the UI can explain the warning rather than
    # simply assert it -- an unexplained duplicate banner gets dismissed.
    matched_on: list[str] = []


# --- ABHA verification ---


class AbhaVerifyRequest(BaseModel):
    abha_number: str


class AbhaVerifyResponse(BaseModel):
    """
    Result of checking an ABHA number.

    `is_valid` reflects the offline format/checksum check, which always runs.
    `verified` is only true when the national registry confirmed the account,
    so the UI can distinguish "looks right" from "confirmed to exist".
    """

    abha_number: str | None = None
    is_valid: bool
    verified: bool = False
    name: str | None = None
    gender: str | None = None
    date_of_birth: str | None = None
    state_name: str | None = None
    district_name: str | None = None
    message: str | None = None


# --- Laboratory ---


class AstResultIn(BaseModel):
    """One antibiotic tested against an isolate."""

    antibiotic: str
    antibiotic_class: str | None = None
    ast_result: str | None = None
    mic_value: float | None = None
    mic_operator: str | None = None
    zone_diameter_mm: int | None = None
    method: str | None = None


class IsolateCreate(BaseModel):
    """
    A culture result and its susceptibility panel.

    report_id is optional: a laboratory reports on a specimen whether or not a
    clinician has filed a report for that patient yet.
    """

    report_id: uuid.UUID | None = None
    patient_id: uuid.UUID | None = None
    accession_no: str | None = None
    collection_date: date | None = None
    test_date: date | None = None
    specimen_type: str | None = None
    specimen_type_other: str | None = None
    culture_result: str | None = None
    culture_result_other: str | None = None
    pathogen: str | None = None
    pathogen_other: str | None = None
    infection_origin: str | None = None
    status: str = "preliminary"
    notes: str | None = None
    ast_results: list[AstResultIn] = []


class AstResultOut(BaseModel):
    antibiotic: str
    antibiotic_class: str | None
    ast_result: str | None
    mic_value: float | None
    mic_operator: str | None
    zone_diameter_mm: int | None
    method: str | None

    class Config:
        from_attributes = True


class IsolateOut(BaseModel):
    isolate_id: uuid.UUID
    report_id: uuid.UUID | None
    accession_no: str | None
    collection_date: date | None
    test_date: date | None
    specimen_type: str | None
    culture_result: str | None
    pathogen: str | None
    infection_origin: str | None
    status: str
    notes: str | None
    created_at: datetime
    ast_results: list[AstResultOut] = []

    # Derived on read so every consumer computes them the same way.
    resistant_count: int = 0
    tested_count: int = 0
    is_mdr: bool = False

    class Config:
        from_attributes = True


class LabSummary(BaseModel):
    isolates_today: int
    pending_cultures: int
    mdr_isolates_week: int
    resistance_rate_week: float | None


class StrainClusterCreate(BaseModel):
    pathogen: str
    designation: str | None = None
    clonal_group: str | None = None
    notes: str | None = None


class StrainClusterOut(BaseModel):
    strain_id: uuid.UUID
    pathogen: str
    designation: str | None
    clonal_group: str | None
    facility_id: uuid.UUID | None
    first_detected_at: datetime
    notes: str | None
    isolate_count: int = 0

    class Config:
        from_attributes = True


# --- Facility onboarding (admin) ---


class FacilityApplicationCreate(BaseModel):
    """
    Submitted by a hospital/clinic with no account yet -- an unauthenticated
    endpoint. Everything here is what admin needs to review the request and,
    on approval, provision the Facility + Doctor account.
    """

    facility_name: str
    facility_type: str  # "Hospital" | "Clinic" | "Dispensary"
    district: str
    state: str
    contact_name: str
    contact_email: str
    contact_phone: str | None = None
    license_no: str | None = None
    requested_role: str  # "doctor" | "lab"


class FacilityApplicationOut(BaseModel):
    application_id: uuid.UUID
    facility_name: str
    facility_type: str
    district: str
    state: str
    contact_name: str
    contact_email: str
    contact_phone: str | None
    license_no: str | None
    requested_role: str
    status: str
    reviewed_at: datetime | None
    rejection_reason: str | None
    submitted_at: datetime

    class Config:
        from_attributes = True


# --- Surveillance (Health Authority) ---


class DiseaseDailyPoint(BaseModel):
    report_date: date
    diagnosis: str
    case_count: int


class SurveillanceMetricOut(BaseModel):
    facility_id: uuid.UUID | None
    pathogen: str | None
    antibiotic: str | None
    window_start: date
    window_end: date
    value: float
    sample_size: int


class FacilityGeo(BaseModel):
    facility_id: uuid.UUID
    name: str
    district: str
    state: str
    latitude: float | None
    longitude: float | None
    recent_case_count: int


class SurveillanceSummary(BaseModel):
    facilities_reporting: int
    reports_today: int


class DistrictSummary(BaseModel):
    district: str
    state: str
    facility_count: int
    recent_case_count: int

    class Config:
        from_attributes = True


class RiskScoreOut(BaseModel):
    facility_id: str
    organism: str | None = None
    composite_risk_score: float
    norm_ewma: float | None = None
    norm_cusum: float | None = None
    norm_if: float | None = None
    culture_count: int | None = None


class AlertOut(BaseModel):
    facility_id: str
    organism: str | None = None
    alert_level: str  # "Watch", "Elevated", "Critical"
    composite_risk_score: float
    date: dt.date | None = None


class ApplicationRejectRequest(BaseModel):
    reason: str


class ApplicationApproveResponse(BaseModel):
    """
    The one-time credential for the new account, shown to admin exactly
    once -- there's no email/notification path yet, so admin communicates
    this out-of-band. The account must change it on first login
    (must_change_password on the created Doctor row).
    """

    application: FacilityApplicationOut
    facility_id: uuid.UUID
    doctor_id: uuid.UUID
    email: str
    temporary_password: str
