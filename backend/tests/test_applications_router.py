"""Facility onboarding: public application submission, admin-only review."""

import uuid

from fastapi.testclient import TestClient

from app.main import app
from scripts.seed import (
    SEED_ADMIN_EMAIL,
    SEED_ADMIN_PASSWORD,
    SEED_DOCTOR_EMAIL,
    SEED_DOCTOR_PASSWORD,
    seed,
)

client = TestClient(app)


def _headers(email, password):
    seed()
    resp = client.post("/auth/login", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def _admin_headers():
    return _headers(SEED_ADMIN_EMAIL, SEED_ADMIN_PASSWORD)


def _doctor_headers():
    return _headers(SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD)


def _application(**overrides):
    payload = {
        "facility_name": f"Test Clinic {uuid.uuid4().hex[:8]}",
        "facility_type": "Clinic",
        "district": "Nashik",
        "state": "Maharashtra",
        "contact_name": "Dr. Test Applicant",
        "contact_email": f"applicant-{uuid.uuid4().hex[:8]}@example.com",
        "requested_role": "doctor",
    }
    payload.update(overrides)
    return payload


def test_submission_requires_no_authentication():
    resp = client.post("/applications", json=_application())
    assert resp.status_code == 201
    assert resp.json()["status"] == "pending"


def test_only_admin_can_list_or_review_applications():
    app_resp = client.post("/applications", json=_application()).json()

    doctor_headers = _doctor_headers()
    assert client.get("/admin/applications", headers=doctor_headers).status_code == 403
    assert (
        client.post(
            f"/admin/applications/{app_resp['application_id']}/approve", headers=doctor_headers
        ).status_code
        == 403
    )


def test_admin_can_approve_and_the_account_can_then_log_in():
    admin_headers = _admin_headers()
    submitted = client.post("/applications", json=_application()).json()

    approved = client.post(
        f"/admin/applications/{submitted['application_id']}/approve", headers=admin_headers
    )
    assert approved.status_code == 200
    body = approved.json()
    assert body["application"]["status"] == "approved"
    assert body["temporary_password"]

    login = client.post(
        "/auth/login", json={"email": body["email"], "password": body["temporary_password"]}
    )
    assert login.status_code == 200
    assert login.json()["must_change_password"] is True


def test_approving_the_same_application_twice_conflicts():
    admin_headers = _admin_headers()
    submitted = client.post("/applications", json=_application()).json()

    client.post(f"/admin/applications/{submitted['application_id']}/approve", headers=admin_headers)
    repeat = client.post(
        f"/admin/applications/{submitted['application_id']}/approve", headers=admin_headers
    )
    assert repeat.status_code == 409


def test_admin_can_reject_with_a_reason():
    admin_headers = _admin_headers()
    submitted = client.post("/applications", json=_application()).json()

    resp = client.post(
        f"/admin/applications/{submitted['application_id']}/reject",
        json={"reason": "Facility could not be verified"},
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "rejected"
    assert resp.json()["rejection_reason"] == "Facility could not be verified"


def test_must_change_password_is_cleared_after_change_password():
    admin_headers = _admin_headers()
    submitted = client.post("/applications", json=_application()).json()
    approved = client.post(
        f"/admin/applications/{submitted['application_id']}/approve", headers=admin_headers
    ).json()

    login = client.post(
        "/auth/login",
        json={"email": approved["email"], "password": approved["temporary_password"]},
    ).json()
    new_headers = {"Authorization": f"Bearer {login['access_token']}"}

    changed = client.post(
        "/auth/change-password",
        json={"current_password": approved["temporary_password"], "new_password": "NewPass123!"},
        headers=new_headers,
    )
    assert changed.status_code == 200

    relogin = client.post(
        "/auth/login", json={"email": approved["email"], "password": "NewPass123!"}
    )
    assert relogin.status_code == 200
    assert relogin.json()["must_change_password"] is False
