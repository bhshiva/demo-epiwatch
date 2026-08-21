-- PII / clinical-text encryption, step 1 of 3.
--
-- Adds sibling encrypted columns next to the plaintext ones. No data is
-- touched here and no key is involved in this file -- the key only ever
-- appears as a bound query parameter from app code (app/services/crypto.py),
-- never in a migration file or a stored Postgres setting.
--
-- Sequence: this migration (schema only) -> scripts/backfill_encrypt_pii.py
-- (run once, by hand, after PGCRYPTO_KEY is set -- encrypts existing rows
-- into the _enc columns) -> migration 013 (drops the plaintext columns and
-- renames _enc -> the original names, run only after the backfill is
-- verified). Splitting it this way means there is always a point to stop
-- and check before the plaintext columns are actually removed.
--
-- NOT encrypted: abha_id (keeps its plaintext unique index for ABDM lookups
-- and Tier-1 duplicate matching), all coded/enum fields, symptoms JSONB
-- (structured, not free text).

ALTER TABLE master.patient_identities ADD COLUMN IF NOT EXISTS full_name_enc BYTEA;
ALTER TABLE master.patient_identities ADD COLUMN IF NOT EXISTS date_of_birth_enc BYTEA;
ALTER TABLE master.patient_identities ADD COLUMN IF NOT EXISTS contact_number_enc BYTEA;
ALTER TABLE master.patient_identities ADD COLUMN IF NOT EXISTS facility_mrn_enc BYTEA;

-- pgp_sym_encrypt is non-deterministic (the same plaintext encrypts to
-- different bytes each call), so neither a UNIQUE constraint nor an
-- equality lookup can target facility_mrn_enc directly. This deterministic
-- HMAC blind index (app/services/crypto.py:hash_field) is what the
-- uniqueness constraint and Tier-1 exact-MRN matching move to instead.
ALTER TABLE master.patient_identities ADD COLUMN IF NOT EXISTS facility_mrn_hash VARCHAR;

ALTER TABLE raw.patient_reports ADD COLUMN IF NOT EXISTS complaints_enc BYTEA;
ALTER TABLE raw.patient_reports ADD COLUMN IF NOT EXISTS medical_history_enc BYTEA;
ALTER TABLE raw.patient_reports ADD COLUMN IF NOT EXISTS treatment_enc BYTEA;
