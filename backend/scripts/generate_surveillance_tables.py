"""
Surveillance ETL: raw clinical/lab data -> aggregated analytics tables.

Pure SQL/Python aggregation, no ML (see ML_PLAN.md, kept local/uncommitted,
for the risk-scoring layer this feeds later). Every write is an idempotent
upsert (ON CONFLICT DO UPDATE / delete-then-insert against a stable key), so
re-running this script -- on a schedule or by hand -- is always safe, the
same expectation the migration runner and scripts/seed.py already hold.

Usage:
    python -m scripts.generate_surveillance_tables            # run once
    python -m scripts.generate_surveillance_tables --daemon   # loop, sleeping
                                                                # 5h between runs

There is no Celery/APScheduler/cron in this project yet (confirmed absent
project-wide). --daemon is a minimal in-process loop rather than pulling in
a task-queue dependency for one periodic job; swap it for a real scheduler
(OS-level Task Scheduler/cron, or a task queue) if more jobs like this show
up later.
"""

import argparse
import time
from datetime import date, timedelta

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import text
from sqlalchemy.orm import selectinload

from app.db import SessionLocal
from app.models import LabIsolate
from app.services.antibiotics import antibiotic_class, is_mdr

ROLLING_WINDOW_DAYS = 7
RUN_INTERVAL_SECONDS = 5 * 60 * 60  # "every 5 hours", per the architecture diagram


def _daily_case_counts(db, window_start: date, window_end: date) -> None:
    """One row per (report_date, diagnosis, facility_id), plus a statewide rollup."""
    db.execute(
        text(
            """
            INSERT INTO analytics.disease_daily (report_date, diagnosis, facility_id, case_count)
            SELECT report_date, diagnosis, facility_id, COUNT(*)
            FROM raw.patient_reports
            WHERE report_date BETWEEN :start AND :end
              AND diagnosis IS NOT NULL
            GROUP BY report_date, diagnosis, facility_id
            ON CONFLICT (report_date, diagnosis, facility_id)
                WHERE facility_id IS NOT NULL
                DO UPDATE SET case_count = EXCLUDED.case_count, generated_at = now()
            """
        ),
        {"start": window_start, "end": window_end},
    )
    db.execute(
        text(
            """
            INSERT INTO analytics.disease_daily (report_date, diagnosis, facility_id, case_count)
            SELECT report_date, diagnosis, NULL, COUNT(*)
            FROM raw.patient_reports
            WHERE report_date BETWEEN :start AND :end
              AND diagnosis IS NOT NULL
            GROUP BY report_date, diagnosis
            ON CONFLICT (report_date, diagnosis)
                WHERE facility_id IS NULL
                DO UPDATE SET case_count = EXCLUDED.case_count, generated_at = now()
            """
        ),
        {"start": window_start, "end": window_end},
    )


def _rolling_facility_counts(db, window_start: date, window_end: date) -> None:
    """Trailing-window case counts per (facility_id, diagnosis) -- what dashboard tiles read."""
    db.execute(
        text(
            """
            INSERT INTO analytics.disease_facility
                (facility_id, diagnosis, window_start, window_end, case_count)
            SELECT facility_id, diagnosis, :start, :end, COUNT(*)
            FROM raw.patient_reports
            WHERE report_date BETWEEN :start AND :end
              AND diagnosis IS NOT NULL
            GROUP BY facility_id, diagnosis
            ON CONFLICT (facility_id, diagnosis, window_start, window_end)
                DO UPDATE SET case_count = EXCLUDED.case_count, generated_at = now()
            """
        ),
        {"start": window_start, "end": window_end},
    )


def _upsert_metric(db, *, metric_name, facility_id, pathogen, antibiotic, window_start, window_end, value, sample_size):
    db.execute(
        text(
            """
            INSERT INTO analytics.surveillance_metrics
                (metric_name, facility_id, pathogen, antibiotic, window_start, window_end, value, sample_size)
            VALUES
                (:metric_name, :facility_id, :pathogen, :antibiotic, :window_start, :window_end, :value, :sample_size)
            ON CONFLICT (
                metric_name,
                COALESCE(facility_id::text, ''),
                COALESCE(pathogen, ''),
                COALESCE(antibiotic, ''),
                window_start,
                window_end
            )
            DO UPDATE SET value = EXCLUDED.value, sample_size = EXCLUDED.sample_size, generated_at = now()
            """
        ),
        {
            "metric_name": metric_name,
            "facility_id": facility_id,
            "pathogen": pathogen,
            "antibiotic": antibiotic,
            "window_start": window_start,
            "window_end": window_end,
            "value": value,
            "sample_size": sample_size,
        },
    )


