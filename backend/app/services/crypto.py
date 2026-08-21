"""
Column-level encryption for PII / clinical free text, via pgcrypto
(pgp_sym_encrypt/pgp_sym_decrypt -- already enabled by the migration runner).

The key is loaded once from PGCRYPTO_KEY (mirroring how JWT_SECRET is loaded
in app/auth.py) and passed as a bound query parameter on every call, never
string-interpolated into SQL and never stored as a Postgres session
setting/GUC -- both of those would leave it recoverable from a query log or
`SHOW`. A wrong key raises rather than silently returning garbage (verified
against this project's actual pgcrypto extension, not assumed).

Encrypted: master.patient_identities.full_name/date_of_birth/contact_number/
facility_mrn, raw.patient_reports.complaints/medical_history/treatment.
NOT encrypted: abha_id (needs its existing plaintext unique index for ABDM
lookups and Tier-1 duplicate matching), all coded/enum fields, symptoms
JSONB (structured, not free text).
"""

import hashlib
import hmac
import os
from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

PGCRYPTO_KEY = os.environ["PGCRYPTO_KEY"]


def encrypt_field(db: Session, plaintext: str | None) -> bytes | None:
    if plaintext is None:
        return None
    return db.execute(
        text("SELECT pgp_sym_encrypt(:v, :k)"), {"v": plaintext, "k": PGCRYPTO_KEY}
    ).scalar()


def decrypt_field(db: Session, ciphertext: bytes | None) -> str | None:
    if ciphertext is None:
        return None
    return db.execute(
        text("SELECT pgp_sym_decrypt(:v, :k)"), {"v": ciphertext, "k": PGCRYPTO_KEY}
    ).scalar()


def encrypt_date(db: Session, value: date | None) -> bytes | None:
    return encrypt_field(db, value.isoformat() if value is not None else None)


def decrypt_date(db: Session, ciphertext: bytes | None) -> date | None:
    raw = decrypt_field(db, ciphertext)
    return date.fromisoformat(raw) if raw is not None else None


def hash_field(value: str | None) -> str | None:
    """
    Deterministic blind index for equality lookups/uniqueness on a field
    that's otherwise stored encrypted (pgp_sym_encrypt is non-deterministic
    -- the same plaintext encrypts to different bytes each call, so neither
    a UNIQUE constraint nor an equality WHERE can target the ciphertext
    column directly). HMAC-SHA256 keyed by PGCRYPTO_KEY: deterministic (same
    input always hashes the same, so it works as an index and a uniqueness
    key) and one-way (doesn't reveal the plaintext, unlike a plain SHA-256
    which would be vulnerable to a dictionary attack over likely values).
    """
    if value is None:
        return None
    return hmac.new(PGCRYPTO_KEY.encode(), value.encode(), hashlib.sha256).hexdigest()
