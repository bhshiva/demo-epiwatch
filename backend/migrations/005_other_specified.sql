-- Coded dropdowns keep aggregation reliable, but "Other" on its own records
-- that something was unusual without recording WHAT. These columns hold the
-- clinician's free-text detail alongside the coded value, so the code stays
-- clean for counting while the finding itself survives.
ALTER TABLE raw.lab_results
    ADD COLUMN IF NOT EXISTS specimen_type_other  VARCHAR,
    ADD COLUMN IF NOT EXISTS culture_result_other VARCHAR,
    ADD COLUMN IF NOT EXISTS pathogen_other       VARCHAR;

-- Promote the ACORN clinical-context fields out of the medical_history text
-- prefix into real columns. As free text inside another field they could not
-- be filtered or aggregated, which defeated the point of collecting them.
ALTER TABLE raw.patient_reports
    ADD COLUMN IF NOT EXISTS infection_syndrome       VARCHAR,
    ADD COLUMN IF NOT EXISTS infection_syndrome_other VARCHAR,
    ADD COLUMN IF NOT EXISTS infection_origin         VARCHAR,
    ADD COLUMN IF NOT EXISTS patient_outcome          VARCHAR,
    ADD COLUMN IF NOT EXISTS patient_outcome_other    VARCHAR;
