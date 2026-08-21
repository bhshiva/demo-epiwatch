import uuid
from datetime import datetime, date
from sqlalchemy import String, ForeignKey, TIMESTAMP, Date, Text, Integer, Numeric, UniqueConstraint, Boolean, LargeBinary
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db import Base

class Facility(Base):
    __tablename__ = "facilities"
    __table_args__ = {"schema": "master"}

    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String)
    type: Mapped[str] = mapped_column(String)
    district: Mapped[str] = mapped_column(String)
    state: Mapped[str] = mapped_column(String)
    latitude: Mapped[float | None] = mapped_column(Numeric)
    longitude: Mapped[float | None] = mapped_column(Numeric)

class Doctor(Base):
    __tablename__ = "doctors"
    __table_args__ = {"schema": "master"}

    doctor_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String)
    specialization: Mapped[str | None] = mapped_column(String)
    # Nullable: health_authority and admin accounts aren't tied to one
    # facility (a health authority sees every facility; admin approves
    # accounts before any facility-scoped work exists for them). Every
    # doctor/lab row still has one.
    facility_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    license_no: Mapped[str | None] = mapped_column(String)
    role: Mapped[str] = mapped_column(String, default="doctor")
    email: Mapped[str] = mapped_column(String, unique=True)
    password_hash: Mapped[str] = mapped_column(String)
    failed_login_count: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(TIMESTAMP)
    # Set true when admin provisions an account with a generated one-time
    # password; cleared once the user sets their own via POST
    # /auth/change-password.
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

class Patient(Base):
    __tablename__ = "patients"
    __table_args__ = {"schema": "master"}

    patient_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    anonymous_id: Mapped[uuid.UUID] = mapped_column(UUID, default=uuid.uuid4)
    age_group: Mapped[str] = mapped_column(String)
    sex: Mapped[str] = mapped_column(String)
    district: Mapped[str] = mapped_column(String)
    exact_age: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)


class PatientIdentity(Base):
    """
    Identifiable patient details, kept out of master.patients so the
    surveillance/analytics path can never join to a name. Only clinicians at
    the owning facility read this table.
    """

    __tablename__ = "patient_identities"
    __table_args__ = {"schema": "master"}

    identity_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.patients.patient_id"))
    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    # Encrypted at rest (pgcrypto pgp_sym_encrypt/decrypt, see
    # services/crypto.py) -- stored as ciphertext bytes, never plaintext in
    # the database. Read/written only through encrypt_field/decrypt_field.
    full_name: Mapped[bytes] = mapped_column(LargeBinary)
    date_of_birth: Mapped[bytes | None] = mapped_column(LargeBinary)
    contact_number: Mapped[bytes | None] = mapped_column(LargeBinary)
    facility_mrn: Mapped[bytes | None] = mapped_column(LargeBinary)
    # Deterministic HMAC blind index for facility_mrn (pgp_sym_encrypt is
    # non-deterministic, so the ciphertext column itself can't back a
    # uniqueness constraint or an equality lookup -- see crypto.py:hash_field
    # and migration 013's comment).
    facility_mrn_hash: Mapped[str | None] = mapped_column(String)
    abha_id: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)


class PatientReport(Base):
    __tablename__ = "patient_reports"
    __table_args__ = {"schema": "raw"}

    report_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.patients.patient_id"))
    doctor_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.doctors.doctor_id"))
    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    report_date: Mapped[date] = mapped_column(Date)
    # Encrypted at rest -- see PatientIdentity's fields above and
    # services/crypto.py. Clinical free text can carry identifying detail a
    # doctor typed in, unlike the coded fields below.
    complaints: Mapped[bytes | None] = mapped_column(LargeBinary)
    medical_history: Mapped[bytes | None] = mapped_column(LargeBinary)
    symptoms: Mapped[dict | None] = mapped_column(JSONB)
    diagnosis: Mapped[str | None] = mapped_column(String)
    diagnosis_status: Mapped[str | None] = mapped_column(String)
    treatment: Mapped[bytes | None] = mapped_column(LargeBinary)
    infection_syndrome: Mapped[str | None] = mapped_column(String)
    infection_syndrome_other: Mapped[str | None] = mapped_column(String)
    infection_origin: Mapped[str | None] = mapped_column(String)
    patient_outcome: Mapped[str | None] = mapped_column(String)
    patient_outcome_other: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    prescriptions: Mapped[list["Prescription"]] = relationship(back_populates="report")
    lab_results: Mapped[list["LabResult"]] = relationship(back_populates="report")

class Prescription(Base):
    __tablename__ = "prescriptions"
    __table_args__ = {"schema": "raw"}

    prescription_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    report_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("raw.patient_reports.report_id"))
    drug_name: Mapped[str] = mapped_column(String)
    dosage: Mapped[str | None] = mapped_column(String)
    duration: Mapped[str | None] = mapped_column(String)
    prescribed_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    report: Mapped["PatientReport"] = relationship(back_populates="prescriptions")

class LabResult(Base):
    __tablename__ = "lab_results"
    __table_args__ = {"schema": "raw"}

    lab_result_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    report_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("raw.patient_reports.report_id"))
    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    test_date: Mapped[date | None] = mapped_column(Date)
    specimen_type: Mapped[str | None] = mapped_column(String)
    specimen_type_other: Mapped[str | None] = mapped_column(String)
    culture_result: Mapped[str | None] = mapped_column(String)
    culture_result_other: Mapped[str | None] = mapped_column(String)
    pathogen: Mapped[str | None] = mapped_column(String)
    pathogen_other: Mapped[str | None] = mapped_column(String)
    antibiotic: Mapped[str | None] = mapped_column(String)
    ast_result: Mapped[str | None] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    report: Mapped["PatientReport"] = relationship(back_populates="lab_results")


