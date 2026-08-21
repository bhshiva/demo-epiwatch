"""
Neo4j driver access for the AMR/strain relationship graph.

Mirrors app/db.py's pattern (module-level singleton, lazily created) but for
the graph store rather than Postgres. Postgres remains the system of record
for everything -- this graph is a derived, periodically-refreshed view built
by scripts/sync_neo4j_graph.py, the same relationship the analytics.* tables
have to raw.*/master.* (see generate_surveillance_tables.py).
"""

import os

from dotenv import load_dotenv
from neo4j import Driver, GraphDatabase

load_dotenv()

_driver: Driver | None = None


def get_driver() -> Driver:
    global _driver
    if _driver is None:
        uri = os.environ.get("NEO4J_URI", "bolt://localhost:7687")
        user = os.environ.get("NEO4J_USER", "neo4j")
        password = os.environ["NEO4J_PASSWORD"]
        _driver = GraphDatabase.driver(uri, auth=(user, password))
    return _driver


def close_driver() -> None:
    global _driver
    if _driver is not None:
        _driver.close()
        _driver = None
