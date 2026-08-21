"""Surveillance aggregation ETL (scripts/generate_surveillance_tables.py)."""

import os
import uuid
from datetime import date

import psycopg
import pytest
from dotenv import load_dotenv
from sqlalchemy import text

from app.db import SessionLocal
from scripts.generate_surveillance_tables import run

load_dotenv()


@pytest.fixture
def db():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.rollback()
        session.close()


@pytest.fixture
def facility_id(db):
    return db.execute(text("SELECT facility_id FROM master.facilities LIMIT 1")).scalar()


def test_run_is_idempotent(db, facility_id):
    """Running twice for the same day must not error or double-count rows."""
    today = date.today()

    run(reference_date=today)
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM analytics.disease_daily")
        first_count = cur.fetchone()[0]

    run(reference_date=today)
    with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM analytics.disease_daily")
        second_count = cur.fetchone()[0]

    assert first_count == second_count


def test_case_counts_match_raw_reports(db, facility_id):
    """The aggregate for today must equal a direct count over raw.patient_reports."""
    today = date.today()
    diagnosis = f"Test-Diagnosis-{uuid.uuid4().hex[:8]}"

    # A minimal patient/report so there is a real row to aggregate.
    patient_id = db.execute(
        text(
            "INSERT INTO master.patients (age_group, sex, district) "
            "VALUES ('18-40', 'F', 'Pune') RETURNING patient_id"
        )
    ).scalar()
    doctor_id = db.execute(text("SELECT doctor_id FROM master.doctors LIMIT 1")).scalar()
    db.execute(
        text(
            "INSERT INTO raw.patient_reports "
            "(patient_id, doctor_id, facility_id, report_date, diagnosis) "
            "VALUES (:patient_id, :doctor_id, :facility_id, :report_date, :diagnosis)"
        ),
        {
            "patient_id": patient_id,
            "doctor_id": doctor_id,
            "facility_id": facility_id,
            "report_date": today,
            "diagnosis": diagnosis,
        },
    )
    db.commit()

    run(reference_date=today)

    with psycopg.connect(os.environ["DATABASE_URL"]) as conn, conn.cursor() as cur:
        cur.execute(
            "SELECT case_count FROM analytics.disease_daily "
            "WHERE report_date = %s AND diagnosis = %s AND facility_id = %s",
            (today, diagnosis, str(facility_id)),
        )
        row = cur.fetchone()

    assert row is not None
    assert row[0] == 1
