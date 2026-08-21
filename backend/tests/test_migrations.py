import os
import psycopg
import pytest
from dotenv import load_dotenv

load_dotenv()

@pytest.fixture
def conn():
    with psycopg.connect(os.environ["DATABASE_URL"]) as c:
        yield c

def test_master_tables_exist(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'master'"
        )
        tables = {row[0] for row in cur.fetchall()}
    assert tables == {"doctors", "facilities", "patients", "patient_identities"}

def test_raw_tables_exist(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'raw'"
        )
        tables = {row[0] for row in cur.fetchall()}
    assert tables == {
        "patient_reports",
        "prescriptions",
        "lab_results",
        # Migration 007: one organism, many antibiotic results.
        "lab_isolates",
        "ast_results",
        # Migration 009: manual strain-cluster grouping for AMR surveillance.
        "strain_clusters",
        "isolate_strain_links",
    }


def test_lab_results_has_culture_result(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = 'raw' AND table_name = 'lab_results'"
        )
        columns = {row[0] for row in cur.fetchall()}
    assert "culture_result" in columns


def test_ast_check_allows_not_tested(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint "
            "WHERE conname = 'lab_results_ast_result_check'"
        )
        definition = cur.fetchone()[0]
    assert "Not tested" in definition


def test_fuzzy_matching_extensions_are_installed(conn):
    """Name matching needs trigram similarity and phonetic comparison."""
    with conn.cursor() as cur:
        cur.execute("SELECT extname FROM pg_extension")
        installed = {row[0] for row in cur.fetchall()}
    assert {"pg_trgm", "fuzzystrmatch"} <= installed


def test_patient_identities_has_abha(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = 'master' AND table_name = 'patient_identities'"
        )
        columns = {row[0] for row in cur.fetchall()}
    assert "abha_id" in columns


def test_abha_is_unique_within_a_facility(conn):
    with conn.cursor() as cur:
        cur.execute(
            "SELECT indexdef FROM pg_indexes "
            "WHERE schemaname = 'master' AND indexname = 'ux_patient_identities_facility_abha'"
        )
        row = cur.fetchone()
    assert row is not None
    assert "UNIQUE" in row[0]
