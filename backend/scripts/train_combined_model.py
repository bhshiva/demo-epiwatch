"""Train a sparse resistance model without fitting on validation data."""

from __future__ import annotations

import argparse
import csv
import json
import re
from datetime import date
from pathlib import Path
from typing import Any

import joblib
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    precision_score,
    precision_recall_curve,
    recall_score,
    roc_auc_score,
    roc_curve,
)

ROOT = Path(__file__).resolve().parents[2]
CLEANED = ROOT / "data" / "cleaned"
MODELS = ROOT / "data" / "models"
MODEL_PATH = MODELS / "combined_resistance_model.joblib"
TUNING_PATH = CLEANED / "combined_model_tuning.json"

# Exclude location, sample IDs, strains and SNP clusters: those fields would
# memorise source-specific identifiers or be unavailable for a future isolate.
FEATURE_SETS = ("basic", "genes", "genes_interactions")
ENHANCED_FEATURE_SETS = ("genes_interactions", "genes_organism_interactions")
VECTORIZER_SETTINGS = (
    {"name": "tfidf", "use_idf": True, "sublinear_tf": True},
    {"name": "term_frequency", "use_idf": False, "sublinear_tf": False},
)
C_VALUES = (0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0, 10.0)
CLASS_WEIGHTS = (None, "balanced")


def _rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def _token(value: str) -> str:
    """Make each categorical value one stable sparse-model token."""
    return re.sub(r"[^A-Z0-9]+", "_", value.upper()).strip("_") or "UNKNOWN"


def _text(row: dict[str, str], feature_set: str) -> str:
    genes = [_token(gene) for gene in re.findall(r"[^,=]+", row.get("amr_genes", ""))]
    organism, antibiotic = _token(row["organism"]), _token(row["antibiotic"])
    tokens = [
        f"organism_{organism}",
        f"antibiotic_{antibiotic}",
        f"organism_antibiotic_{organism}__{antibiotic}",
    ]
    if feature_set in {"genes", "genes_interactions", "genes_organism_interactions"}:
        tokens.extend(f"gene_{gene}" for gene in genes)
        tokens.append(f"gene_data_{bool(genes)}")
    if feature_set in {"genes_interactions", "genes_organism_interactions"}:
        tokens.extend(f"gene_antibiotic_{gene}__{antibiotic}" for gene in genes)
    if feature_set == "genes_organism_interactions":
        tokens.extend(f"organism_gene_{organism}__{gene}" for gene in genes)
    return " ".join(tokens)


def _vectorizer(settings: dict[str, Any]) -> TfidfVectorizer:
    return TfidfVectorizer(
        token_pattern=r"(?u)\S+", lowercase=False, use_idf=settings["use_idf"],
        sublinear_tf=settings["sublinear_tf"],
    )


def _evaluate(name: str, rows: list[dict[str, str]], probabilities: list[float]) -> dict[str, object]:
    actual = [int(row["resistant"]) for row in rows]
    predicted = [int(probability >= 0.5) for probability in probabilities]
    matrix = confusion_matrix(actual, predicted, labels=[0, 1]).tolist()
    fpr, tpr, thresholds = roc_curve(actual, probabilities)
    roc_rows = [
        {"threshold": float(threshold), "false_positive_rate": float(x), "true_positive_rate": float(y)}
        for threshold, x, y in zip(thresholds, fpr, tpr)
    ]
    (CLEANED / f"roc_{name}.csv").write_text(
        "threshold,false_positive_rate,true_positive_rate\n"
        + "\n".join(f"{row['threshold']},{row['false_positive_rate']},{row['true_positive_rate']}" for row in roc_rows)
        + "\n",
        encoding="utf-8",
    )
    return {
        "rows": len(rows),
        "accuracy": float(accuracy_score(actual, predicted)),
        "precision": float(precision_score(actual, predicted, zero_division=0)),
        "recall": float(recall_score(actual, predicted, zero_division=0)),
        "roc_auc": float(roc_auc_score(actual, probabilities)),
        "confusion_matrix": matrix,
    }


