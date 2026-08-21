"""
Syncs the strain/isolate/antibiotic/facility/pathogen relationship graph
from Postgres into Neo4j.

Postgres stays the system of record; this is a periodically-refreshed
derived view, the same relationship analytics.* tables have to raw.*/
master.* (see generate_surveillance_tables.py). Every write is an
idempotent MERGE, so re-running this -- on a schedule or by hand -- is
always safe.

Graph shape:
    (Isolate)-[:OF_PATHOGEN]->(Pathogen)
    (Isolate)-[:BELONGS_TO_STRAIN]->(Strain)
    (Isolate)-[:COLLECTED_AT]->(Facility)
    (Isolate)-[:TESTED_AGAINST {result, mic_value, mic_operator,
                                 zone_diameter_mm, method}]->(Antibiotic)
    (Strain)-[:OF_PATHOGEN]->(Pathogen)
    (Strain)-[:FIRST_SEEN_AT]->(Facility)

Browsable via Neo4j Browser at http://localhost:7474 once populated -- e.g.
MATCH (s:Strain)<-[:BELONGS_TO_STRAIN]-(i:Isolate)-[:TESTED_AGAINST]->(a:Antibiotic)
RETURN s, i, a LIMIT 100

Usage:
    python -m scripts.sync_neo4j_graph
    python -m scripts.sync_neo4j_graph --daemon   # loop, sleeping 5h between runs
"""

import argparse
import time

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import text

from app.db import SessionLocal
from app.services.antibiotics import antibiotic_class, is_mdr
from app.services.graph_db import get_driver

RUN_INTERVAL_SECONDS = 5 * 60 * 60  # matches generate_surveillance_tables.py


def _fetch_isolates(db):
    rows = db.execute(
        text(
            """
            SELECT
                li.isolate_id, li.accession_no, li.collection_date, li.test_date,
                li.status, li.specimen_type, li.culture_result, li.facility_id,
                COALESCE(NULLIF(li.pathogen, 'Other'), li.pathogen_other) AS pathogen
            FROM raw.lab_isolates li
            WHERE li.status != 'amended'
            """
        )
    ).mappings().all()
    return [dict(r) for r in rows]


def _fetch_ast_results(db):
    rows = db.execute(
        text(
            """
            SELECT ar.isolate_id, ar.antibiotic, ar.antibiotic_class, ar.ast_result,
                   ar.mic_value, ar.mic_operator, ar.zone_diameter_mm, ar.method
            FROM raw.ast_results ar
            JOIN raw.lab_isolates li ON li.isolate_id = ar.isolate_id
            WHERE li.status != 'amended'
            """
        )
    ).mappings().all()
    return [dict(r) for r in rows]


def _fetch_strain_links(db):
    rows = db.execute(
        text(
            """
            SELECT sc.strain_id, sc.designation, sc.clonal_group, sc.first_detected_at,
                   sc.facility_id AS strain_facility_id, sc.pathogen,
                   isl.isolate_id
            FROM raw.strain_clusters sc
            JOIN raw.isolate_strain_links isl ON isl.strain_id = sc.strain_id
            """
        )
    ).mappings().all()
    return [dict(r) for r in rows]


def _fetch_facilities(db):
    rows = db.execute(
        text("SELECT facility_id, name, district, state, latitude, longitude FROM master.facilities")
    ).mappings().all()
    return [dict(r) for r in rows]


def _mdr_by_isolate(ast_rows: list[dict]) -> dict:
    """Same class-counting definition lab.py/generate_surveillance_tables.py use."""
    resistant_classes: dict = {}
    for row in ast_rows:
        if row["ast_result"] != "Resistant":
            continue
        cls = row["antibiotic_class"] or antibiotic_class(row["antibiotic"]) or row["antibiotic"]
        resistant_classes.setdefault(row["isolate_id"], set()).add(cls)
    return {isolate_id: is_mdr(classes) for isolate_id, classes in resistant_classes.items()}


