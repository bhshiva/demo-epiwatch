"""Create a PNG summary of model metrics and validation hot/cold values."""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[2]
CLEANED = ROOT / "data" / "cleaned"
OUTPUT = CLEANED / "model_values.png"


def main() -> None:
    metrics = json.loads((CLEANED / "combined_model_metrics.json").read_text(encoding="utf-8"))
    mapping = json.loads((CLEANED / "validation_hot_cold_mapping.json").read_text(encoding="utf-8"))
    locations = mapping[:20]

    figure, axes = plt.subplots(1, 2, figsize=(16, 8), gridspec_kw={"width_ratios": [1, 2]})
    figure.suptitle("EpiWatch Resistance Model: Validation Values", fontsize=18, fontweight="bold")

    metric_names = ["Accuracy", "Precision", "Recall", "ROC-AUC"]
    metric_values = [
        metrics["validation"]["accuracy"],
        metrics["validation"]["precision"],
        metrics["validation"]["recall"],
        metrics["validation"]["roc_auc"],
    ]
    bars = axes[0].bar(metric_names, metric_values, color=["#2f6690", "#f28e2b", "#59a14f", "#b07aa1"])
    axes[0].set_title("Validation Metrics")
    axes[0].set_ylim(0, 1)
    axes[0].set_ylabel("Score")
    axes[0].tick_params(axis="x", rotation=35)
    for bar, value in zip(bars, metric_values):
        axes[0].text(bar.get_x() + bar.get_width() / 2, value + 0.025, f"{value:.3f}", ha="center", fontweight="bold")

    labels = [row["location"][:28] for row in locations]
    values = [row["mean_predicted_resistance"] for row in locations]
    colors = ["#d1495b" if row["map_class"] == "hot" else "#2e86ab" for row in locations]
    axes[1].barh(labels[::-1], values[::-1], color=colors[::-1])
    axes[1].axvline(0.5, color="#333333", linestyle="--", linewidth=1)
    axes[1].set_title("Top Validation Locations: Hot / Cold")
    axes[1].set_xlabel("Mean predicted resistance")
    axes[1].set_xlim(0, 1)
    axes[1].text(0.02, 1.02, "Cold < 0.5    |    Hot >= 0.5", transform=axes[1].transAxes, fontsize=10)

    figure.text(0.5, 0.02, "Mapping uses frozen validation predictions only; it is not a confirmed outbreak map.", ha="center", fontsize=10)
    figure.tight_layout(rect=[0, 0.05, 1, 0.95])
    figure.savefig(OUTPUT, dpi=160, bbox_inches="tight")
    print(OUTPUT)


if __name__ == "__main__":
    main()