def _best_threshold(actual: list[int], probabilities: list[float]) -> tuple[float, float]:
    precision, recall, thresholds = precision_recall_curve(actual, probabilities)
    # The final precision/recall pair has no corresponding threshold.
    f1_scores = (2 * precision[:-1] * recall[:-1]) / (precision[:-1] + recall[:-1] + 1e-12)
    best_index = int(f1_scores.argmax())
    return float(thresholds[best_index]), float(f1_scores[best_index])


def _tuning_result(actual: list[int], probabilities: list[float], *, feature_set: str,
                   vectorizer_settings: dict[str, Any], c_value: float,
                   class_weight: str | None) -> dict[str, object]:
    threshold, f1 = _best_threshold(actual, probabilities)
    predicted = [int(value >= threshold) for value in probabilities]
    return {
        "feature_set": feature_set,
        "vectorizer": vectorizer_settings["name"],
        "vectorizer_settings": vectorizer_settings,
        "C": c_value,
        "class_weight": class_weight,
        "threshold": threshold,
        "f1": f1,
        "precision": float(precision_score(actual, predicted, zero_division=0)),
        "recall": float(recall_score(actual, predicted, zero_division=0)),
        "roc_auc": float(roc_auc_score(actual, probabilities)),
    }


def _hot_cold(rows: list[dict[str, str]], probabilities: list[float]) -> list[dict[str, object]]:
    buckets: dict[str, list[float]] = {}
    for row, probability in zip(rows, probabilities):
        buckets.setdefault(row["location"] or "UNKNOWN", []).append(probability)
    result = []
    for location, values in buckets.items():
        mean = sum(values) / len(values)
        result.append({
            "location": location,
            "samples": len(values),
            "mean_predicted_resistance": round(mean, 6),
            "map_class": "hot" if mean >= 0.5 else "cold",
        })
    return sorted(result, key=lambda row: row["mean_predicted_resistance"], reverse=True)


