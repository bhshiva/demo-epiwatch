"""Write a non-PII Neo4j profile used to gate graph-model training."""

from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from app.services.graph_db import close_driver, get_driver
from neo4j.exceptions import ServiceUnavailable

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "cleaned" / "neo4j_graph_profile.json"

QUERIES = {
    "node_counts": """
        MATCH (node) UNWIND labels(node) AS label
        RETURN label, count(*) AS count ORDER BY label
    """,
    "relationship_counts": """
        MATCH ()-[relationship]->()
        RETURN type(relationship) AS type, count(*) AS count ORDER BY type
    """,
    "ast_result_counts": """
        MATCH ()-[test:TESTED_AGAINST]->()
        RETURN coalesce(test.result, 'MISSING') AS result, count(*) AS count ORDER BY result
    """,
    "isolate_link_completeness": """
        MATCH (isolate:Isolate)
        OPTIONAL MATCH (isolate)-[:OF_PATHOGEN]->(pathogen:Pathogen)
        OPTIONAL MATCH (isolate)-[:COLLECTED_AT]->(facility:Facility)
        RETURN count(DISTINCT isolate) AS isolates,
               count(DISTINCT CASE WHEN isolate.collection_date IS NOT NULL THEN isolate END) AS with_collection_date,
               count(DISTINCT CASE WHEN pathogen IS NOT NULL THEN isolate END) AS with_pathogen,
               count(DISTINCT CASE WHEN facility IS NOT NULL THEN isolate END) AS with_facility
    """,
    "strain_facility_connectivity": """
        MATCH (strain:Strain)
        OPTIONAL MATCH (strain)<-[:BELONGS_TO_STRAIN]-(:Isolate)-[:COLLECTED_AT]->(facility:Facility)
        WITH strain, count(DISTINCT facility) AS facility_count
        RETURN count(strain) AS strains,
               count(CASE WHEN facility_count >= 1 THEN strain END) AS strains_with_facility,
               count(CASE WHEN facility_count >= 2 THEN strain END) AS cross_facility_strains,
               coalesce(max(facility_count), 0) AS maximum_facilities_per_strain
    """,
}


def _records(session, query: str) -> list[dict[str, object]]:
    return [dict(record) for record in session.run(query)]


def profile() -> dict[str, object]:
    """Profile only structural data; never query patient identities or report text."""
    driver = get_driver()
    try:
        driver.verify_connectivity()
        with driver.session() as session:
            result = {name: _records(session, query) for name, query in QUERIES.items()}
    finally:
        close_driver()
    result["profiled_at"] = datetime.now(timezone.utc).isoformat()
    result["purpose"] = "graph-model feasibility gate; structural aggregates only"
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    try:
        print(json.dumps(profile(), indent=2))
    except ServiceUnavailable as error:
        print(
            "Neo4j is unavailable. Start the configured Neo4j service, then rerun "
            "python -m scripts.profile_neo4j_graph.",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
