-- Lab isolates and AST panels.
--
-- raw.lab_results collapsed three distinct things into one row: a specimen, an
-- organism recovered from it, and a single drug-versus-organism test result.
-- A real susceptibility panel tests one organism against 12-18 antibiotics, so
-- that shape cannot represent routine microbiology. It also makes an
-- antibiogram impossible, discards co-resistance (resistance to one drug is
-- strongly predictive of resistance to others), and cannot express MDR/XDR,
-- which is counted in resistant drug CLASSES per isolate.

CREATE TABLE IF NOT EXISTS raw.lab_isolates (
    isolate_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Nullable by design: a laboratory receives a specimen and reports on it
    -- whether or not a clinician's report exists yet. Requiring the report
    -- first is why labs currently cannot submit independently.
    report_id UUID REFERENCES raw.patient_reports(report_id),
    patient_id UUID REFERENCES master.patients(patient_id),
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),

    -- Who in the laboratory is accountable for this result.
    lab_user_id UUID REFERENCES master.doctors(doctor_id),

    accession_no VARCHAR,
    collection_date DATE,
    test_date DATE,

    specimen_type VARCHAR,
    specimen_type_other VARCHAR,
    culture_result VARCHAR,
    culture_result_other VARCHAR,
    pathogen VARCHAR,
    pathogen_other VARCHAR,
    infection_origin VARCHAR,

    -- A pending culture is a reportable fact. Treating "no row" as pending
    -- makes turnaround time unmeasurable.
    status VARCHAR NOT NULL DEFAULT 'preliminary'
        CHECK (status IN ('pending', 'preliminary', 'final', 'amended', 'cancelled')),

    -- Amendments insert a new row rather than overwriting. An AST result a
    -- clinician already prescribed against is exactly what an audit has to be
    -- able to reconstruct.
    amended_from UUID REFERENCES raw.lab_isolates(isolate_id),

    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now(),
    updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.ast_results (
    ast_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    isolate_id UUID NOT NULL REFERENCES raw.lab_isolates(isolate_id) ON DELETE CASCADE,

    antibiotic VARCHAR NOT NULL,
    antibiotic_class VARCHAR,

    ast_result VARCHAR
        CHECK (ast_result IS NULL OR ast_result IN
               ('Resistant', 'Susceptible', 'Intermediate', 'Not tested')),

    -- SIR is an interpretation of a measurement. Keeping the measurement makes
    -- MIC creep detectable while the categorical call is still "Susceptible".
    mic_value NUMERIC,
    mic_operator VARCHAR
        CHECK (mic_operator IS NULL OR mic_operator IN ('<=', '>=', '<', '>', '=')),
    zone_diameter_mm INTEGER,
    method VARCHAR
        CHECK (method IS NULL OR method IN
               ('Disk diffusion', 'Broth microdilution', 'E-test', 'VITEK', 'Other')),
    breakpoint_standard VARCHAR DEFAULT 'CLSI',

    created_at TIMESTAMP NOT NULL DEFAULT now(),

    -- One result per drug per isolate; a repeat is an amendment, not a new row.
    UNIQUE (isolate_id, antibiotic)
);

-- Backfill: every existing lab_results row becomes one isolate carrying a
-- one-drug panel, so nothing already recorded is lost. raw.lab_results is left
-- in place and simply goes unread by new code; dropping it is a later,
-- separate migration once the new path is proven.
WITH migrated AS (
    INSERT INTO raw.lab_isolates (
        report_id, patient_id, facility_id, test_date,
        specimen_type, specimen_type_other,
        culture_result, culture_result_other,
        pathogen, pathogen_other, status, created_at
    )
    SELECT
        lr.report_id, pr.patient_id, lr.facility_id, lr.test_date,
        lr.specimen_type, lr.specimen_type_other,
        lr.culture_result, lr.culture_result_other,
        lr.pathogen, lr.pathogen_other,
        'final', lr.created_at
    FROM raw.lab_results lr
    JOIN raw.patient_reports pr ON pr.report_id = lr.report_id
    RETURNING isolate_id, report_id, created_at
)
INSERT INTO raw.ast_results (isolate_id, antibiotic, ast_result, created_at)
SELECT m.isolate_id, lr.antibiotic, lr.ast_result, lr.created_at
FROM migrated m
JOIN raw.lab_results lr
  ON lr.report_id = m.report_id
 AND lr.created_at = m.created_at
WHERE lr.antibiotic IS NOT NULL;
