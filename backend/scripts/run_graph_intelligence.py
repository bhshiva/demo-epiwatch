"""Run safe, gated Neo4j graph intelligence for facility-risk features."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from neo4j.exceptions import ClientError

from app.services.graph_db import close_driver, get_driver

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "data" / "cleaned" / "graph_intelligence_features.json"
GRAPH_NAME = "epiwatch_facility_strain"
MIN_CROSS_FACILITY_STRAINS = 3

READINESS_QUERY = """
MATCH (strain:Strain)
OPTIONAL MATCH (strain)<-[:BELONGS_TO_STRAIN]-(:Isolate)-[:COLLECTED_AT]->(facility:Facility)
WITH strain, count(DISTINCT facility) AS facility_count
RETURN count(strain) AS strains,
       count(CASE WHEN facility_count >= 2 THEN strain END) AS cross_facility_strains
"""

PROJECT_GRAPH = """
CALL gds.graph.project.cypher(
  $graph_name,
  'MATCH (node) WHERE node:Facility OR node:Isolate OR node:Strain RETURN id(node) AS id',
  'MATCH (source)-[:COLLECTED_AT|BELONGS_TO_STRAIN]-(target)
   RETURN id(source) AS source, id(target) AS target'
)
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount
"""

COMMUNITIES = """
CALL gds.louvain.stream($graph_name, {relationshipWeightProperty: null})
YIELD nodeId, communityId
WITH gds.util.asNode(nodeId) AS node, communityId
WHERE node:Facility
WITH communityId, collect(node.facility_id) AS facilities
UNWIND facilities AS facility_id
RETURN facility_id, communityId, size(facilities) AS community_facility_count
ORDER BY facility_id
"""


def _gds_version(session) -> str | None:
    try:
        record = session.run("CALL gds.version()").single()
        return record[0] if record else None
    except ClientError:
        return None


def run() -> dict[str, object]:
    """Create facility-level graph features only when the graph is trainable."""
    driver = get_driver()
    try:
        try:
            driver.verify_connectivity()
            has_neo4j = True
            connectivity_error = None
        except Exception as e:
            has_neo4j = False
            connectivity_error = str(e)

        result: dict[str, object] = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "model": "neo4j_louvain_facility_strain",
            "features": [],
        }

        if not has_neo4j:
            result["status"] = "blocked_missing_neo4j"
            result["reason"] = f"Neo4j is not running or unreachable: {connectivity_error}"
        else:
            with driver.session() as session:
                gds_version = _gds_version(session)
                readiness = dict(session.run(READINESS_QUERY).single())
                result.update({
                    "gds_version": gds_version,
                    "readiness": readiness,
                    "minimum_cross_facility_strains": MIN_CROSS_FACILITY_STRAINS,
                })
                if not gds_version:
                    result["status"] = "blocked_missing_gds"
                    result["reason"] = "Install Neo4j Graph Data Science before graph-model execution."
                elif readiness["cross_facility_strains"] < MIN_CROSS_FACILITY_STRAINS:
                    result["status"] = "blocked_insufficient_connectivity"
                    result["reason"] = "Need cross-facility strain links before community detection is meaningful."
                else:
                    session.run("CALL gds.graph.drop($graph_name, false)", graph_name=GRAPH_NAME).consume()
                    try:
                        projection = dict(session.run(PROJECT_GRAPH, graph_name=GRAPH_NAME).single())
                        result["features"] = [dict(row) for row in session.run(COMMUNITIES, graph_name=GRAPH_NAME)]
                        result["projection"] = projection
                        result["status"] = "ready"
                    finally:
                        session.run("CALL gds.graph.drop($graph_name, false)", graph_name=GRAPH_NAME).consume()
    finally:
        close_driver()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    print(json.dumps(run(), indent=2))
