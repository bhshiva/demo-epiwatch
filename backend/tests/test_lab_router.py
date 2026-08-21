"""Laboratory role and isolate submission."""

import uuid

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.models import Doctor
from app.routers.lab import lab_user
from scripts.seed import (
    SEED_DOCTOR_EMAIL,
    SEED_DOCTOR_PASSWORD,
    SEED_LAB_EMAIL,
    SEED_LAB_PASSWORD,
    seed,
)

client = TestClient(app)


def _headers(email, password):
    seed()
    resp = client.post("/auth/login", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def _lab_headers():
    return _headers(SEED_LAB_EMAIL, SEED_LAB_PASSWORD)


def _doctor_headers():
    return _headers(SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD)


def _panel(**overrides):
    payload = {
        "accession_no": f"ACC-{uuid.uuid4().hex[:8]}",
        "test_date": "2026-08-19",
        "specimen_type": "Blood",
        "culture_result": "Growth - organism identified",
        "pathogen": "Klebsiella pneumoniae",
        "infection_origin": "Hospital-acquired",
        "status": "final",
        "ast_results": [
            {"antibiotic": "Meropenem", "ast_result": "Resistant"},
            {"antibiotic": "Ciprofloxacin", "ast_result": "Resistant"},
            {"antibiotic": "Gentamicin", "ast_result": "Resistant"},
            {"antibiotic": "Colistin", "ast_result": "Susceptible"},
        ],
    }
    payload.update(overrides)
    return payload


def test_lab_routes_require_authentication():
    assert client.get("/lab/worklist").status_code in (401, 403)
    assert client.post("/lab/isolates", json=_panel()).status_code in (401, 403)


def test_a_doctor_cannot_reach_lab_routes():
    """Role is a real boundary, not a UI convenience."""
    headers = _doctor_headers()
    assert client.get("/lab/worklist", headers=headers).status_code == 403
    assert client.post("/lab/isolates", json=_panel(), headers=headers).status_code == 403


def test_admin_no_longer_has_lab_access():
    """
    Admin's job is facility onboarding, not patient/isolate data. It used to
    piggyback on lab.py's require_role("lab", "admin") grant; that grant was
    removed once the admin role's real purpose (application review) was
    defined, so admin must be rejected here exactly like any other role.
    """
    admin = Doctor(name="Admin", email="a@x", password_hash="x", role="admin")
    with pytest.raises(HTTPException) as exc:
        lab_user(user=admin)
    assert exc.value.status_code == 403


def test_login_returns_the_role():
    seed()
    lab = client.post(
        "/auth/login", json={"email": SEED_LAB_EMAIL, "password": SEED_LAB_PASSWORD}
    ).json()
    doctor = client.post(
        "/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD}
    ).json()

    assert lab["role"] == "lab"
    assert doctor["role"] == "doctor"


def test_lab_can_submit_a_full_panel():
    """The shape raw.lab_results could not represent."""
    resp = client.post("/lab/isolates", json=_panel(), headers=_lab_headers())

    assert resp.status_code == 201
    body = resp.json()
    assert len(body["ast_results"]) == 4
    assert body["pathogen"] == "Klebsiella pneumoniae"


def test_antibiotic_class_is_derived_when_omitted():
    """MDR counting is by class, so the class cannot be left to the caller."""
    body = client.post("/lab/isolates", json=_panel(), headers=_lab_headers()).json()

    by_drug = {a["antibiotic"]: a["antibiotic_class"] for a in body["ast_results"]}
    assert by_drug["Meropenem"] == "Carbapenems"
    assert by_drug["Ciprofloxacin"] == "Fluoroquinolones"
    assert by_drug["Colistin"] == "Polymyxins"


def test_mdr_is_flagged_across_three_or_more_classes():
    """WHO/ECDC define MDR by resistant classes, not by resistant drugs."""
    resistant_three_classes = client.post(
        "/lab/isolates", json=_panel(), headers=_lab_headers()
    ).json()
    assert resistant_three_classes["is_mdr"] is True

    # Two drugs from a single class is not multidrug resistance.
    same_class = client.post(
        "/lab/isolates",
        json=_panel(
            ast_results=[
                {"antibiotic": "Ciprofloxacin", "ast_result": "Resistant"},
                {"antibiotic": "Levofloxacin", "ast_result": "Resistant"},
            ]
        ),
        headers=_lab_headers(),
    ).json()
    assert same_class["is_mdr"] is False


def test_not_tested_is_excluded_from_the_denominator():
    """Counting untested drugs as susceptible would understate resistance."""
    body = client.post(
        "/lab/isolates",
        json=_panel(
            ast_results=[
                {"antibiotic": "Meropenem", "ast_result": "Resistant"},
                {"antibiotic": "Colistin", "ast_result": "Susceptible"},
                {"antibiotic": "Tigecycline", "ast_result": "Not tested"},
            ]
        ),
        headers=_lab_headers(),
    ).json()

    assert len(body["ast_results"]) == 3
    assert body["tested_count"] == 2
    assert body["resistant_count"] == 1


def test_duplicate_antibiotic_in_one_panel_is_rejected():
    resp = client.post(
        "/lab/isolates",
        json=_panel(
            ast_results=[
                {"antibiotic": "Meropenem", "ast_result": "Resistant"},
                {"antibiotic": "Meropenem", "ast_result": "Susceptible"},
            ]
        ),
        headers=_lab_headers(),
    )
    assert resp.status_code == 400


def test_isolate_can_be_recorded_without_a_doctor_report():
    """A lab reports on a specimen whether or not a clinician has filed one."""
    body = client.post(
        "/lab/isolates", json=_panel(report_id=None), headers=_lab_headers()
    ).json()
    assert body["report_id"] is None


def test_worklist_holds_only_unfinished_cultures():
    headers = _lab_headers()
    client.post("/lab/isolates", json=_panel(status="pending"), headers=headers)
    client.post("/lab/isolates", json=_panel(status="final"), headers=headers)

    worklist = client.get("/lab/worklist", headers=headers).json()
    assert all(i["status"] in ("pending", "preliminary") for i in worklist)


def test_amendment_supersedes_rather_than_overwrites():
    """
    An AST result a clinician already prescribed against must remain
    reconstructible, so a correction is a new row linked to the old one.
    """
    headers = _lab_headers()
    original = client.post("/lab/isolates", json=_panel(), headers=headers).json()

    corrected = client.patch(
        f"/lab/isolates/{original['isolate_id']}",
        json=_panel(
            pathogen="Escherichia coli",
            ast_results=[{"antibiotic": "Meropenem", "ast_result": "Susceptible"}],
        ),
        headers=headers,
    )
    assert corrected.status_code == 200
    assert corrected.json()["isolate_id"] != original["isolate_id"]

    superseded = client.get(f"/lab/isolates/{original['isolate_id']}", headers=headers).json()
    assert superseded["status"] == "amended"
    assert superseded["pathogen"] == "Klebsiella pneumoniae"  # original preserved


def test_an_already_amended_result_cannot_be_amended_again():
    headers = _lab_headers()
    original = client.post("/lab/isolates", json=_panel(), headers=headers).json()
    client.patch(f"/lab/isolates/{original['isolate_id']}", json=_panel(), headers=headers)

    repeat = client.patch(
        f"/lab/isolates/{original['isolate_id']}", json=_panel(), headers=headers
    )
    assert repeat.status_code == 409


def test_unknown_isolate_returns_404():
    resp = client.get(f"/lab/isolates/{uuid.uuid4()}", headers=_lab_headers())
    assert resp.status_code == 404


def test_summary_excludes_untested_drugs_from_the_resistance_rate():
    headers = _lab_headers()
    body = client.get("/lab/summary", headers=headers).json()

    assert set(body) == {
        "isolates_today",
        "pending_cultures",
        "mdr_isolates_week",
        "resistance_rate_week",
    }
    if body["resistance_rate_week"] is not None:
        assert 0.0 <= body["resistance_rate_week"] <= 1.0
