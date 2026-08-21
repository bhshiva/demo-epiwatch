-- Analytics schema: aggregated surveillance tables, refreshed periodically
-- by scripts/generate_surveillance_tables.py (not computed per-request).
-- Pure SQL aggregation -- no ML here; see ML_PLAN.md (local, not committed)
-- for the risk-scoring layer this schema is designed to eventually feed.

CREATE SCHEMA IF NOT EXISTS analytics;

-- Case counts by day/diagnosis/facility. facility_id is nullable so a
-- statewide/all-facility rollup row (facility_id IS NULL) can share this
-- table rather than needing a parallel one.
CREATE TABLE IF NOT EXISTS analytics.disease_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_date DATE NOT NULL,
    diagnosis VARCHAR NOT NULL,
    facility_id UUID REFERENCES master.facilities(facility_id),
    case_count INTEGER NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- One row per (date, diagnosis, facility) including the all-facility rollup;
-- a plain UNIQUE constraint treats every NULL as distinct, which would let
-- the ETL insert duplicate rollup rows on every run, so the facility_id
-- coalesce is baked into two partial unique indexes instead.
CREATE UNIQUE INDEX IF NOT EXISTS ux_disease_daily_facility
    ON analytics.disease_daily (report_date, diagnosis, facility_id)
    WHERE facility_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS ux_disease_daily_rollup
    ON analytics.disease_daily (report_date, diagnosis)
    WHERE facility_id IS NULL;

CREATE INDEX IF NOT EXISTS ix_disease_daily_date ON analytics.disease_daily(report_date);
CREATE INDEX IF NOT EXISTS ix_disease_daily_facility ON analytics.disease_daily(facility_id);

-- Rolling-window case counts per facility/diagnosis (e.g. trailing 7 days),
-- refreshed each ETL run rather than computed live -- this is what the
-- Health Authority dashboard reads for "cases this week" style tiles.
CREATE TABLE IF NOT EXISTS analytics.disease_facility (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES master.facilities(facility_id),
    diagnosis VARCHAR NOT NULL,
    window_start DATE NOT NULL,
    window_end DATE NOT NULL,
    case_count INTEGER NOT NULL,
    generated_at TIMESTAMP NOT NULL DEFAULT now(),
    UNIQUE (facility_id, diagnosis, window_start, window_end)
);

CREATE INDEX IF NOT EXISTS ix_disease_facility_facility
    ON analytics.disease_facility(facility_id);
CREATE INDEX IF NOT EXISTS ix_disease_facility_window
    ON analytics.disease_facility(window_start, window_end);

-- Resistance/MDR rates per facility/pathogen/antibiotic over a rolling
-- window. metric_name distinguishes what "value" means (e.g.
-- 'resistance_rate', 'mdr_rate') so this one table can carry several metric
-- kinds without a schema change each time a new one is added.
CREATE TABLE IF NOT EXISTS analytics.surveillance_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name VARCHAR NOT NULL,
    facility_id UUID REFERENCES master.facilities(facility_id),
    pathogen VARCHAR,
    antibiotic VARCHAR,
    window_start DATE NOT NULL,
    window_end DATE NOT NULL,
    value NUMERIC NOT NULL,
    sample_size INTEGER NOT NULL DEFAULT 0,
    generated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Same NULL-coalescing problem as disease_daily: facility_id/pathogen/
-- antibiotic can each legitimately be NULL (a statewide metric, a
-- pathogen-only metric with no single antibiotic), so the natural key is
-- expressed as one non-partial index over COALESCE'd sentinel expressions
-- rather than a plain UNIQUE constraint that would treat every NULL
-- combination as distinct.
CREATE UNIQUE INDEX IF NOT EXISTS ux_surveillance_metrics_key
    ON analytics.surveillance_metrics (
        metric_name,
        COALESCE(facility_id::text, ''),
        COALESCE(pathogen, ''),
        COALESCE(antibiotic, ''),
        window_start,
        window_end
    );

CREATE INDEX IF NOT EXISTS ix_surveillance_metrics_facility
    ON analytics.surveillance_metrics(facility_id);
CREATE INDEX IF NOT EXISTS ix_surveillance_metrics_name
    ON analytics.surveillance_metrics(metric_name);
