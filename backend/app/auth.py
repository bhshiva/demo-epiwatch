import os
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.models import Doctor

_hasher = PasswordHasher()
JWT_SECRET = os.environ["JWT_SECRET"]
JWT_ALGORITHM = "HS256"
TOKEN_TTL_MINUTES = 60 * 12
LOCKOUT_THRESHOLD = 5
LOCKOUT_MINUTES = 15


def hash_password(plain: str) -> str:
    return _hasher.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return _hasher.verify(hashed, plain)
    except VerifyMismatchError:
        return False


def create_access_token(doctor_id: str, role: str = "doctor") -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": doctor_id,
        "role": role,
        "iat": now,
        "exp": now + timedelta(minutes=TOKEN_TTL_MINUTES),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])


def record_login_failure(doctor: Doctor) -> None:
    doctor.failed_login_count += 1
    if doctor.failed_login_count >= LOCKOUT_THRESHOLD:
        doctor.locked_until = datetime.utcnow() + timedelta(minutes=LOCKOUT_MINUTES)


def record_login_success(doctor: Doctor) -> None:
    doctor.failed_login_count = 0
    doctor.locked_until = None


def is_locked(doctor: Doctor) -> bool:
    return doctor.locked_until is not None and doctor.locked_until > datetime.utcnow()
