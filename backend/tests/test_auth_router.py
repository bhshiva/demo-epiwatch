from fastapi.testclient import TestClient
from app.main import app
from scripts.seed import seed, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD

client = TestClient(app)


def test_login_success():
    seed()
    resp = client.post("/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD})
    assert resp.status_code == 200
    body = resp.json()
    assert "access_token" in body
    assert body["name"] == "Dr. Asha Rao"


def test_login_wrong_password():
    seed()
    resp = client.post("/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": "wrong-password"})
    assert resp.status_code == 401


def test_login_unknown_email():
    resp = client.post("/auth/login", json={"email": "nobody@example.com", "password": "whatever"})
    assert resp.status_code == 401


def test_protected_endpoint_requires_token():
    resp = client.get("/dashboard/summary")
    assert resp.status_code in (401, 403, 404)
