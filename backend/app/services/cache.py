"""
Read-through cache for analytics reads.

Postgres's analytics.* tables (refreshed every ~5h by
scripts/generate_surveillance_tables.py) remain the source of truth; Redis
only saves a repeated aggregation query within its TTL. A cold cache or a
Redis outage must degrade to "hit Postgres directly", never to an error --
this is an optimization, not a dependency the API can fail on.
"""

import json
import os

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


def set_json(key: str, value, ttl: int = DEFAULT_TTL_SECONDS) -> None:
    """Best-effort write. A caching failure must never fail the request it's caching for."""
    client = _get_client()
    if client is None:
        return
    try:
        client.set(key, json.dumps(value), ex=ttl)
    except redis.RedisError:
        _mark_unavailable()


def _mark_unavailable() -> None:
    # One failed call is enough to stop retrying for the rest of this
    # process's life -- a downed Redis shouldn't cost every subsequent
    # request a connection-timeout wait.
    global _unavailable
    _unavailable = True
