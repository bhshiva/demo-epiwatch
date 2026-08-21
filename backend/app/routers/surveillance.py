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
from app.schemas import DiseaseDailyPoint, FacilityGeo, SurveillanceMetricOut
from app.services import cache

router = APIRouter(prefix="/surveillance", tags=["surveillance"])

# Admin's job is facility-onboarding review, not statistics -- same
# least-privilege boundary as lab.py's admin exclusion.
health_authority_user = require_role("health_authority")

CACHE_TTL_SECONDS = 5 * 60


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
