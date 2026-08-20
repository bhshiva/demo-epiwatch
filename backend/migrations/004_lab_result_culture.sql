-- Culture result was collected at the point of care but had nowhere to land,
-- so "No growth" and "Contaminated" -- clinically meaningful negatives -- were
-- being discarded on submit. A negative culture is evidence, not missing data.
ALTER TABLE raw.lab_results
    ADD COLUMN IF NOT EXISTS culture_result VARCHAR;

-- The original CHECK admitted only the three GLASS interpretive categories.
-- "Not tested" must be representable: an identified organism with no
-- susceptibility panel run is a different fact from a missing record.
-- Constraint name verified against pg_constraint before writing this.
ALTER TABLE raw.lab_results
    DROP CONSTRAINT IF EXISTS lab_results_ast_result_check;

ALTER TABLE raw.lab_results
    ADD CONSTRAINT lab_results_ast_result_check
    CHECK (ast_result IS NULL OR ast_result IN
        ('Resistant', 'Susceptible', 'Intermediate', 'Not tested'));
