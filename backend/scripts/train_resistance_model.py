"""Train and evaluate a leakage-safe ARMD resistance baseline."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from datetime import date
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
CLEANED_DIR = PROJECT_ROOT / "data" / "cleaned"
MODELS_DIR = PROJECT_ROOT / "data" / "models"
INPUT_NAME = "armd_resistance.csv"
MODEL_NAME = "armd_resistance_baseline.json"


def _key(organism: str, antibiotic: str) -> str:
    return f"{organism}|{antibiotic}"


def _rate(resistant: int, tested: int, prior: float, strength: int) -> float:
    return (resistant + strength * prior) / (tested + strength)


def train() -> dict:
    source = CLEANED_DIR / INPUT_NAME
    if not source.exists():
        raise FileNotFoundError(f"prepared ARMD data not found: {source}")

    dates: list[date] = []
    rows: list[dict[str, str]] = []
    with source.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            row_date = date.fromisoformat(row["collection_date"])
            dates.append(row_date)
            rows.append(row)

    unique_dates = sorted(set(dates))
    if len(unique_dates) < 2:
        raise ValueError("at least two collection dates are required for a time split")
    cutoff = unique_dates[max(0, int(len(unique_dates) * 0.8) - 1)]
    train_rows = [row for row in rows if date.fromisoformat(row["collection_date"]) <= cutoff]
    test_rows = [row for row in rows if date.fromisoformat(row["collection_date"]) > cutoff]
    if not train_rows or not test_rows:
        raise ValueError("chronological split produced an empty partition")

    global_counts = Counter()
    organism_counts: dict[str, Counter[int]] = defaultdict(Counter)
    pair_counts: dict[str, Counter[int]] = defaultdict(Counter)
    for row in train_rows:
        label = int(row["resistant"])
        global_counts[label] += 1
        organism_counts[row["organism"]][label] += 1
        pair_counts[_key(row["organism"], row["antibiotic"])][label] += 1

    global_prior = global_counts[1] / sum(global_counts.values())
    organism_rates = {
        organism: _rate(counts[1], sum(counts.values()), global_prior, 20)
        for organism, counts in organism_counts.items()
    }
    pair_rates = {
        pair: _rate(counts[1], sum(counts.values()), organism_rates[pair.split("|", 1)[0]], 10)
        for pair, counts in pair_counts.items()
    }

    correct = 0
    predicted_positive = 0
    actual_positive = 0
    true_positive = 0
    for row in test_rows:
        pair = _key(row["organism"], row["antibiotic"])
        probability = pair_rates.get(pair, organism_rates.get(row["organism"], global_prior))
        predicted = probability >= 0.5
        actual = int(row["resistant"]) == 1
        correct += predicted == actual
        predicted_positive += predicted
        actual_positive += actual
        true_positive += predicted and actual

    precision = true_positive / predicted_positive if predicted_positive else 0.0
    recall = true_positive / actual_positive if actual_positive else 0.0
    metrics = {
        "train_rows": len(train_rows),
        "test_rows": len(test_rows),
        "cutoff_date": cutoff.isoformat(),
        "accuracy": correct / len(test_rows),
        "precision": precision,
        "recall": recall,
        "global_resistance_rate_train": global_prior,
    }
    artifact = {
        "model_type": "smoothed_categorical_resistance_baseline",
        "label": "resistant",
        "source": "Dryad ARMD observed susceptibility only",
        "training_cutoff_date": cutoff.isoformat(),
        "global_rate": global_prior,
        "organism_rates": organism_rates,
        "organism_antibiotic_rates": pair_rates,
        "metrics": metrics,
    }
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    (MODELS_DIR / MODEL_NAME).write_text(json.dumps(artifact, indent=2) + "\n", encoding="utf-8")
    (CLEANED_DIR / "armd_resistance_model_metrics.json").write_text(
        json.dumps(metrics, indent=2) + "\n", encoding="utf-8"
    )
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train", action="store_true", help="train and evaluate the ARMD baseline")
    args = parser.parse_args()
    if args.train:
        print(json.dumps(train(), indent=2))
    else:
        parser.error("use --train")


if __name__ == "__main__":
    main()
