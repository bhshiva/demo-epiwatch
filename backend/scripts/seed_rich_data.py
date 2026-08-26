"""
Seed script to populate a rich, realistic multi-facility epidemiological
and AST dataset across Maharashtra and Karnataka for EpiWatch.
"""

import random
import uuid
from datetime import date, datetime, timedelta

from dotenv import load_dotenv
load_dotenv()

from app.auth import hash_password
from app.db import SessionLocal
from app.models import (
    AstResult,
    Doctor,
    Facility,
    FacilityApplication,
    LabIsolate,
    Patient,
    PatientIdentity,
    PatientReport,
    Prescription,
)
from app.services.crypto import encrypt_field, hash_field
from scripts.generate_surveillance_tables import run as run_analytics_etl
from scripts.seed import (
    SEED_ADMIN_EMAIL,
    SEED_ADMIN_PASSWORD,
    SEED_DOCTOR_EMAIL,
    SEED_DOCTOR_PASSWORD,
    SEED_HEALTH_AUTHORITY_EMAIL,
    SEED_HEALTH_AUTHORITY_PASSWORD,
    SEED_LAB_EMAIL,
    SEED_LAB_PASSWORD,
    _ensure_facility,
    _ensure_user,
)

FACILITY_DATA = [
    {
        "name": "City General Hospital",
        "type": "Hospital",
        "district": "Pune",
        "state": "Maharashtra",
        "latitude": 18.5204,
        "longitude": 73.8567,
    },
    {
        "name": "Ruby Hall Sentinel Clinic",
        "type": "Clinic",
        "district": "Pune",
        "state": "Maharashtra",
        "latitude": 18.5312,
        "longitude": 73.8785,
    },
    {
        "name": "KEM Hospital Parel",
        "type": "Hospital",
        "district": "Mumbai",
        "state": "Maharashtra",
        "latitude": 18.9986,
        "longitude": 72.8436,
    },
    {
        "name": "Sion Municipal Hospital",
        "type": "Hospital",
        "district": "Mumbai",
        "state": "Maharashtra",
        "latitude": 19.0356,
        "longitude": 72.8601,
    },
    {
        "name": "Dadar Central Polyclinic",
        "type": "Clinic",
        "district": "Mumbai",
        "state": "Maharashtra",
        "latitude": 19.0178,
        "longitude": 72.8478,
    },
    {
        "name": "Kurla West Dispensary",
        "type": "Clinic",
        "district": "Mumbai",
        "state": "Maharashtra",
        "latitude": 19.0657,
        "longitude": 72.8792,
    },
    {
        "name": "Bandra Sentinel Center",
        "type": "Hospital",
        "district": "Mumbai",
        "state": "Maharashtra",
        "latitude": 19.0596,
        "longitude": 72.8295,
    },
    {
        "name": "Thane Civil Sentinel",
        "type": "Hospital",
        "district": "Thane",
        "state": "Maharashtra",
        "latitude": 19.1970,
        "longitude": 72.9760,
    },
    {
        "name": "Nashik District Hospital",
        "type": "Hospital",
        "district": "Nashik",
        "state": "Maharashtra",
        "latitude": 19.9975,
        "longitude": 73.7898,
    },
    {
        "name": "Dharwad Civil Hospital",
        "type": "Hospital",
        "district": "Dharwad",
        "state": "Karnataka",
        "latitude": 15.4589,
        "longitude": 75.0078,
    },
    {
        "name": "Victoria Hospital Bangalore",
        "type": "Hospital",
        "district": "Bengaluru",
        "state": "Karnataka",
        "latitude": 12.9629,
        "longitude": 77.5746,
    },
]

PATIENT_NAMES = [
    ("Rajesh Kumar", "Male", 48, "45-64"),
    ("Sunita Deshmukh", "Female", 34, "25-44"),
    ("Aarav Patil", "Male", 7, "5-14"),
    ("Ananya Kulkarni", "Female", 22, "15-24"),
    ("Ramesh Shinde", "Male", 68, "65+"),
    ("Pooja Nair", "Female", 29, "25-44"),
    ("Vikram More", "Male", 52, "45-64"),
    ("Kavita Joshi", "Female", 41, "25-44"),
    ("Amitabh Sawant", "Male", 38, "25-44"),
    ("Meenakshi Rao", "Female", 61, "45-64"),
    ("Sanjay Gokhale", "Male", 45, "45-64"),
    ("Neha Jadhav", "Female", 19, "15-24"),
    ("Vijay Waghmare", "Male", 55, "45-64"),
    ("Smita Bhat", "Female", 31, "25-44"),
    ("Pradeep Hegde", "Male", 63, "45-64"),
    ("Deepa Shenoy", "Female", 27, "25-44"),
    ("Ganesh Gaikwad", "Male", 42, "25-44"),
    ("Lata Tambe", "Female", 72, "65+"),
    ("Siddharth Pai", "Male", 35, "25-44"),
    ("Vandana Kamat", "Female", 50, "45-64"),
    ("Rahul Thorat", "Male", 12, "5-14"),
    ("Swati Mane", "Female", 36, "25-44"),
    ("Nitin Chavan", "Male", 49, "45-64"),
    ("Rekha Salunkhe", "Female", 58, "45-64"),
    ("Prakash Gore", "Male", 66, "65+"),
]

