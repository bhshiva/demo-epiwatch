-- PII / clinical-text encryption, step 3 of 3 (final).
--
-- Drops the plaintext columns and renames the _enc columns into their place.
-- Only run this after scripts/backfill_encrypt_pii.py has completed and
-- been verified (every row's _enc column matches its plaintext on decrypt) --
-- this migration is irreversible in the sense that the plaintext columns it
-- drops are gone; the encrypted data survives under the original column
-- names from here on.
--
-- The trigram GIN index on full_name (ix_patient_identities_name_trgm) and
-- the functional index on contact_number (ix_patient_identities_contact)
-- cannot be carried forward: an index can't accelerate a query against
-- ciphertext. app/services/patient_matching.py has been rewritten to
-- decrypt inline (pgp_sym_decrypt(...) inside similarity()/dmetaphone()),
-- which means those specific candidate-matching queries now do a full scan
-- within WHERE facility_id = :facility_id -- accepted at this project's
-- scale (one clinic's patient volume per query, not a hospital chain), and
-- documented here rather than silently lost.

DROP INDEX IF EXISTS master.ix_patient_identities_name_trgm;
DROP INDEX IF EXISTS master.ix_patient_identities_contact;

-- facility_mrn's old unique index (migration 003) enforced uniqueness by
-- comparing plaintext bytes. pgp_sym_encrypt is non-deterministic, so that
-- same comparison against ciphertext would essentially never match --
-- silently disabling duplicate-MRN prevention rather than erroring, which
-- is worse than not having the constraint at all. Dropping
-- ux_patient_identities_facility_mrn (implicitly, via the column drop
-- below) and replacing it with a unique index on facility_mrn_hash -- a
-- deterministic HMAC blind index (crypto.py:hash_field) populated by
-- scripts/backfill_encrypt_pii.py -- restores the real guarantee.
CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_identities_facility_mrn_hash
    ON master.patient_identities (facility_id, facility_mrn_hash)
    WHERE facility_mrn_hash IS NOT NULL;

ALTER TABLE master.patient_identities DROP COLUMN full_name;
ALTER TABLE master.patient_identities RENAME COLUMN full_name_enc TO full_name;
ALTER TABLE master.patient_identities ALTER COLUMN full_name SET NOT NULL;

ALTER TABLE master.patient_identities DROP COLUMN date_of_birth;
ALTER TABLE master.patient_identities RENAME COLUMN date_of_birth_enc TO date_of_birth;

ALTER TABLE master.patient_identities DROP COLUMN contact_number;
ALTER TABLE master.patient_identities RENAME COLUMN contact_number_enc TO contact_number;

ALTER TABLE master.patient_identities DROP COLUMN facility_mrn;
ALTER TABLE master.patient_identities RENAME COLUMN facility_mrn_enc TO facility_mrn;

ALTER TABLE raw.patient_reports DROP COLUMN complaints;
ALTER TABLE raw.patient_reports RENAME COLUMN complaints_enc TO complaints;

ALTER TABLE raw.patient_reports DROP COLUMN medical_history;
ALTER TABLE raw.patient_reports RENAME COLUMN medical_history_enc TO medical_history;

ALTER TABLE raw.patient_reports DROP COLUMN treatment;
ALTER TABLE raw.patient_reports RENAME COLUMN treatment_enc TO treatment;
