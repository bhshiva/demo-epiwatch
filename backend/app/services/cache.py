"""
Read-through cache for analytics reads.

Postgres's analytics.* tables (refreshed every ~5h by
scripts/generate_surveillance_tables.py) remain the source of truth; Redis
only saves a repeated aggregation query within its TTL. A cold cache or a
Redis outage must degrade to "hit Postgres directly", never to an error --
this is an optimization, not a dependency the API can fail on.
"""

import decimal
import json
import os
import uuid
from datetime import date, datetime

import redis

DEFAULT_TTL_SECONDS = 5 * 60

_client: redis.Redis | None = None
_unavailable = False


def _get_client() -> redis.Redis | None:
    global _client, _unavailable
    if _unavailable:
        return None
    if _client is None:
        url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
        _client = redis.Redis.from_url(url, socket_connect_timeout=1, socket_timeout=1)
    return _client


def get_json(key: str):
    """Returns the cached value, or None on a miss or if Redis is unreachable."""
    client = _get_client()
    if client is None:
        return None
    try:
        raw = client.get(key)
    except redis.RedisError:
        _mark_unavailable()
        return None
    return json.loads(raw) if raw is not None else None


def _json_default(obj):
    """Handles the types raw SQL rows commonly come back as (date/UUID/Decimal)
    that json.dumps doesn't know natively."""
    if isinstance(obj, (date, datetime)):
        return obj.isoformat()
    if isinstance(obj, uuid.UUID):
        return str(obj)
    if isinstance(obj, decimal.Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def set_json(key: str, value, ttl: int = DEFAULT_TTL_SECONDS) -> None:
    """
    Best-effort write. A caching failure -- Redis being down, or a value
    this encoder still can't serialize -- must never fail the request it's
    caching for, only skip the cache for this call.
    """
    client = _get_client()
    if client is None:
        return
    try:
        payload = json.dumps(value, default=_json_default)
    except TypeError:
        return
    try:
        client.set(key, payload, ex=ttl)
    except redis.RedisError:
        _mark_unavailable()


def _mark_unavailable() -> None:
    # One failed call is enough to stop retrying for the rest of this
    # process's life -- a downed Redis shouldn't cost every subsequent
    # request a connection-timeout wait.
    global _unavailable
    _unavailable = True
