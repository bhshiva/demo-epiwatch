from fastapi.testclient import TestClient
from app.main import app
from scripts.seed import seed, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD

client = TestClient(app)


def _login_headers():
    seed()
    resp = client.post("/auth/login", json={"email": SEED_DOCTOR_EMAIL, "password": SEED_DOCTOR_PASSWORD})
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def test_dashboard_summary_shape():
    headers = _login_headers()
    resp = client.get("/dashboard/summary", headers=headers)
    assert resp.status_code == 200
    body = resp.json()
    assert set(body.keys()) == {"patients_today", "reports_submitted_total", "active_conditions"}
    assert isinstance(body["patients_today"], int)


def test_dashboard_summary_requires_auth():
    resp = client.get("/dashboard/summary")
    assert resp.status_code in (401, 403, 404)