class LabIsolate(Base):
    """
    One organism recovered from one specimen.

    Distinct from the legacy LabResult: an isolate owns a panel of AstResult
    rows (one per antibiotic tested), which is how routine microbiology
    actually reports. report_id is nullable so a laboratory can record a
    result before any clinician report exists for that patient.
    """

    __tablename__ = "lab_isolates"
    __table_args__ = {"schema": "raw"}

    isolate_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    report_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("raw.patient_reports.report_id"))
    patient_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.patients.patient_id"))
    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    lab_user_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.doctors.doctor_id"))

    accession_no: Mapped[str | None] = mapped_column(String)
    collection_date: Mapped[date | None] = mapped_column(Date)
    test_date: Mapped[date | None] = mapped_column(Date)

    specimen_type: Mapped[str | None] = mapped_column(String)
    specimen_type_other: Mapped[str | None] = mapped_column(String)
    culture_result: Mapped[str | None] = mapped_column(String)
    culture_result_other: Mapped[str | None] = mapped_column(String)
    pathogen: Mapped[str | None] = mapped_column(String)
    pathogen_other: Mapped[str | None] = mapped_column(String)
    infection_origin: Mapped[str | None] = mapped_column(String)

    status: Mapped[str] = mapped_column(String, default="preliminary")
    amended_from: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("raw.lab_isolates.isolate_id"))
    notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    ast_results: Mapped[list["AstResult"]] = relationship(
        back_populates="isolate", cascade="all, delete-orphan"
    )


class AstResult(Base):
    """One antibiotic tested against one isolate."""

    __tablename__ = "ast_results"
    __table_args__ = {"schema": "raw"}

    ast_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    isolate_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("raw.lab_isolates.isolate_id"))

    antibiotic: Mapped[str] = mapped_column(String)
    antibiotic_class: Mapped[str | None] = mapped_column(String)
    ast_result: Mapped[str | None] = mapped_column(String)

    mic_value: Mapped[float | None] = mapped_column(Numeric)
    mic_operator: Mapped[str | None] = mapped_column(String)
    zone_diameter_mm: Mapped[int | None] = mapped_column(Integer)
    method: Mapped[str | None] = mapped_column(String)
    breakpoint_standard: Mapped[str | None] = mapped_column(String, default="CLSI")

    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    isolate: Mapped["LabIsolate"] = relationship(back_populates="ast_results")


class StrainCluster(Base):
    """A named clone/lineage that one or more isolates get linked to."""

    __tablename__ = "strain_clusters"
    __table_args__ = {"schema": "raw"}

    strain_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    pathogen: Mapped[str] = mapped_column(String)
    designation: Mapped[str | None] = mapped_column(String)
    clonal_group: Mapped[str | None] = mapped_column(String)
    facility_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    first_detected_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)

    links: Mapped[list["IsolateStrainLink"]] = relationship(
        back_populates="strain", cascade="all, delete-orphan"
    )


class IsolateStrainLink(Base):
    """
    One isolate's assignment to one strain.

    A link table rather than a FK on lab_isolates: an assignment can be
    corrected, and keeping the row (rather than overwriting a single column)
    preserves that history, matching how lab_isolates itself handles
    amendments.
    """

    __tablename__ = "isolate_strain_links"
    __table_args__ = (
        UniqueConstraint("isolate_id", "strain_id"),
        {"schema": "raw"},
    )

    link_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)
    isolate_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("raw.lab_isolates.isolate_id"))
    strain_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("raw.strain_clusters.strain_id"))
    assigned_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)
    assigned_by: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.doctors.doctor_id"))

    strain: Mapped["StrainCluster"] = relationship(back_populates="links")


class FacilityApplication(Base):
    """A hospital/clinic's request for access, reviewed by an admin account."""

    __tablename__ = "facility_applications"
    __table_args__ = {"schema": "master"}

    application_id: Mapped[uuid.UUID] = mapped_column(UUID, primary_key=True, default=uuid.uuid4)

    facility_name: Mapped[str] = mapped_column(String)
    facility_type: Mapped[str] = mapped_column(String)
    district: Mapped[str] = mapped_column(String)
    state: Mapped[str] = mapped_column(String)

    contact_name: Mapped[str] = mapped_column(String)
    contact_email: Mapped[str] = mapped_column(String)
    contact_phone: Mapped[str | None] = mapped_column(String)
    license_no: Mapped[str | None] = mapped_column(String)

    requested_role: Mapped[str] = mapped_column(String)

    status: Mapped[str] = mapped_column(String, default="pending")
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.doctors.doctor_id"))
    reviewed_at: Mapped[datetime | None] = mapped_column(TIMESTAMP)
    rejection_reason: Mapped[str | None] = mapped_column(Text)

    created_facility_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    created_doctor_id: Mapped[uuid.UUID | None] = mapped_column(UUID, ForeignKey("master.doctors.doctor_id"))

    submitted_at: Mapped[datetime] = mapped_column(TIMESTAMP, default=datetime.utcnow)