def sync() -> dict:
    db = SessionLocal()
    try:
        isolates = _fetch_isolates(db)
        ast_rows = _fetch_ast_results(db)
        strain_links = _fetch_strain_links(db)
        facilities = _fetch_facilities(db)
    finally:
        db.close()

    for row in ast_rows:
        row["isolate_id"] = str(row["isolate_id"])
        row["antibiotic_class"] = row["antibiotic_class"] or antibiotic_class(row["antibiotic"])
        row["mic_value"] = float(row["mic_value"]) if row["mic_value"] is not None else None

    # Computed after ast_rows' isolate_id has already been stringified, so
    # this dict's keys match what isolates' lookup below uses -- previously
    # this ran on the raw UUID objects, before the stringify loop, so the
    # later string-keyed .get() never matched and every isolate silently
    # got is_mdr=False regardless of its actual resistance profile.
    mdr_by_isolate = _mdr_by_isolate(ast_rows)
    for isolate in isolates:
        isolate["isolate_id"] = str(isolate["isolate_id"])
        isolate["facility_id"] = str(isolate["facility_id"])
        isolate["collection_date"] = str(isolate["collection_date"]) if isolate["collection_date"] else None
        isolate["test_date"] = str(isolate["test_date"]) if isolate["test_date"] else None
        isolate["is_mdr"] = mdr_by_isolate.get(isolate["isolate_id"], False)

    for row in strain_links:
        row["strain_id"] = str(row["strain_id"])
        row["isolate_id"] = str(row["isolate_id"])
        row["strain_facility_id"] = str(row["strain_facility_id"]) if row["strain_facility_id"] else None
        row["first_detected_at"] = str(row["first_detected_at"]) if row["first_detected_at"] else None

    for row in facilities:
        row["facility_id"] = str(row["facility_id"])
        row["latitude"] = float(row["latitude"]) if row["latitude"] is not None else None
        row["longitude"] = float(row["longitude"]) if row["longitude"] is not None else None

    driver = get_driver()
    with driver.session() as session:
        session.execute_write(_ensure_constraints)
        session.execute_write(_write_facilities, facilities)
        session.execute_write(_write_isolates, isolates)
        session.execute_write(_write_ast_results, ast_rows)
        session.execute_write(_write_strain_links, strain_links)

    return {
        "facilities": len(facilities),
        "isolates": len(isolates),
        "ast_results": len(ast_rows),
        "strain_links": len(strain_links),
    }


def _ensure_constraints(tx):
    """Uniqueness constraints double as the indexes MERGE needs to not be O(n) per call."""
    for label, prop in [
        ("Facility", "facility_id"),
        ("Isolate", "isolate_id"),
        ("Strain", "strain_id"),
        ("Antibiotic", "name"),
        ("Pathogen", "name"),
    ]:
        tx.run(f"CREATE CONSTRAINT IF NOT EXISTS FOR (n:{label}) REQUIRE n.{prop} IS UNIQUE")


def _write_facilities(tx, rows):
    tx.run(
        """
        UNWIND $rows AS row
        MERGE (f:Facility {facility_id: row.facility_id})
        SET f.name = row.name, f.district = row.district, f.state = row.state,
            f.latitude = row.latitude, f.longitude = row.longitude
        """,
        rows=rows,
    )


def _write_isolates(tx, rows):
    tx.run(
        """
        UNWIND $rows AS row
        MERGE (i:Isolate {isolate_id: row.isolate_id})
        SET i.accession_no = row.accession_no, i.collection_date = row.collection_date,
            i.test_date = row.test_date, i.status = row.status,
            i.specimen_type = row.specimen_type, i.culture_result = row.culture_result,
            i.is_mdr = row.is_mdr
        MERGE (f:Facility {facility_id: row.facility_id})
        MERGE (i)-[:COLLECTED_AT]->(f)
        FOREACH (_ IN CASE WHEN row.pathogen IS NOT NULL THEN [1] ELSE [] END |
            MERGE (p:Pathogen {name: row.pathogen})
            MERGE (i)-[:OF_PATHOGEN]->(p)
        )
        """,
        rows=rows,
    )


def _write_ast_results(tx, rows):
    tx.run(
        """
        UNWIND $rows AS row
        MATCH (i:Isolate {isolate_id: row.isolate_id})
        MERGE (a:Antibiotic {name: row.antibiotic})
        SET a.class = row.antibiotic_class
        MERGE (i)-[t:TESTED_AGAINST]->(a)
        SET t.result = row.ast_result, t.mic_value = row.mic_value,
            t.mic_operator = row.mic_operator, t.zone_diameter_mm = row.zone_diameter_mm,
            t.method = row.method
        """,
        rows=rows,
    )


def _write_strain_links(tx, rows):
    tx.run(
        """
        UNWIND $rows AS row
        MERGE (s:Strain {strain_id: row.strain_id})
        SET s.designation = row.designation, s.clonal_group = row.clonal_group,
            s.first_detected_at = row.first_detected_at
        FOREACH (_ IN CASE WHEN row.pathogen IS NOT NULL THEN [1] ELSE [] END |
            MERGE (p:Pathogen {name: row.pathogen})
            MERGE (s)-[:OF_PATHOGEN]->(p)
        )
        FOREACH (_ IN CASE WHEN row.strain_facility_id IS NOT NULL THEN [1] ELSE [] END |
            MERGE (f:Facility {facility_id: row.strain_facility_id})
            MERGE (s)-[:FIRST_SEEN_AT]->(f)
        )
        WITH s, row
        MATCH (i:Isolate {isolate_id: row.isolate_id})
        MERGE (i)-[:BELONGS_TO_STRAIN]->(s)
        """,
        rows=rows,
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--daemon", action="store_true", help=f"loop, sleeping {RUN_INTERVAL_SECONDS}s between runs"
    )
    args = parser.parse_args()

    counts = sync()
    print(f"Synced to Neo4j: {counts}")
    while args.daemon:
        time.sleep(RUN_INTERVAL_SECONDS)
        counts = sync()
        print(f"Synced to Neo4j: {counts}")