def _resistance_and_mdr_metrics(db, window_start: date, window_end: date) -> None:
    """
    Resistance rate and MDR rate, per facility and statewide.

    Mirrors lab.py's live per-isolate definitions exactly (same "Not tested"
    exclusion, same is_mdr() class-counting helper) so a batch aggregate and
    the live per-isolate summary can never disagree on what these numbers
    mean -- the reason MDR_CLASS_THRESHOLD/is_mdr() were factored out of
    lab.py into services/antibiotics.py in the first place.
    """
    isolates = (
        db.query(LabIsolate)
        .options(selectinload(LabIsolate.ast_results))
        .filter(LabIsolate.test_date.between(window_start, window_end))
        .all()
    )

    per_facility: dict = {}
    for isolate in isolates:
        scored = [a for a in isolate.ast_results if a.ast_result in ("Resistant", "Susceptible", "Intermediate")]
        resistant = [a for a in scored if a.ast_result == "Resistant"]
        resistant_classes = {antibiotic_class(a.antibiotic) or a.antibiotic for a in resistant}

        bucket = per_facility.setdefault(
            isolate.facility_id, {"tested": 0, "resistant": 0, "isolates": 0, "mdr": 0}
        )
        bucket["tested"] += len(scored)
        bucket["resistant"] += len(resistant)
        bucket["isolates"] += 1
        if is_mdr(resistant_classes):
            bucket["mdr"] += 1

    statewide = {"tested": 0, "resistant": 0, "isolates": 0, "mdr": 0}
    for facility_id, bucket in per_facility.items():
        for key in statewide:
            statewide[key] += bucket[key]

        if bucket["tested"] > 0:
            _upsert_metric(
                db,
                metric_name="resistance_rate",
                facility_id=facility_id,
                pathogen=None,
                antibiotic=None,
                window_start=window_start,
                window_end=window_end,
                value=bucket["resistant"] / bucket["tested"],
                sample_size=bucket["tested"],
            )
        if bucket["isolates"] > 0:
            _upsert_metric(
                db,
                metric_name="mdr_rate",
                facility_id=facility_id,
                pathogen=None,
                antibiotic=None,
                window_start=window_start,
                window_end=window_end,
                value=bucket["mdr"] / bucket["isolates"],
                sample_size=bucket["isolates"],
            )

    if statewide["tested"] > 0:
        _upsert_metric(
            db,
            metric_name="resistance_rate",
            facility_id=None,
            pathogen=None,
            antibiotic=None,
            window_start=window_start,
            window_end=window_end,
            value=statewide["resistant"] / statewide["tested"],
            sample_size=statewide["tested"],
        )
    if statewide["isolates"] > 0:
        _upsert_metric(
            db,
            metric_name="mdr_rate",
            facility_id=None,
            pathogen=None,
            antibiotic=None,
            window_start=window_start,
            window_end=window_end,
            value=statewide["mdr"] / statewide["isolates"],
            sample_size=statewide["isolates"],
        )


def run(reference_date: date | None = None) -> None:
    """One aggregation pass over the trailing ROLLING_WINDOW_DAYS window."""
    today = reference_date or date.today()
    window_start = today - timedelta(days=ROLLING_WINDOW_DAYS - 1)

    db = SessionLocal()
    try:
        _daily_case_counts(db, window_start, today)
        _rolling_facility_counts(db, window_start, today)
        _resistance_and_mdr_metrics(db, window_start, today)
        db.commit()
        print(f"Surveillance tables refreshed for {window_start} .. {today}")
    finally:
        db.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--daemon", action="store_true", help=f"loop, sleeping {RUN_INTERVAL_SECONDS}s between runs"
    )
    args = parser.parse_args()

    run()
    while args.daemon:
        time.sleep(RUN_INTERVAL_SECONDS)
        run()
