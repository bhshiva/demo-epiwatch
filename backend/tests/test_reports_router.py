import uuid

from fastapi.testclient import TestClient
from app.main import app
from scripts.seed import seed, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD

client = TestClient(app)


def _login_headers():
    seed()
    resp = client.post("/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD})
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


def test_create_report():
    headers = _login_headers()
    payload = {
        "patient_age_group": "30-40",
        "patient_sex": "F",
        "patient_district": "Pune",
        "report_date": "2026-08-17",
        "complaints": "Fever and cough",
        "symptoms": ["fever", "cough"],
        "diagnosis": "Suspected influenza",
        "diagnosis_status": "Suspected",
        "prescriptions": [{"drug_name": "Paracetamol", "dosage": "500mg", "duration": "5 days"}],
    }
    resp = client.post("/reports", json=payload, headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert body["diagnosis"] == "Suspected influenza"
    assert body["diagnosis_status"] == "Suspected"


def test_create_report_requires_auth():
    resp = client.post("/reports", json={
        "patient_age_group": "30-40", "patient_sex": "F", "patient_district": "Pune",
        "report_date": "2026-08-17",
    })
    assert resp.status_code == 401


def test_list_reports_returns_only_own_reports():
    headers = _login_headers()
    client.post("/reports", json={
        "patient_age_group": "20-30", "patient_sex": "M", "patient_district": "Pune",
        "report_date": "2026-08-17", "diagnosis": "Test diagnosis",
    }, headers=headers)

    resp = client.get("/reports", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) >= 1
    assert all("report_id" in r for r in body)


def test_culture_result_is_persisted_and_returned_in_history():
    """
    Culture result was previously collected in the UI but had no column, no
    schema field and no DTO field, so it was silently dropped on submit.
    """
    headers = _login_headers()
    name = f"Culture Case {uuid.uuid4().hex[:6]}"

    create = client.post(
        "/reports",
        json={
            "patient_identity": {"full_name": name, "exact_age": 30},
            "confirmed_new": True,
            "patient_age_group": "25-44",
            "patient_sex": "Female",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Dysuria",
            "lab_result": {
                "specimen_type": "Urine",
                "culture_result": "No growth",
                "ast_result": "Not tested",
            },
        },
        headers=headers,
    )
    assert create.status_code == 200

    found = client.get("/patients/search?q=Culture", headers=headers).json()
    patient_id = next(p["patient_id"] for p in found if p["full_name"] == name)

    history = client.get(f"/patients/{patient_id}/history", headers=headers).json()
    assert history[0]["culture_result"] == "No growth"


def test_ast_result_not_tested_is_accepted():
    """The original CHECK constraint permitted only R/S/I and rejected this."""
    headers = _login_headers()
    resp = client.post(
        "/reports",
        json={
            "patient_age_group": "25-44",
            "patient_sex": "Male",
            "patient_district": "Pune",
            "report_date": "2026-08-19",
            "complaints": "Panel not run",
            "lab_result": {"pathogen": "Escherichia coli", "ast_result": "Not tested"},
        },
        headers=headers,
    )
    assert resp.status_code == 200
