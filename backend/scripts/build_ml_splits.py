"""Build immutable training/validation splits from cleaned ARMD and NCBI AST data."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CLEANED = ROOT / "data" / "cleaned"
FIELDS = ["source", "sample_id", "organism", "antibiotic", "collection_date", "location", "resistant", "amr_genes", "strain", "snp_cluster"]
AST_ITEM = re.compile(r"^(.*?)=(R|S|I|NS|SSD)$")


def _write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def _armd_rows() -> list[dict[str, str]]:
    rows = []
    with (CLEANED / "armd_resistance.csv").open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            rows.append({
                "source": "armd",
                "sample_id": row["order_id"],
                "organism": row["organism"],
                "antibiotic": row["antibiotic"],
                "collection_date": row["collection_date"],
                "location": "STANFORD_EHR",
                "resistant": row["resistant"],
                "amr_genes": "",
                "strain": "",
                "snp_cluster": "",
            })
    return rows


def _ncbi_rows() -> list[dict[str, str]]:
    rows = []
    with (CLEANED / "ncbi_ecoli_human_clinical.csv").open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            for item in row["ast_phenotypes"].split(","):
                match = AST_ITEM.match(item.strip())
                if not match or match.group(2) not in {"R", "S"}:
                    continue
                rows.append({
                    "source": "ncbi",
                    "sample_id": row["target_acc"],
                    "organism": row["organism"],
                    "antibiotic": match.group(1).strip().upper(),
                    "collection_date": row["collection_date"],
                    "location": row["location"],
                    "resistant": str(int(match.group(2) == "R")),
                    "amr_genes": row["amr_genotypes_core"],
                    "strain": row["strain"],
                    "snp_cluster": row["snp_cluster"],
                })
    return rows


def _date_cutoff(rows: list[dict[str, str]], fraction: float) -> date:
    dates = sorted({date.fromisoformat(row["collection_date"]) for row in rows})
    return dates[min(len(dates) - 1, max(0, int(len(dates) * fraction) - 1))]


def build() -> dict[str, int | str]:
    rows = sorted(_armd_rows() + _ncbi_rows(), key=lambda row: (row["collection_date"], row["source"], row["sample_id"]))
    if not rows:
        raise ValueError("no compatible AST rows found")
    validation_cutoff = _date_cutoff(rows, 0.8)
    training = [row for row in rows if date.fromisoformat(row["collection_date"]) <= validation_cutoff]
    validation = [row for row in rows if date.fromisoformat(row["collection_date"]) > validation_cutoff]
    train_test_cutoff = _date_cutoff(training, 0.8)
    internal_train = [row for row in training if date.fromisoformat(row["collection_date"]) <= train_test_cutoff]
    test = [row for row in training if date.fromisoformat(row["collection_date"]) > train_test_cutoff]
    _write_rows(CLEANED / "training.csv", training)
    _write_rows(CLEANED / "validation.csv", validation)
    _write_rows(CLEANED / "training_internal_train.csv", internal_train)
    _write_rows(CLEANED / "training_internal_test.csv", test)
    summary = {
        "combined_rows": len(rows),
        "training_rows": len(training),
        "validation_rows": len(validation),
        "internal_train_rows": len(internal_train),
        "internal_test_rows": len(test),
        "validation_cutoff": validation_cutoff.isoformat(),
        "internal_train_test_cutoff": train_test_cutoff.isoformat(),
        "validation_used_for_training": False,
    }
    (CLEANED / "split_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", action="store_true")
    args = parser.parse_args()
    if not args.build:
        parser.error("use --build")
    print(json.dumps(build(), indent=2))


if __name__ == "__main__":
    main()
