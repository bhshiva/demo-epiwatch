"""Compute EWMA and one-sided CUSUM signals from cleaned ARMD counts."""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
CLEANED_DIR = PROJECT_ROOT / "data" / "cleaned"
INPUT_NAME = "armd_resistance.csv"
SERIES_NAME = "armd_daily_series.csv"
SCORES_NAME = "armd_spc_scores.csv"
ALPHA = 0.2
BASELINE_DAYS = 28
CONTROL_LIMIT_SIGMA = 3.0
CUSUM_SLACK_SIGMA = 0.5
CUSUM_THRESHOLD_SIGMA = 5.0


def build_series() -> dict[tuple[str, date], int]:
    counts: dict[tuple[str, date], int] = defaultdict(int)
    with (CLEANED_DIR / INPUT_NAME).open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            counts[(row["organism"], date.fromisoformat(row["collection_date"]))] += 1
    return counts


def _std(values: list[float]) -> float:
    if len(values) < 2:
        return 1.0
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / (len(values) - 1)
    return max(math.sqrt(variance), 1.0)


def run() -> dict[str, int]:
    counts = build_series()
    by_organism: dict[str, list[date]] = defaultdict(list)
    for organism, row_date in counts:
        by_organism[organism].append(row_date)
    score_rows: list[dict[str, object]] = []
    series_rows: list[dict[str, object]] = []
    for organism, organism_dates in by_organism.items():
        start, end = min(organism_dates), max(organism_dates)
        values = []
        current = start
        while current <= end:
            value = counts.get((organism, current), 0)
            values.append(value)
            series_rows.append({"organism": organism, "date": current.isoformat(), "culture_count": value})
            current += timedelta(days=1)
        if len(values) <= BASELINE_DAYS:
            continue
        baseline = values[:BASELINE_DAYS]
        target = sum(baseline) / len(baseline)
        sigma = _std([float(value) for value in baseline])
        ewma = target
        cusum = 0.0
        for offset, value in enumerate(values[BASELINE_DAYS:], BASELINE_DAYS):
            ewma = ALPHA * value + (1 - ALPHA) * ewma
            cusum = max(0.0, cusum + value - target - CUSUM_SLACK_SIGMA * sigma)
            deviation = abs(value - ewma) / sigma
            row_date = start + timedelta(days=offset)
            score_rows.append(
                {
                    "organism": organism,
                    "date": row_date.isoformat(),
                    "culture_count": value,
                    "ewma": round(ewma, 6),
                    "ewma_deviation_sigma": round(deviation, 6),
                    "ewma_alert": deviation >= CONTROL_LIMIT_SIGMA,
                    "cusum": round(cusum, 6),
                    "cusum_alert": cusum >= CUSUM_THRESHOLD_SIGMA * sigma,
                    "baseline_days": BASELINE_DAYS,
                }
            )
    with (CLEANED_DIR / SERIES_NAME).open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=["organism", "date", "culture_count"])
        writer.writeheader()
        writer.writerows(series_rows)
    with (CLEANED_DIR / SCORES_NAME).open("w", newline="", encoding="utf-8") as handle:
        fields = [
            "organism", "date", "culture_count", "ewma", "ewma_deviation_sigma",
            "ewma_alert", "cusum", "cusum_alert", "baseline_days",
        ]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(score_rows)
    return {"daily_rows": len(series_rows), "score_rows": len(score_rows), "organisms": len(by_organism)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run", action="store_true", help="build daily series and SPC scores")
    args = parser.parse_args()
    if not args.run:
        parser.error("use --run")
    print(json.dumps(run(), indent=2))


if __name__ == "__main__":
    main()
