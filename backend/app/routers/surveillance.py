"""
Read-only, all-facility surveillance API for the Health Authority role.

Everything here reads the analytics.* tables (refreshed periodically by
scripts/generate_surveillance_tables.py), cached via app/services/cache.py.
Unlike every other router, these queries are deliberately NOT facility-
scoped: seeing across facilities is the entire point of this role.
"""

from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_session
from app.deps import require_role
from app.models import Doctor
from app.schemas import DiseaseDailyPoint, DistrictSummary, FacilityGeo, SurveillanceMetricOut, SurveillanceSummary, RiskScoreOut, AlertOut
from app.services import cache

router = APIRouter(prefix="/surveillance", tags=["surveillance"])

# Admin's job is facility-onboarding review, not statistics -- same
# least-privilege boundary as lab.py's admin exclusion.
health_authority_user = require_role("health_authority")

CACHE_TTL_SECONDS = 5 * 60


@router.get("/summary", response_model=SurveillanceSummary)
def summary(
    db: Session = Depends(get_session),
    user: Doctor = Depends(health_authority_user),
):
    """
    Headline KPI tiles. Deliberately NOT cached and NOT read from the
    batched analytics.* tables -- "Live Surveillance" means live: these
    query raw.patient_reports directly so the tiles never lag behind the
    5-hourly ETL cycle the rest of this router's endpoints accept.
    """
    facilities_reporting = db.execute(
        text(
            "SELECT COUNT(DISTINCT facility_id) FROM raw.patient_reports "
            "WHERE report_date >= CURRENT_DATE - INTERVAL '30 days'"
        )
    ).scalar()
    reports_today = db.execute(
        text("SELECT COUNT(*) FROM raw.patient_reports WHERE report_date = CURRENT_DATE")
    ).scalar()
    return SurveillanceSummary(
        facilities_reporting=facilities_reporting or 0,
        reports_today=reports_today or 0,
    )


@router.get("/districts", response_model=list[DistrictSummary])
def districts(
    db: Session = Depends(get_session),
    user: Doctor = Depends(health_authority_user),
):
    """Per-district facility/case-count rollup, for the region drill-down panel."""
    cache_key = "surveillance:districts"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    rows = db.execute(
        text(
            """
            SELECT
                f.district, f.state,
                COUNT(DISTINCT f.facility_id) AS facility_count,
                COALESCE(SUM(df.case_count), 0) AS recent_case_count
            FROM master.facilities f
            LEFT JOIN analytics.disease_facility df
                ON df.facility_id = f.facility_id
               AND df.window_end >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY f.district, f.state
            ORDER BY recent_case_count DESC
            """
        )
    ).mappings().all()
    result = [dict(r) for r in rows]
    cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
    return result


@router.get("/disease-daily", response_model=list[DiseaseDailyPoint])
def disease_daily(
    diagnosis: str | None = None,
    days: int = Query(default=30, le=180),
    db: Session = Depends(get_session),
    user: Doctor = Depends(health_authority_user),
):
    """Statewide daily case counts (facility_id IS NULL rows) for the trailing window."""
    cache_key = f"surveillance:disease-daily:{diagnosis}:{days}"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    since = date.today() - timedelta(days=days)
    query = (
        "SELECT report_date, diagnosis, case_count FROM analytics.disease_daily "
        "WHERE facility_id IS NULL AND report_date >= :since"
    )
    params = {"since": since}
    if diagnosis:
        query += " AND diagnosis = :diagnosis"
        params["diagnosis"] = diagnosis
    query += " ORDER BY report_date"

    rows = db.execute(text(query), params).mappings().all()
    result = [dict(r) for r in rows]
    cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
    return result


@router.get("/metrics", response_model=list[SurveillanceMetricOut])
def metrics(
    metric_name: str = Query(description="e.g. 'resistance_rate' or 'mdr_rate'"),
    facility_id: str | None = None,
    db: Session = Depends(get_session),
    user: Doctor = Depends(health_authority_user),
):
    """Latest window's value per facility (plus the statewide rollup) for one metric."""
    cache_key = f"surveillance:metrics:{metric_name}:{facility_id}"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    query = (
        "SELECT DISTINCT ON (facility_id) "
        "facility_id, pathogen, antibiotic, window_start, window_end, value, sample_size "
        "FROM analytics.surveillance_metrics WHERE metric_name = :metric_name "
        "AND pathogen IS NULL AND antibiotic IS NULL"
    )
    params = {"metric_name": metric_name}
    if facility_id:
        query += " AND facility_id = :facility_id"
        params["facility_id"] = facility_id
    query += " ORDER BY facility_id, window_end DESC"

    rows = db.execute(text(query), params).mappings().all()
    result = [dict(r) for r in rows]
    cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
    return result


@router.get("/facilities-geo", response_model=list[FacilityGeo])
def facilities_geo(
    db: Session = Depends(get_session),
    user: Doctor = Depends(health_authority_user),
):
    """Facility locations plus their latest case count, for the outbreak map."""
    cache_key = "surveillance:facilities-geo"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    rows = db.execute(
        text(
            """
            SELECT
                f.facility_id, f.name, f.district, f.state, f.latitude, f.longitude,
                COALESCE(SUM(df.case_count), 0) AS recent_case_count
            FROM master.facilities f
            LEFT JOIN analytics.disease_facility df
                ON df.facility_id = f.facility_id
               AND df.window_end >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY f.facility_id, f.name, f.district, f.state, f.latitude, f.longitude
            """
        )
    ).mappings().all()
    result = [dict(r) for r in rows]
    cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
    return result


import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FINAL_SCORES = ROOT / "data" / "cleaned" / "final_risk_scores.json"

@router.get("/risk-scores", response_model=list[RiskScoreOut])
def risk_scores(
    user: Doctor = Depends(health_authority_user),
):
    """Latest risk scores generated by the machine learning pipeline."""
    cache_key = "surveillance:risk-scores"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    if FINAL_SCORES.exists():
        with open(FINAL_SCORES, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Map JSON properties to the model
            result = []
            for row in data:
                result.append({
                    "facility_id": row.get("facility_id", ""),
                    "organism": row.get("organism"),
                    "composite_risk_score": row.get("composite_risk_score", 0),
                    "norm_ewma": row.get("norm_ewma"),
                    "norm_cusum": row.get("norm_cusum"),
                    "norm_if": row.get("norm_if"),
                    "culture_count": row.get("culture_count"),
                })
            cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
            return result
    return []


@router.get("/alerts", response_model=list[AlertOut])
def alerts(
    user: Doctor = Depends(health_authority_user),
):
    """Latest elevated and critical alerts generated by the ML pipeline."""
    cache_key = "surveillance:alerts"
    cached = cache.get_json(cache_key)
    if cached is not None:
        return cached

    if FINAL_SCORES.exists():
        with open(FINAL_SCORES, "r", encoding="utf-8") as f:
            data = json.load(f)
            result = []
            for row in data:
                score = row.get("composite_risk_score", 0)
                if score >= 0.5:
                    alert_level = "Watch"
                    if score >= 0.85:
                        alert_level = "Critical"
                    elif score >= 0.7:
                        alert_level = "Elevated"
                        
                    result.append({
                        "facility_id": row.get("facility_id", ""),
                        "organism": row.get("organism"),
                        "alert_level": alert_level,
                        "composite_risk_score": score,
                        "date": row.get("date")
                    })
            # sort by score descending
            result = sorted(result, key=lambda x: x["composite_risk_score"], reverse=True)
            cache.set_json(cache_key, result, ttl=CACHE_TTL_SECONDS)
            return result
    return []
