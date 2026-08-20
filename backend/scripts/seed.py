from dotenv import load_dotenv
load_dotenv()

from app.db import SessionLocal
from app.models import Facility, Doctor
from app.auth import hash_password

SEED_DOCTOR_EMAIL = "doctor@epiwatch.test"
SEED_DOCTOR_PASSWORD = "EpiWatch123!"
SEED_LAB_EMAIL = "lab@epiwatch.test"
SEED_LAB_PASSWORD = "EpiWatch123!"


def _ensure_facility(db):
    facility = db.query(Facility).filter_by(name="City General Hospital").first()
    if facility:
        return facility

    facility = Facility(
        name="City General Hospital",
        type="Hospital",
        district="Pune",
        state="Maharashtra",
        latitude=18.5204,
        longitude=73.8567,
    )
    db.add(facility)
    db.flush()
    return facility


def _ensure_user(db, facility, *, email, password, name, specialization, license_no, role):
    """
    Seeds one user, and corrects the role of one that already exists.

    Users seeded before migration 008 took the column's 'doctor' default, so the
    lab account signed in to the doctor workspace. Reconciling the role here
    keeps a database seeded by an older build usable without a manual UPDATE.
    """
    user = db.query(Doctor).filter_by(email=email).first()
    if user:
        if user.role != role:
            print(f"Correcting role for {email}: {user.role} -> {role}")
            user.role = role
        return user, False

    user = Doctor(
        name=name,
        specialization=specialization,
        facility_id=facility.facility_id,
        license_no=license_no,
        email=email,
        password_hash=hash_password(password),
        role=role,
    )
    db.add(user)
    db.flush()
    return user, True


def seed():
    db = SessionLocal()
    try:
        facility = _ensure_facility(db)

        doctor, doctor_created = _ensure_user(
            db, facility,
            email=SEED_DOCTOR_EMAIL, password=SEED_DOCTOR_PASSWORD,
            name="Dr. Asha Rao", specialization="General Medicine",
            license_no="MH-12345", role="doctor",
        )
        # A laboratory technician shares the facility but not the role.
        lab_user, lab_created = _ensure_user(
            db, facility,
            email=SEED_LAB_EMAIL, password=SEED_LAB_PASSWORD,
            name="Priya Nair", specialization="Clinical Microbiology",
            license_no="MH-LAB-201", role="lab",
        )

        db.commit()
        print(f"Facility {facility.facility_id}")
        print(f"  doctor {doctor.doctor_id} ({doctor.role}) {'created' if doctor_created else 'existing'}")
        print(f"  lab    {lab_user.doctor_id} ({lab_user.role}) {'created' if lab_created else 'existing'}")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
