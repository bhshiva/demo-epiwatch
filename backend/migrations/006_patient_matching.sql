-- Fuzzy matching support. Names are typed from memory, transliterated from
-- regional scripts, and misspelled; exact comparison alone cannot find the
-- duplicate a clinician is about to create.
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;

-- ABHA is India's 14-digit national health ID under ABDM. Where a patient
-- presents one, matching is deterministic and the fuzzy tier is unnecessary.
ALTER TABLE master.patient_identities
    ADD COLUMN IF NOT EXISTS abha_id VARCHAR;

-- Stored normalised (digits only) so comparison is exact.
ALTER TABLE master.patient_identities
    DROP CONSTRAINT IF EXISTS ck_patient_identities_abha_format;
ALTER TABLE master.patient_identities
    ADD CONSTRAINT ck_patient_identities_abha_format
    CHECK (abha_id IS NULL OR abha_id ~ '^[0-9]{14}$');

-- Facility-scoped, not national: the privacy boundary means a facility cannot
-- read another's identities, so a nationally unique index would reject a
-- legitimate registration the clinician cannot see or resolve. National
-- unification needs an ABDM-style consent layer first.
CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_identities_facility_abha
    ON master.patient_identities (facility_id, abha_id)
    WHERE abha_id IS NOT NULL;

-- Without this every duplicate check is a facility-wide sequential scan.
CREATE INDEX IF NOT EXISTS ix_patient_identities_name_trgm
    ON master.patient_identities USING gin (lower(full_name) gin_trgm_ops);

-- Normalise to last 10 digits so +91/0 prefixes compare equal.
CREATE INDEX IF NOT EXISTS ix_patient_identities_contact
    ON master.patient_identities (right(regexp_replace(contact_number, '\D', '', 'g'), 10))
    WHERE contact_number IS NOT NULL;
