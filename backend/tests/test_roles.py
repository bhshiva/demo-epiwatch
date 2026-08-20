"""Role-based access control."""

import uuid

import pytest
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient

from app.auth import create_access_token, decode_access_token
from app.db import SessionLocal
from app.deps import get_current_doctor, require_role
from app.models import Doctor
from scripts.seed import SEED_LAB_EMAIL, SEED_DOCTOR_EMAIL, SEED_DOCTOR_PASSWORD, seed


def test_token_carries_the_role():
    token = create_access_token(str(uuid.uuid4()), "lab")
    assert decode_access_token(token)["role"] == "lab"


def test_token_defaults_to_doctor():
    """Keeps existing callers working without change."""
    token = create_access_token(str(uuid.uuid4()))
    assert decode_access_token(token)["role"] == "doctor"


def test_require_role_allows_a_permitted_role():
    dependency = require_role("lab", "admin")
    user = Doctor(name="Tech", email="t@x", password_hash="x", role="lab")
    assert dependency(user=user) is user


def test_require_role_rejects_others_with_403():
    dependency = require_role("lab")
    user = Doctor(name="Doc", email="d@x", password_hash="x", role="doctor")

    with pytest.raises(HTTPException) as exc:
        dependency(user=user)
    assert exc.value.status_code == 403


def test_require_role_names_what_is_needed():
    """A bare 'forbidden' leaves the caller with nowhere to go."""
    dependency = require_role("lab", "admin")
    user = Doctor(name="Doc", email="d@x", password_hash="x", role="doctor")

    with pytest.raises(HTTPException) as exc:
        dependency(user=user)
    assert "lab" in exc.value.detail and "admin" in exc.value.detail


def test_authorisation_reads_the_database_not_the_token():
    """
    A token issued before a role change must not retain its old privileges.
    Trusting the claim would leave that access valid until expiry -- up to
    twelve hours for this app's tokens.
    """
    seed()
    db = SessionLocal()
    try:
        lab_user = db.query(Doctor).filter_by(email=SEED_LAB_EMAIL).first()
        assert lab_user is not None and lab_user.role == "lab"

        # Token still claims "lab" after the row is demoted.
        stale_token = create_access_token(str(lab_user.doctor_id), "lab")
        lab_user.role = "doctor"
        db.commit()

        app = FastAPI()

        @app.get("/lab-only")
        def lab_only(user: Doctor = Depends(require_role("lab"))):
            return {"ok": True}

        client = TestClient(app)
        resp = client.get("/lab-only", headers={"Authorization": f"Bearer {stale_token}"})
        assert resp.status_code == 403, "a stale role claim must not grant access"
    finally:
        # Restore, so the suite can be re-run.
        restore = db.query(Doctor).filter_by(email=SEED_LAB_EMAIL).first()
        if restore is not None:
            restore.role = "lab"
            db.commit()
        db.close()


def test_existing_accounts_default_to_doctor():
    """Migration 008 added the column with a default, so no backfill was needed."""
    seed()
    db = SessionLocal()
    try:
        doctor = db.query(Doctor).filter_by(email=SEED_DOCTOR_EMAIL).first()
        assert doctor.role == "doctor"
    finally:
        db.close()
