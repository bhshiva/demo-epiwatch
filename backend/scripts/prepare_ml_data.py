"""Prepare local ARMD and NCBI data for the first EpiWatch ML baseline."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = PROJECT_ROOT / "data" / "raw"
CLEANED_DIR = PROJECT_ROOT / "data" / "cleaned"
ARMD_DIR_NAME = "doi_10_5061_dryad_jq2bvq8kp__v20251022"
NCBI_FILES = {
    "E. coli_data.csv": ("ESCHERICHIA COLI", "562"),
    "Klebsiella pneumoniae.csv": ("KLEBSIELLA PNEUMONIAE", "573"),
    "Acinetobacter baumannii.csv": ("ACINETOBACTER BAUMANNII", "470"),
    "Pseudomonas aeruginosa.csv": ("PSEUDOMONAS AERUGINOSA", "287"),
    "Staphylococcus aureus.csv": ("STAPHYLOCOCCUS AUREUS", "1280"),
}

NCBI_COLUMNS = [
    "organism_group", "strain", "isolate_identifiers", "amr_genotypes_core",
    "ast_phenotypes", "amrfinderplus_version", "amrfinderplus_analysis_type",
    "host", "host_disease", "serovar", "species_taxid", "target_acc",
    "stress_genotypes", "creation_date", "location", "isolation_source",
    "isolation_type", "food_origin", "snp_cluster", "min_same", "min_diff",
    "biosample_acc", "assembly_acc", "amr_genotypes", "computed_types",
]


def _clean(value: str | None) -> str:
    return (value or "").strip()


def _canonical_organism(value: str) -> str:
    value = _clean(value).upper()
    replacements = {
        "E. COLI": "ESCHERICHIA COLI",
        "E.COLI": "ESCHERICHIA COLI",
        "ESCHERICHIA": "ESCHERICHIA COLI",
        "STAPH AUREUS {MRSA}": "STAPHYLOCOCCUS AUREUS",
    }
    return replacements.get(value, value)


def _parse_date(value: str) -> str:
    value = _clean(value)
    if not value:
        return ""
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        return value[:10] if re.match(r"^\d{4}-\d{2}-\d{2}", value) else ""


def _armd_input() -> Path:
    path = RAW_DIR / ARMD_DIR_NAME / "microbiology_cultures_cohort.csv"
    if not path.exists():
        raise FileNotFoundError(f"ARMD cohort not found: {path}")
    return path


def prepare_armd(output: Path) -> dict[str, int]:
    counts = Counter()
    output.parent.mkdir(parents=True, exist_ok=True)
    with _armd_input().open(newline="", encoding="utf-8-sig") as source, output.open(
        "w", newline="", encoding="utf-8"
    ) as target:
        reader = csv.DictReader(source)
        writer = csv.DictWriter(
            target,
            fieldnames=[
                "anon_id", "encounter_id", "order_id", "collection_date",
                "ordering_mode", "specimen_type", "culture_positive",
                "organism", "antibiotic", "susceptibility", "resistant",
            ],
        )
        writer.writeheader()
        for row in reader:
            counts["input_rows"] += 1
            organism = _canonical_organism(row.get("organism"))
            susceptibility = _clean(row.get("susceptibility")).upper()
            if not organism or organism == "NULL":
                counts["dropped_missing_organism"] += 1
                continue
            if susceptibility not in {"RESISTANT", "SUSCEPTIBLE", "INTERMEDIATE"}:
                counts["dropped_invalid_susceptibility"] += 1
                continue
            date = _parse_date(row.get("order_time_jittered_utc"))
            if not date:
                counts["dropped_invalid_date"] += 1
                continue
            writer.writerow(
                {
                    "anon_id": _clean(row.get("anon_id")),
                    "encounter_id": _clean(row.get("pat_enc_csn_id_coded")),
                    "order_id": _clean(row.get("order_proc_id_coded")),
                    "collection_date": date,
                    "ordering_mode": _clean(row.get("ordering_mode")),
                    "specimen_type": _clean(row.get("culture_description")).upper(),
                    "culture_positive": _clean(row.get("was_positive")),
                    "organism": organism,
                    "antibiotic": _clean(row.get("antibiotic")).upper(),
                    "susceptibility": susceptibility.title(),
                    "resistant": int(susceptibility == "RESISTANT"),
                }
            )
            counts["output_rows"] += 1
    return dict(counts)


def _repair_ncbi_row(row: list[str]) -> list[str] | None:
    if len(row) == len(NCBI_COLUMNS):
        return row
    target_index = next(
        (index for index, value in enumerate(row) if re.match(r"^PDT\d+\.\d+$", value)),
        None,
    )
    if target_index is None or target_index < 11:
        return None
    serovar_end = target_index - 1
    repaired = row[:9]
    repaired.append(",".join(row[9:serovar_end]))
    repaired.extend(row[serovar_end:])
    return repaired if len(repaired) == len(NCBI_COLUMNS) else None


def prepare_ncbi(output: Path) -> dict[str, int]:
    counts = Counter()
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "target_acc", "biosample_acc", "organism", "strain", "collection_date",
        "location", "host", "source_type", "isolation_type", "snp_cluster",
        "amr_genotypes", "amr_genotypes_core", "ast_phenotypes", "assembly_acc",
    ]
    with output.open("w", newline="", encoding="utf-8") as target:
        writer = csv.DictWriter(target, fieldnames=fields)
        writer.writeheader()
        for filename, (organism, species_taxid) in NCBI_FILES.items():
            input_path = RAW_DIR / filename
            if not input_path.exists():
                counts[f"missing_{filename}"] += 1
                continue
            with input_path.open(newline="", encoding="utf-8-sig") as source:
                reader = csv.reader(source)
                next(reader)
                for row in reader:
                    counts["input_rows"] += 1
                    row = _repair_ncbi_row(row)
                    if row is None:
                        counts["dropped_malformed_rows"] += 1
                        continue
                    if _clean(row[7]).lower() not in {"human", "homo sapiens"}:
                        counts["dropped_nonhuman"] += 1
                        continue
                    if _clean(row[16]).lower() != "clinical":
                        counts["dropped_nonclinical"] += 1
                        continue
                    if _clean(row[10]) != species_taxid:
                        counts["dropped_wrong_species"] += 1
                        continue
                    date = _parse_date(row[13])
                    if not date or not _clean(row[11]):
                        counts["dropped_invalid_identity_or_date"] += 1
                        continue
                    writer.writerow(
                        {
                            "target_acc": _clean(row[11]),
                            "biosample_acc": _clean(row[21]),
                            "organism": organism,
                            "strain": _clean(row[1]),
                            "collection_date": date,
                            "location": _clean(row[14]),
                            "host": _clean(row[7]),
                            "source_type": "Human",
                            "isolation_type": "clinical",
                            "snp_cluster": _clean(row[18]),
                            "amr_genotypes": _clean(row[23]),
                            "amr_genotypes_core": _clean(row[3]),
                            "ast_phenotypes": _clean(row[4]),
                            "assembly_acc": _clean(row[22]),
                        }
                    )
                    counts["output_rows"] += 1
                    counts["with_strain"] += bool(_clean(row[1]))
                    counts["with_snp_cluster"] += bool(_clean(row[18]))
                    counts["with_ast"] += bool(_clean(row[4]))
    return dict(counts)


def prepare() -> dict[str, dict[str, int]]:
    CLEANED_DIR.mkdir(parents=True, exist_ok=True)
    summary = {
        "armd": prepare_armd(CLEANED_DIR / "armd_resistance.csv"),
        "ncbi": prepare_ncbi(CLEANED_DIR / "ncbi_ecoli_human_clinical.csv"),
    }
    (CLEANED_DIR / "preprocessing_summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true", help="prepare both local datasets")
    args = parser.parse_args()
    if args.prepare:
        print(json.dumps(prepare(), indent=2))
    else:
        parser.error("use --prepare")


if __name__ == "__main__":
    main()
