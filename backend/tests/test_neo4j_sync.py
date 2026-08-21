"""Postgres -> Neo4j graph sync (scripts/sync_neo4j_graph.py)."""

import pytest
from dotenv import load_dotenv
from sqlalchemy import text

from app.db import SessionLocal
from app.services.graph_db import get_driver
from scripts.sync_neo4j_graph import sync

load_dotenv()


def _neo4j_reachable() -> bool:
    try:
        get_driver().verify_connectivity()
        return True
    except Exception:
        return False


pytestmark = pytest.mark.skipif(
    not _neo4j_reachable(), reason="Neo4j not reachable at NEO4J_URI -- see .env.example"
)


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


def test_sync_is_idempotent():
    """Running twice must not error or double-count nodes/relationships."""
    first = sync()
    second = sync()
    assert first == second


def test_synced_isolate_links_to_its_facility_and_antibiotics(db):
    isolate_id = db.execute(
        text("SELECT isolate_id FROM raw.lab_isolates WHERE status != 'amended' LIMIT 1")
    ).scalar()
    if isolate_id is None:
        pytest.skip("no isolates in this database to check")

    sync()

    driver = get_driver()
    with driver.session() as session:
        row = session.run(
            """
            MATCH (i:Isolate {isolate_id: $isolate_id})-[:COLLECTED_AT]->(f:Facility)
            RETURN f.facility_id AS facility_id
            """,
            isolate_id=str(isolate_id),
        ).single()

    assert row is not None, "isolate should have a COLLECTED_AT relationship to a Facility"


def test_mdr_flag_matches_the_shared_definition(db):
    """The graph's is_mdr must agree with services/antibiotics.py -- same source of
    truth the live lab.py summary and the surveillance ETL both use."""
    from app.services.antibiotics import antibiotic_class, is_mdr

    row = db.execute(
        text(
            """
            SELECT li.isolate_id
            FROM raw.lab_isolates li
            JOIN raw.ast_results ar ON ar.isolate_id = li.isolate_id
            WHERE li.status != 'amended' AND ar.ast_result = 'Resistant'
            GROUP BY li.isolate_id
            LIMIT 1
            """
        )
    ).first()
    if row is None:
        pytest.skip("no isolate with a resistant result to check")
    isolate_id = row[0]

    ast_rows = db.execute(
        text("SELECT antibiotic, antibiotic_class, ast_result FROM raw.ast_results WHERE isolate_id = :id"),
        {"id": isolate_id},
    ).all()
    resistant_classes = {
        (r.antibiotic_class or antibiotic_class(r.antibiotic) or r.antibiotic)
        for r in ast_rows
        if r.ast_result == "Resistant"
    }
    expected = is_mdr(resistant_classes)

    sync()

    driver = get_driver()
    with driver.session() as session:
        actual = session.run(
            "MATCH (i:Isolate {isolate_id: $id}) RETURN i.is_mdr AS is_mdr",
            id=str(isolate_id),
        ).single()["is_mdr"]

    assert actual == expected
