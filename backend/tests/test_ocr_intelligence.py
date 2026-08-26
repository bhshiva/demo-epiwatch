import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.auth import create_access_token
from app.services.normalization_service import (
    normalize_pathogen,
    normalize_antibiotic,
    normalize_specimen,
    normalize_syndrome,
    normalize_sex,
    normalize_district,
    age_to_age_group,
)
from app.services.clinical_intelligence import (
    audit_lab_isolate,
    audit_clinician_report,
)
from app.services.ocr_service import (
    parse_raw_clinical_text,
    parse_raw_ast_text,
)


def test_pathogen_normalization():
    p, _, score = normalize_pathogen("e. coli")
    assert p == "Escherichia coli"
    assert score > 0.9

    p, _, score = normalize_pathogen("K. Pneumoniae")
    assert p == "Klebsiella pneumoniae"

    p, _, score = normalize_pathogen("MRSA")
    assert p == "Staphylococcus aureus"

    p, _, score = normalize_pathogen("Pseudomonas")
    assert p == "Pseudomonas aeruginosa"


def test_antibiotic_normalization():
    drug, ab_class, score = normalize_antibiotic("Augmentin")
    assert drug == "Amoxicillin-Clavulanate"
    assert ab_class == "Penicillins"

    drug, ab_class, _ = normalize_antibiotic("Cipro")
    assert drug == "Ciprofloxacin"
    assert ab_class == "Fluoroquinolones"

    drug, ab_class, _ = normalize_antibiotic("Piptaz")
    assert drug == "Piperacillin-Tazobactam"
    assert ab_class == "Penicillins"


def test_intrinsic_resistance_violation_detection():
    # Klebsiella is intrinsically resistant to Ampicillin
    ast_panel = [
        {"antibiotic": "Ampicillin", "antibiotic_class": "Penicillins", "ast_result": "Susceptible"},
        {"antibiotic": "Ceftriaxone", "antibiotic_class": "Cephalosporins", "ast_result": "Resistant"},
    ]
    audit = audit_lab_isolate(
        specimen_type="Urine",
        pathogen="Klebsiella pneumoniae",
        ast_panel=ast_panel,
    )
    assert audit.status == "CRITICAL_ANOMALY"
    assert audit.is_valid is False
    categories = [f["category"] for f in audit.findings]
    assert "intrinsic_resistance" in categories


def test_specimen_pathogen_incongruity():
    # Neisseria gonorrhoeae in Sputum
    ast_panel = [
        {"antibiotic": "Ceftriaxone", "antibiotic_class": "Cephalosporins", "ast_result": "Susceptible"}
    ]
    audit = audit_lab_isolate(
        specimen_type="Sputum",
        pathogen="Neisseria gonorrhoeae",
        ast_panel=ast_panel,
    )
    assert any(f["category"] == "specimen_pathogen_mismatch" for f in audit.findings)


def test_demographic_mismatch():
    # Male cervical swab
    audit = audit_lab_isolate(
        specimen_type="Cervical swab",
        pathogen="Escherichia coli",
        ast_panel=[],
        patient_sex="Male",
    )
    assert audit.status == "CRITICAL_ANOMALY"
    assert any(f["category"] == "demographic_mismatch" for f in audit.findings)


def test_clinical_report_ocr_parsing():
    text = """
    Patient: Rajesh Verma | Age: 55 yrs | Sex: Male | District: Mumbai
    Complaints: Fever with severe cough and breathlessness for 3 days.
    Diagnosis: Community Acquired Pneumonia
    Syndrome: Pneumonia / Lower respiratory
    Origin: Community-acquired
    """
    res = parse_raw_clinical_text(text)
    extracted = res["extracted"]
    assert extracted["full_name"] == "Rajesh Verma"
    assert extracted["exact_age"] == 55
    assert extracted["age_group"] == "45-64"
    assert extracted["sex"] == "Male"
    assert extracted["district"] == "Mumbai"
    assert "Fever" in extracted["symptoms"]
    assert "Cough" in extracted["symptoms"]
    assert res["intelligence_audit"]["is_valid"] is True


def test_lab_ast_ocr_parsing():
    text = """
    Lab No: ACC-2026-9912
    Specimen: Urine
    Organism: Escherichia coli
    AST Results:
    - Ampicillin: Resistant
    - Ceftriaxone: Resistant
    - Ciprofloxacin: Resistant
    - Meropenem: Susceptible
    """
    res = parse_raw_ast_text(text)
    extracted = res["extracted"]
    assert extracted["specimen_type"] == "Urine"
    assert extracted["pathogen"] == "Escherichia coli"
    assert len(extracted["ast_panel"]) == 4
    assert res["intelligence_audit"]["mdr_flag"] is True  # Penicillin + Cephalo + Fluoroquinolone = 3 classes


from scripts.seed import seed, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD

def test_ingestion_api_endpoints():
    seed()
    client = TestClient(app)
    resp = client.post("/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD})
    assert resp.status_code == 200
    token = resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Test sample documents endpoint
    res = client.get("/api/v1/ingestion/sample-documents")
    assert res.status_code == 200
    assert "doctor_pneumonia_prescription" in res.json()

    # Test OCR parse endpoint
    parse_payload = {
        "document_type": "clinical_report",
        "raw_text": "Patient Name: Priya Sen, Age: 28, Sex: Female, District: Pune, Diagnosis: UTI, Complaints: Burning urination and fever.",
    }
    res = client.post("/api/v1/ingestion/ocr-parse", json=parse_payload, headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["extracted"]["sex"] == "Female"
    assert data["extracted"]["district"] == "Pune"
    assert data["intelligence_audit"]["is_valid"] is True

    # Test validate-isolate endpoint
    iso_payload = {
        "specimen_type": "Blood",
        "pathogen": "Pseudomonas aeruginosa",
        "ast_panel": [
            {"antibiotic": "Ampicillin", "antibiotic_class": "Penicillins", "ast_result": "Susceptible"}
        ],
    }
    res = client.post("/api/v1/ingestion/validate-isolate", json=iso_payload, headers=headers)
    assert res.status_code == 200
    iso_data = res.json()
    assert iso_data["status"] == "CRITICAL_ANOMALY"
