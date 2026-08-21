"""Health Authority surveillance API: read-only, all-facility, role-gated."""

from fastapi.testclient import TestClient

from app.main import app
from scripts.generate_surveillance_tables import run as run_etl
from scripts.seed import (
    SEED_DOCTOR_EMAIL,
    SEED_DOCTOR_PASSWORD,
    SEED_HEALTH_AUTHORITY_EMAIL,
    SEED_HEALTH_AUTHORITY_PASSWORD,
    seed,
)

client = TestClient(app)


def _headers(email, password):
    seed()
    resp = client.post("/auth/login", json={"email": email, "password": password})
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def _ha_headers():
    return _headers(SEED_HEALTH_AUTHORITY_EMAIL, SEED_HEALTH_AUTHORITY_PASSWORD)


def test_a_doctor_cannot_reach_surveillance_endpoints():
    headers = _headers(SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD)
    assert client.get("/surveillance/facilities-geo", headers=headers).status_code == 403


def test_disease_daily_returns_a_list():
    run_etl()
    resp = client.get("/surveillance/disease-daily", headers=_ha_headers())
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_facilities_geo_includes_the_seeded_facility():
    resp = client.get("/surveillance/facilities-geo", headers=_ha_headers())
    assert resp.status_code == 200
    body = resp.json()
    assert any(f["name"] == "City General Hospital" for f in body)
    for facility in body:
        assert "recent_case_count" in facility


def test_metrics_endpoint_requires_metric_name():
    resp = client.get("/surveillance/metrics", headers=_ha_headers())
    assert resp.status_code == 422


def test_metrics_returns_a_list_for_a_known_metric():
    run_etl()
    resp = client.get(
        "/surveillance/metrics", params={"metric_name": "resistance_rate"}, headers=_ha_headers()
    )
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
