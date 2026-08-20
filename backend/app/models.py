import uuid
from datetime import datetime, date
from sqlalchemy import String, ForeignKey, TIMESTAMP, Date, Text, Integer, Numeric
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
    facility_id: Mapped[uuid.UUID] = mapped_column(UUID, ForeignKey("master.facilities.facility_id"))
    license_no: Mapped[str | None] = mapped_column(String)
    role: Mapped[str] = mapped_column(String, default="doctor")
    email: Mapped[str] = mapped_column(String, unique=True)
    password_hash: Mapped[str] = mapped_column(String)
    failed_login_count: Mapped[int] = mapped_column(Integer, default=0)
    locked_until: Mapped[datetime | None] = mapped_column(TIMESTAMP)
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
    full_name: Mapped[str] = mapped_column(String)
    date_of_birth: Mapped[date | None] = mapped_column(Date)
    contact_number: Mapped[str | None] = mapped_column(String)
    facility_mrn: Mapped[str | None] = mapped_column(String)
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
    complaints: Mapped[str | None] = mapped_column(Text)
    medical_history: Mapped[str | None] = mapped_column(Text)
    symptoms: Mapped[dict | None] = mapped_column(JSONB)
    diagnosis: Mapped[str | None] = mapped_column(String)
    diagnosis_status: Mapped[str | None] = mapped_column(String)
    treatment: Mapped[str | None] = mapped_column(Text)
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
