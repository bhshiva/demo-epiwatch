"""
Generate risk scores using EWMA/CUSUM (from SPC) and Isolation Forest.
Includes hyperparameter tuning for the Isolation Forest model.
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.model_selection import ParameterGrid
from sklearn.preprocessing import StandardScaler

from sqlalchemy import text
from app.db import SessionLocal

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parents[2]
CLEANED_DIR = ROOT / "data" / "cleaned"
MODELS_DIR = ROOT / "data" / "models"
SPC_SCORES = CLEANED_DIR / "armd_spc_scores.csv"
GRAPH_FEATURES = CLEANED_DIR / "graph_intelligence_features.json"
MODEL_PATH = MODELS_DIR / "facility_risk_model.joblib"
FINAL_SCORES = CLEANED_DIR / "final_risk_scores.json"

def fetch_facility_data() -> pd.DataFrame:
    """Fetch facility-level data from the database.
    If analytics tables don't exist yet, return a mock DataFrame.
    """
    db = SessionLocal()
    try:
        # Try fetching from master.facilities to get a list of facilities
        facilities = db.execute(text("SELECT facility_id FROM master.facilities")).mappings().all()
        facility_ids = [str(f["facility_id"]) for f in facilities]
    except Exception as e:
        logger.warning(f"Could not fetch facilities from DB: {e}")
        facility_ids = ["fac-1", "fac-2", "fac-3"]
    finally:
        db.close()
        
    return pd.DataFrame({"facility_id": facility_ids})


def run(tune: bool = False) -> dict[str, object]:
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    
    # 1. Load SPC scores (EWMA / CUSUM)
    try:
        spc_df = pd.read_csv(SPC_SCORES)
        
        # Filter to recent history (last 14 days) to keep execution fast and dataset manageable
        if "date" in spc_df.columns:
            spc_df["date_dt"] = pd.to_datetime(spc_df["date"])
            spc_df = spc_df[spc_df["date_dt"] >= spc_df["date_dt"].max() - pd.Timedelta(days=14)].copy()
            spc_df = spc_df.drop(columns=["date_dt"])
            
        # Mock facility_id onto SPC scores since run_spc.py didn't include it
        fac_df = fetch_facility_data()
        
        # Cross join for demonstration to have facility-level data
        spc_df = spc_df.merge(fac_df, how="cross")
    except FileNotFoundError:
        logger.warning("SPC scores not found. Generating mock data.")
        spc_df = pd.DataFrame({
            "organism": ["E. coli", "S. aureus"],
            "ewma_deviation_sigma": [1.2, 0.5],
            "cusum": [0.8, 0.1],
            "culture_count": [10, 5],
            "facility_id": ["fac-1", "fac-2"]
        })

    # 2. Load Graph features
    graph_features_map = {}
    if GRAPH_FEATURES.exists():
        try:
            with open(GRAPH_FEATURES, "r", encoding="utf-8") as f:
                graph_data = json.load(f)
                for gf in graph_data.get("features", []):
                    graph_features_map[gf["facility_id"]] = gf.get("community_facility_count", 0)
        except Exception as e:
            logger.warning(f"Failed to load graph features: {e}")

    # Map graph features onto DataFrame
    spc_df["community_facility_count"] = spc_df["facility_id"].map(graph_features_map).fillna(0)
    
    # Define features for Isolation Forest
    feature_cols = ["ewma_deviation_sigma", "cusum", "culture_count", "community_facility_count"]
    
    # Handle missing values
    spc_df[feature_cols] = spc_df[feature_cols].fillna(0)
    
    X = spc_df[feature_cols].values
    
    # Scale features
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # 3. Hyperparameter Tuning for Isolation Forest
    best_model = None
    best_score = -float('inf')
    best_params = {}
    
    if tune:
        logger.info("Starting hyperparameter tuning for IsolationForest...")
        param_grid = {
            "n_estimators": [50, 100, 200],
            "max_samples": ["auto", 0.5, 0.8],
            "contamination": [0.01, 0.05, 0.1]
        }
        
        for params in ParameterGrid(param_grid):
            model = IsolationForest(random_state=42, **params)
            model.fit(X_scaled)
            
            # Since it's unsupervised, we evaluate by the variance of the decision function.
            # A higher variance often means better separation of anomalies vs normal.
            scores = model.decision_function(X_scaled)
            score_variance = scores.var()
            
            if score_variance > best_score:
                best_score = score_variance
                best_model = model
                best_params = params
                
        logger.info(f"Best params: {best_params} (Variance: {best_score:.4f})")
    else:
        logger.info("Using default hyperparameters for IsolationForest...")
        best_model = IsolationForest(random_state=42, n_estimators=100, contamination=0.05)
        best_model.fit(X_scaled)
        best_params = {"n_estimators": 100, "contamination": 0.05}
        
    # 4. Generate Predictions and Composite Risk Score
    # Anomaly score: lower means more anomalous. We negate it so higher = higher risk.
    if len(X_scaled) > 0:
        spc_df["if_anomaly_score"] = -best_model.decision_function(X_scaled)
    else:
        spc_df["if_anomaly_score"] = 0
        
    # Normalize components for composite score [0, 1]
    def min_max_norm(series):
        if series.max() == series.min():
            return pd.Series([0]*len(series))
        return (series - series.min()) / (series.max() - series.min())
        
    w1, w2, w3 = 1/3, 1/3, 1/3
    spc_df["norm_ewma"] = min_max_norm(spc_df["ewma_deviation_sigma"])
    spc_df["norm_cusum"] = min_max_norm(spc_df["cusum"])
    spc_df["norm_if"] = min_max_norm(spc_df["if_anomaly_score"])
    
    spc_df["composite_risk_score"] = (
        w1 * spc_df["norm_ewma"] + 
        w2 * spc_df["norm_cusum"] + 
        w3 * spc_df["norm_if"]
    )
    
    # 5. Save Model and Scores
    joblib.dump({"model": best_model, "scaler": scaler, "features": feature_cols}, MODEL_PATH)
    logger.info(f"Saved model to {MODEL_PATH}")
    
    # Export results
    FINAL_SCORES.write_text(spc_df.to_json(orient="records"), encoding="utf-8")
    
    # Determine alerts
    alerts_generated = int((spc_df["composite_risk_score"] > 0.7).sum())
    
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "rows_scored": len(spc_df),
        "alerts_generated": alerts_generated,
        "best_params": best_params
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--tune", action="store_true", help="Run hyperparameter tuning")
    args = parser.parse_args()
    
    result = run(tune=args.tune)
    print(json.dumps(result, indent=2))