DIAGNOSES = [
    ("Community Acquired Pneumonia", "J18.9", "Respiratory", "Cephalosporins", "Ceftriaxone", 1000, "mg", "IV", "Once daily", 7),
    ("Typhoid Fever", "A01.0", "Gastrointestinal", "Fluoroquinolones", "Ciprofloxacin", 500, "mg", "Oral", "Twice daily", 10),
    ("Urinary Tract Infection", "N39.0", "Urinary", "Fluoroquinolones", "Norfloxacin", 400, "mg", "Oral", "Twice daily", 5),
    ("Acute Gastroenteritis", "A09", "Gastrointestinal", "Fluoroquinolones", "Ofloxacin", 200, "mg", "Oral", "Twice daily", 5),
    ("Influenza-like Illness", "J10.1", "Respiratory", "Other", "Oseltamivir", 75, "mg", "Oral", "Twice daily", 5),
    ("Sepsis / Bacteremia", "A41.9", "Bloodstream", "Carbapenems", "Meropenem", 1000, "mg", "IV", "TDS", 10),
    ("Skin & Soft Tissue Infection", "L08.9", "Other", "Penicillins", "Amoxicillin-Clavulanate", 625, "mg", "Oral", "TDS", 7),
]

ORGANISM_AST_SPECS = [
    {
        "organism": "Acinetobacter baumannii",
        "sample_type": "Bronchoalveolar Lavage",
        "antibiotics": [
            ("Meropenem", "Carbapenems", 12.0, 16.0, "R"),
            ("Ciprofloxacin", "Fluoroquinolones", 10.0, 8.0, "R"),
            ("Amikacin", "Aminoglycosides", 14.0, 32.0, "R"),
            ("Colistin", "Polymyxins", 22.0, 1.0, "S"),
        ],
        "is_mdr": True,
    },
    {
        "organism": "Salmonella Typhi",
        "sample_type": "Blood Culture",
        "antibiotics": [
            ("Ciprofloxacin", "Fluoroquinolones", 14.0, 2.0, "R"),
            ("Ceftriaxone", "Cephalosporins", 24.0, 0.5, "S"),
            ("Azithromycin", "Macrolides", 18.0, 8.0, "S"),
            ("Ampicillin", "Penicillins", 12.0, 16.0, "R"),
        ],
        "is_mdr": False,
    },
    {
        "organism": "Escherichia coli",
        "sample_type": "Urine Culture",
        "antibiotics": [
            ("Ciprofloxacin", "Fluoroquinolones", 13.0, 4.0, "R"),
            ("Ceftriaxone", "Cephalosporins", 16.0, 8.0, "R"),
            ("Amoxicillin-Clavulanate", "Penicillins", 15.0, 16.0, "I"),
            ("Meropenem", "Carbapenems", 26.0, 0.25, "S"),
            ("Nitrofurantoin", "Nitrofurans", 21.0, 16.0, "S"),
        ],
        "is_mdr": True,
    },
    {
        "organism": "Klebsiella pneumoniae",
        "sample_type": "Sputum Culture",
        "antibiotics": [
            ("Ceftriaxone", "Cephalosporins", 14.0, 16.0, "R"),
            ("Cefepime", "Cephalosporins", 15.0, 8.0, "I"),
            ("Meropenem", "Carbapenems", 18.0, 4.0, "I"),
            ("Amikacin", "Aminoglycosides", 20.0, 4.0, "S"),
            ("Piperacillin-Tazobactam", "Penicillins", 16.0, 32.0, "R"),
        ],
        "is_mdr": True,
    },
    {
        "organism": "Pseudomonas aeruginosa",
        "sample_type": "Pus Swab",
        "antibiotics": [
            ("Ceftazidime", "Cephalosporins", 15.0, 16.0, "R"),
            ("Piperacillin-Tazobactam", "Penicillins", 18.0, 16.0, "S"),
            ("Meropenem", "Carbapenems", 22.0, 1.0, "S"),
            ("Ciprofloxacin", "Fluoroquinolones", 19.0, 1.0, "S"),
        ],
        "is_mdr": False,
    },
    {
        "organism": "Staphylococcus aureus",
        "sample_type": "Wound Swab",
        "antibiotics": [
            ("Cefoxitin", "Cephalosporins", 18.0, 8.0, "R"),  # MRSA surrogate
            ("Vancomycin", "Glycopeptides", 22.0, 1.0, "S"),
            ("Linezolid", "Oxazolidinones", 26.0, 1.5, "S"),
            ("Clindamycin", "Lincosamides", 20.0, 0.5, "S"),
        ],
        "is_mdr": True,
    },
]