def train_and_validate(enhanced: bool = False) -> dict[str, object]:
    internal_train = _rows(CLEANED / "training_internal_train.csv")
    internal_test = _rows(CLEANED / "training_internal_test.csv")
    validation = _rows(CLEANED / "validation.csv")

    tune_cutoff = sorted(date.fromisoformat(row["collection_date"]) for row in internal_train)[
        int(len(internal_train) * 0.8)
    ]
    fit_rows = [row for row in internal_train if date.fromisoformat(row["collection_date"]) < tune_cutoff]
    tune_rows = [row for row in internal_train if date.fromisoformat(row["collection_date"]) >= tune_cutoff]
    candidates: list[dict[str, object]] = []
    tune_actual = [int(row["resistant"]) for row in tune_rows]
    fit_actual = [int(row["resistant"]) for row in fit_rows]
    feature_sets = ENHANCED_FEATURE_SETS if enhanced else FEATURE_SETS
    vectorizer_settings_list = VECTORIZER_SETTINGS[:1] if enhanced else VECTORIZER_SETTINGS
    c_values = (5.0, 10.0, 20.0, 50.0) if enhanced else C_VALUES
    for feature_set in feature_sets:
        for vectorizer_settings in vectorizer_settings_list:
            vectorizer = _vectorizer(vectorizer_settings)
            x_fit = vectorizer.fit_transform(_text(row, feature_set) for row in fit_rows)
            x_tune = vectorizer.transform(_text(row, feature_set) for row in tune_rows)
            for c_value in c_values:
                for class_weight in CLASS_WEIGHTS:
                    candidate = LogisticRegression(
                        C=c_value, max_iter=300, class_weight=class_weight,
                        solver="liblinear", random_state=42,
                    )
                    candidate.fit(x_fit, fit_actual)
                    candidates.append(_tuning_result(
                        tune_actual, candidate.predict_proba(x_tune)[:, 1].tolist(),
                        feature_set=feature_set, vectorizer_settings=vectorizer_settings,
                        c_value=c_value, class_weight=class_weight,
                    ))
    # F1 is appropriate for the rare resistant class; remaining metrics are
    # retained for every trial and resolve exact F1 ties deterministically.
    candidates.sort(key=lambda item: (item["f1"], item["roc_auc"], item["recall"]), reverse=True)
    winner = candidates[0]
    feature_set = str(winner["feature_set"])
    c_value = float(winner["C"])
    class_weight = winner["class_weight"]
    threshold = float(winner["threshold"])

    vectorizer = _vectorizer(dict(winner["vectorizer_settings"]))
    x_train = vectorizer.fit_transform(_text(row, feature_set) for row in internal_train)
    model = LogisticRegression(
        C=c_value, max_iter=300, class_weight=class_weight,
        solver="liblinear", random_state=42,
    )
    model.fit(x_train, [int(row["resistant"]) for row in internal_train])
    predictions = {}
    for name, rows in (("internal_test", internal_test), ("validation", validation)):
        probabilities = model.predict_proba(
            vectorizer.transform(_text(row, feature_set) for row in rows)
        )[:, 1].tolist()
        predictions[name] = probabilities
    for name, rows in (("internal_test", internal_test), ("validation", validation)):
        actual = [int(row["resistant"]) for row in rows]
        predicted = [int(value >= threshold) for value in predictions[name]]
        metrics_threshold = {
            "threshold": threshold,
            "accuracy": float(accuracy_score(actual, predicted)),
            "precision": float(precision_score(actual, predicted, zero_division=0)),
            "recall": float(recall_score(actual, predicted, zero_division=0)),
        }
        (CLEANED / f"{name}_threshold_metrics.json").write_text(
            json.dumps(metrics_threshold, indent=2) + "\n", encoding="utf-8"
        )
    metrics = {
        "internal_test": _evaluate("internal_test", internal_test, predictions["internal_test"]),
        "validation": _evaluate("validation", validation, predictions["validation"]),
        "tuned_threshold": threshold,
        "tuning_feature_set": feature_set,
        "tuning_vectorizer": winner["vectorizer"],
        "tuning_C": c_value,
        "tuning_class_weight": class_weight,
        "development_best_f1": winner["f1"],
        "development_best_roc_auc": winner["roc_auc"],
        "tuning_candidates": len(candidates),
        "tuning_profile": "enhanced" if enhanced else "full",
        "tuning_rows": len(tune_rows),
        "validation_used_for_training": False,
        "hot_cold_mapping_source": "validation_predictions_only",
    }
    MODELS.mkdir(parents=True, exist_ok=True)
    joblib.dump(
        {"vectorizer": vectorizer, "model": model, "feature_set": feature_set,
         "threshold": threshold, "tuning_winner": winner},
        MODEL_PATH,
    )
    (CLEANED / "combined_model_metrics.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    TUNING_PATH.write_text(json.dumps({
        "selection_split": "chronological tail of training_internal_train.csv",
        "selection_metric": "f1",
        "fit_rows": len(fit_rows),
        "tune_rows": len(tune_rows),
        "validation_used_for_training_or_selection": False,
        "candidates": candidates,
    }, indent=2) + "\n", encoding="utf-8")
    (CLEANED / "validation_hot_cold_mapping.json").write_text(
        json.dumps(_hot_cold(validation, predictions["validation"]), indent=2) + "\n", encoding="utf-8"
    )
    return metrics


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--train", action="store_true")
    parser.add_argument(
        "--enhanced", action="store_true",
        help="run the focused organism-specific AMR-gene interaction search",
    )
    args = parser.parse_args()
    if not args.train:
        parser.error("use --train")
    print(json.dumps(train_and_validate(enhanced=args.enhanced), indent=2))


if __name__ == "__main__":
    main()
