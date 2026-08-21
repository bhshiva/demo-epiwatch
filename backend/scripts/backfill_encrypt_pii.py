"""
One-off backfill: encrypt existing plaintext PII/clinical-text rows into
the _enc columns added by migration 012.

Raw SQL rather than the ORM: the _enc columns are a transient step (dropped
again, renamed to the original names, by migration 013 once this backfill is
verified), so they were never added to app/models.py -- no reason to churn
the model definitions for a step that only exists for one migration cycle.

Idempotent -- skips any row whose _enc column is already populated, so this
is safe to re-run (e.g. after an interrupted run).

Usage (from backend/, inside its venv):
    python -m scripts.backfill_encrypt_pii

Run this once, verify the row counts it reports look right, THEN apply
migration 013 (which drops the plaintext columns). Do not apply 013 before
running this.
"""

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import text

from app.db import SessionLocal
from app.services.crypto import PGCRYPTO_KEY, hash_field


def _backfill_patient_identities(db) -> int:
    result = db.execute(
        text(
            """
            UPDATE master.patient_identities
            SET
                full_name_enc = COALESCE(full_name_enc, pgp_sym_encrypt(full_name, :key)),
                date_of_birth_enc = COALESCE(
                    date_of_birth_enc,
                    CASE WHEN date_of_birth IS NOT NULL
                         THEN pgp_sym_encrypt(date_of_birth::text, :key)
                    END
                ),
                contact_number_enc = COALESCE(
                    contact_number_enc,
                    CASE WHEN contact_number IS NOT NULL
                         THEN pgp_sym_encrypt(contact_number, :key)
                    END
                ),
                facility_mrn_enc = COALESCE(
                    facility_mrn_enc,
                    CASE WHEN facility_mrn IS NOT NULL
                         THEN pgp_sym_encrypt(facility_mrn, :key)
                    END
                )
            WHERE full_name_enc IS NULL
               OR (date_of_birth IS NOT NULL AND date_of_birth_enc IS NULL)
               OR (contact_number IS NOT NULL AND contact_number_enc IS NULL)
               OR (facility_mrn IS NOT NULL AND facility_mrn_enc IS NULL)
            """
        ),
        {"key": PGCRYPTO_KEY},
    )
    db.commit()

    # facility_mrn_hash is the deterministic blind index the uniqueness
    # constraint and Tier-1 exact-MRN matching move to (see crypto.py). HMAC
    # needs the key from Python, not SQL, so this is a separate pass rather
    # than folded into the UPDATE above.
    rows = db.execute(
        text(
            "SELECT identity_id, facility_mrn FROM master.patient_identities "
            "WHERE facility_mrn IS NOT NULL AND facility_mrn_hash IS NULL"
        )
    ).all()
    for identity_id, facility_mrn in rows:
        db.execute(
            text("UPDATE master.patient_identities SET facility_mrn_hash = :h WHERE identity_id = :id"),
            {"h": hash_field(facility_mrn.strip().lower()), "id": identity_id},
        )
    db.commit()

    return result.rowcount


def _backfill_patient_reports(db) -> int:
    result = db.execute(
        text(
            """
            UPDATE raw.patient_reports
            SET
                complaints_enc = COALESCE(
                    complaints_enc,
                    CASE WHEN complaints IS NOT NULL THEN pgp_sym_encrypt(complaints, :key) END
                ),
                medical_history_enc = COALESCE(
                    medical_history_enc,
                    CASE WHEN medical_history IS NOT NULL THEN pgp_sym_encrypt(medical_history, :key) END
                ),
                treatment_enc = COALESCE(
                    treatment_enc,
                    CASE WHEN treatment IS NOT NULL THEN pgp_sym_encrypt(treatment, :key) END
                )
            WHERE (complaints IS NOT NULL AND complaints_enc IS NULL)
               OR (medical_history IS NOT NULL AND medical_history_enc IS NULL)
               OR (treatment IS NOT NULL AND treatment_enc IS NULL)
            """
        ),
        {"key": PGCRYPTO_KEY},
    )
    db.commit()
    return result.rowcount


def run() -> None:
    db = SessionLocal()
    try:
        identities = _backfill_patient_identities(db)
        reports = _backfill_patient_reports(db)
        print(f"Encrypted {identities} patient_identities row(s)")
        print(f"Encrypted {reports} patient_reports row(s)")
    finally:
        db.close()


if __name__ == "__main__":
    run()
