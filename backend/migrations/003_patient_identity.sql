-- Patient identity layer.
--
-- Identity is kept in its own table, deliberately NOT in master.patients,
-- so the privacy boundary is structural rather than a convention:
--
--   surveillance / analytics  ->  master.patients -> raw.patient_reports
--                                 (age band, sex, district only)
--
--   clinical continuity       ->  master.patient_identities -> master.patients
--                                 (name, DOB, contact, facility MRN)
--
-- Aggregation queries join the first path and can never see a name. Only the
-- treating facility's own clinicians traverse the second.

CREATE TABLE IF NOT EXISTS master.patient_identities (
    identity_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES master.patients(patient_id),
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),
    full_name VARCHAR NOT NULL,
    date_of_birth DATE,
    contact_number VARCHAR,
    facility_mrn VARCHAR,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- One identity record per patient handle.
CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_identities_patient
    ON master.patient_identities (patient_id);

-- Name search is the primary lookup and is always facility-scoped.
CREATE INDEX IF NOT EXISTS ix_patient_identities_facility_name
    ON master.patient_identities (facility_id, lower(full_name));

-- A facility's own medical record number must stay unique within that facility.
CREATE UNIQUE INDEX IF NOT EXISTS ux_patient_identities_facility_mrn
    ON master.patient_identities (facility_id, facility_mrn)
    WHERE facility_mrn IS NOT NULL;

-- Exact age supports clinical judgement; age_group remains the aggregation key
-- and is derived from it, so surveillance behaviour is unchanged.
ALTER TABLE master.patients
    ADD COLUMN IF NOT EXISTS exact_age INTEGER;
