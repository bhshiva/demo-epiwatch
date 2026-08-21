-- Strain clustering for AMR surveillance.
--
-- Grouping isolates by strain (a shared clone/lineage, e.g. an ST131 E. coli
-- cluster) is what turns a pile of individual resistant isolates into an
-- outbreak signal: the same strain appearing across facilities or spreading
-- within one is the thing worth alerting on, not any single resistant
-- result. Assignment here is manual/lab-entered (a microbiologist tags an
-- isolate with a strain designation once one is known, e.g. from sequencing
-- or epidemiological linkage) -- there is no automated clustering algorithm.
--
-- A link table rather than a single FK column on lab_isolates: an isolate's
-- strain assignment can be corrected (a bad WGS call, a mislabelled sample),
-- and the amendment philosophy already used for lab_isolates itself
-- (superseding rows, not overwriting) argues for keeping that history here
-- too rather than silently overwriting a link.

CREATE TABLE IF NOT EXISTS raw.strain_clusters (
    strain_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    pathogen VARCHAR NOT NULL,
    designation VARCHAR,
    clonal_group VARCHAR,

    -- Where this cluster was first flagged. Nullable: a cluster can be
    -- recognised as spanning facilities from the start (e.g. a state-level
    -- health authority naming a cluster from aggregate data), not just
    -- promoted from a single facility's first isolate.
    facility_id UUID REFERENCES master.facilities(facility_id),

    first_detected_at TIMESTAMP NOT NULL DEFAULT now(),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS raw.isolate_strain_links (
    link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    isolate_id UUID NOT NULL REFERENCES raw.lab_isolates(isolate_id) ON DELETE CASCADE,
    strain_id UUID NOT NULL REFERENCES raw.strain_clusters(strain_id) ON DELETE CASCADE,
    assigned_at TIMESTAMP NOT NULL DEFAULT now(),
    assigned_by UUID REFERENCES master.doctors(doctor_id),

    UNIQUE (isolate_id, strain_id)
);

CREATE INDEX IF NOT EXISTS ix_isolate_strain_links_strain
    ON raw.isolate_strain_links(strain_id);
CREATE INDEX IF NOT EXISTS ix_isolate_strain_links_isolate
    ON raw.isolate_strain_links(isolate_id);
CREATE INDEX IF NOT EXISTS ix_strain_clusters_pathogen
    ON raw.strain_clusters(pathogen);

-- raw.lab_isolates has had no index beyond its primary/foreign keys since
-- migration 007, despite the worklist, summary and (new) surveillance
-- queries filtering/sorting on exactly these columns. Cheap to add while
-- this table's neighbourhood is already open for the strain-link FK above.
CREATE INDEX IF NOT EXISTS ix_lab_isolates_facility_status
    ON raw.lab_isolates(facility_id, status);
CREATE INDEX IF NOT EXISTS ix_lab_isolates_test_date
    ON raw.lab_isolates(test_date);