def seed_rich_data():
    db = SessionLocal()
    try:
        print("[SEED] Seeding rich surveillance, clinical, and AST data...")

        # 1. Ensure core standard users
        core_fac = _ensure_facility(db)
        doctor, _ = _ensure_user(
            db, core_fac,
            email=SEED_DOCTOR_EMAIL, password=SEED_DOCTOR_PASSWORD,
            name="Dr. Asha Rao", specialization="General Medicine",
            license_no="MH-12345", role="doctor",
        )
        lab_user, _ = _ensure_user(
            db, core_fac,
            email=SEED_LAB_EMAIL, password=SEED_LAB_PASSWORD,
            name="Priya Nair", specialization="Clinical Microbiology",
            license_no="MH-LAB-201", role="lab",
        )
        _ensure_user(
            db, None,
            email=SEED_HEALTH_AUTHORITY_EMAIL, password=SEED_HEALTH_AUTHORITY_PASSWORD,
            name="Dr. Meera Iyer", specialization=None,
            license_no=None, role="health_authority",
        )
        _ensure_user(
            db, None,
            email=SEED_ADMIN_EMAIL, password=SEED_ADMIN_PASSWORD,
            name="Ravi Kulkarni", specialization=None,
            license_no=None, role="admin",
        )

        # 2. Seed Facilities
        facilities = []
        for f_data in FACILITY_DATA:
            fac = db.query(Facility).filter_by(name=f_data["name"]).first()
            if not fac:
                fac = Facility(**f_data)
                db.add(fac)
                db.flush()
            facilities.append(fac)

        # 3. Seed Doctors & Labs for each facility
        facility_doctors = {}
        facility_labs = {}
        for fac in facilities:
            doc_email = f"doctor.{fac.district.lower()}@epiwatch.test"
            lab_email = f"lab.{fac.district.lower()}@epiwatch.test"
            
            f_doc, _ = _ensure_user(
                db, fac,
                email=doc_email, password="EpiWatch123!",
                name=f"Dr. {fac.name.split()[0]} Physician", specialization="Internal Medicine",
                license_no=f"{fac.state[:2].upper()}-DOC-{random.randint(100, 999)}", role="doctor",
            )
            f_lab, _ = _ensure_user(
                db, fac,
                email=lab_email, password="EpiWatch123!",
                name=f"{fac.name.split()[0]} Lab Officer", specialization="Microbiology",
                license_no=f"{fac.state[:2].upper()}-LAB-{random.randint(100, 999)}", role="lab",
            )
            facility_doctors[fac.facility_id] = f_doc
            facility_labs[fac.facility_id] = f_lab

        # 4. Seed Patients & Identities
        patients = []
        for idx, (pname, sex, age, age_group) in enumerate(PATIENT_NAMES):
            fac = facilities[idx % len(facilities)]
            mrn = f"MRN-{fac.district[:3].upper()}-{1000 + idx}"
            mrn_hash = hash_field(mrn)
            
            # Check existing identity by mrn_hash
            existing_id = db.query(PatientIdentity).filter_by(facility_id=fac.facility_id, facility_mrn_hash=mrn_hash).first()
            if existing_id:
                pat = db.query(Patient).filter_by(patient_id=existing_id.patient_id).first()
                if pat:
                    patients.append((pat, fac))
                    continue

            pat = Patient(
                age_group=age_group,
                sex=sex,
                district=fac.district,
                exact_age=age,
            )
            db.add(pat)
            db.flush()

            identity = PatientIdentity(
                patient_id=pat.patient_id,
                facility_id=fac.facility_id,
                full_name=encrypt_field(db, pname),
                contact_number=encrypt_field(db, f"+9198{random.randint(10000000, 99999999)}"),
                facility_mrn=encrypt_field(db, mrn),
                facility_mrn_hash=mrn_hash,
                abha_id=f"91{random.randint(100000000000, 999999999999)}",
            )
            db.add(identity)
            patients.append((pat, fac))

        db.flush()

        # 5. Seed Clinical Reports & Prescriptions across 30 days
        today = date.today()
        created_reports = []
        for i in range(75):
            pat, fac = random.choice(patients)
            doc = facility_doctors.get(fac.facility_id, doctor)
            diag_info = random.choice(DIAGNOSES)
            
            days_ago = random.choices(
                population=list(range(30)),
                weights=[10 if d <= 7 else 3 for d in range(30)],
                k=1,
            )[0]
            rep_date = today - timedelta(days=days_ago)

            report = PatientReport(
                patient_id=pat.patient_id,
                doctor_id=doc.doctor_id,
                facility_id=fac.facility_id,
                report_date=rep_date,
                complaints=encrypt_field(db, f"Patient presents with acute symptoms of {diag_info[0]}"),
                medical_history=encrypt_field(db, "No known drug allergies reported. Baseline stable."),
                treatment=encrypt_field(db, f"Prescribed course of {diag_info[4]} with monitoring."),
                diagnosis=diag_info[0],
                diagnosis_status="Confirmed",
                infection_syndrome=diag_info[2],
                infection_origin="community",
                patient_outcome="improving",
                symptoms={"fever": True, "duration_days": random.randint(2, 6)},
            )
            db.add(report)
            db.flush()
            created_reports.append((report, fac))

            # Add prescription
            rx = Prescription(
                report_id=report.report_id,
                drug_name=f"{diag_info[4]} ({diag_info[3]})",
                dosage=f"{diag_info[5]} {diag_info[6]} {diag_info[8]}",
                duration=f"{diag_info[9]} days",
            )
            db.add(rx)

        # 6. Seed Lab Isolates and AST Breakpoints
        sir_map = {"R": "Resistant", "S": "Susceptible", "I": "Intermediate"}
        for idx, (rep, fac) in enumerate(created_reports[:48]):
            l_user = facility_labs.get(fac.facility_id, lab_user)
            spec = ORGANISM_AST_SPECS[idx % len(ORGANISM_AST_SPECS)]
            
            isolate = LabIsolate(
                facility_id=fac.facility_id,
                lab_user_id=l_user.doctor_id,
                report_id=rep.report_id,
                patient_id=rep.patient_id,
                accession_no=f"ACC-{fac.district[:3].upper()}-{202600 + idx}",
                specimen_type=spec["sample_type"],
                culture_result="Positive",
                pathogen=spec["organism"],
                collection_date=rep.report_date,
                test_date=rep.report_date + timedelta(days=1),
                infection_origin="community",
                status="final",
            )
            db.add(isolate)
            db.flush()

            for ab_name, ab_class, zone, mic, sir in spec["antibiotics"]:
                ast = AstResult(
                    isolate_id=isolate.isolate_id,
                    antibiotic=ab_name,
                    antibiotic_class=ab_class,
                    zone_diameter_mm=int(zone),
                    mic_value=mic,
                    ast_result=sir_map.get(sir, "Resistant"),
                    method="Disk diffusion",
                    breakpoint_standard="CLSI",
                )
                db.add(ast)

        # 7. Seed Facility Applications for Admin Review
        sample_applications = [
            ("Apex Superspecialty Hospital", "Hospital", "Mumbai", "Maharashtra", "Dr. Alok Verma", "alok.verma@apex.test", "MH-MC-88219", "approved", "doctor"),
            ("Sahyadri Sentinel Clinic", "Clinic", "Pune", "Maharashtra", "Dr. Sneha Desai", "sneha.desai@sahyadri.test", "MH-MC-99432", "pending", "doctor"),
            ("KLE Central Dispensary", "Dispensary", "Dharwad", "Karnataka", "Dr. Sunil Patil", "sunil.patil@kle.test", "KA-LAB-44120", "pending", "lab"),
            ("Fortis Outreach Dispensary", "Clinic", "Bengaluru", "Karnataka", "Dr. Kiran Rao", "kiran.rao@fortis.test", "KA-MC-77312", "rejected", "doctor"),
        ]

        for name, ftype, dist, st, doc_name, email, lic, status, role in sample_applications:
            app = db.query(FacilityApplication).filter_by(facility_name=name).first()
            if not app:
                app = FacilityApplication(
                    facility_name=name,
                    facility_type=ftype,
                    district=dist,
                    state=st,
                    contact_name=doc_name,
                    contact_email=email,
                    contact_phone=f"+9198{random.randint(10000000, 99999999)}",
                    license_no=lic,
                    requested_role=role,
                    status=status,
                    submitted_at=datetime.utcnow() - timedelta(days=random.randint(1, 10)),
                )
                db.add(app)

        db.commit()
        print("[SUCCESS] Database successfully populated with multi-facility clinical and AST data!")

        # 8. Trigger analytics aggregation
        print("[ETL] Running surveillance aggregation tables...")
        run_analytics_etl()
        print("[COMPLETE] All analytics, surveillance tables, and metrics successfully updated!")

    finally:
        db.close()


if __name__ == "__main__":
    seed_rich_data()
