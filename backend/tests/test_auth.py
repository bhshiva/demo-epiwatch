import os
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("DATABASE_URL", "postgresql://test/test")

import uuid
from datetime import datetime, timedelta
import pytest
import jwt as pyjwt

from app.auth import (
    hash_password,
    verify_password,
    create_access_token,
    decode_access_token,
    record_login_failure,
    record_login_success,
    is_locked,
)
from app.models import Doctor

def make_doctor(**overrides):
    defaults = dict(
        doctor_id=uuid.uuid4(),
        name="Dr. Test",
        facility_id=uuid.uuid4(),
        email="doc@example.com",
        password_hash=hash_password("correct-horse"),
        failed_login_count=0,
        locked_until=None,
    )
    defaults.update(overrides)
    return Doctor(**defaults)

def test_hash_and_verify_roundtrip():
    hashed = hash_password("s3cret!")
    assert hashed != "s3cret!"
    assert verify_password("s3cret!", hashed) is True
    assert verify_password("wrong", hashed) is False

def test_token_roundtrip():
    doctor_id = str(uuid.uuid4())
    token = create_access_token(doctor_id)
    payload = decode_access_token(token)
    assert payload["sub"] == doctor_id

def test_decode_invalid_token_raises():
    with pytest.raises(pyjwt.InvalidTokenError):
        decode_access_token("not-a-real-token")

def test_record_login_failure_increments_count():
    doctor = make_doctor(failed_login_count=0)
    record_login_failure(doctor)
    assert doctor.failed_login_count == 1
    assert doctor.locked_until is None

def test_fifth_failure_locks_account():
    doctor = make_doctor(failed_login_count=4)
    record_login_failure(doctor)
    assert doctor.failed_login_count == 5
    assert doctor.locked_until is not None
    assert doctor.locked_until > datetime.utcnow()

def test_record_login_success_resets_counters():
    doctor = make_doctor(failed_login_count=3, locked_until=datetime.utcnow() + timedelta(minutes=5))
    record_login_success(doctor)
    assert doctor.failed_login_count == 0
    assert doctor.locked_until is None

def test_is_locked_true_when_locked_until_future():
    doctor = make_doctor(locked_until=datetime.utcnow() + timedelta(minutes=5))
    assert is_locked(doctor) is True

def test_is_locked_false_when_locked_until_past():
    doctor = make_doctor(locked_until=datetime.utcnow() - timedelta(minutes=5))
    assert is_locked(doctor) is False

def test_is_locked_false_when_never_locked():
    doctor = make_doctor(locked_until=None)
    assert is_locked(doctor) is False
