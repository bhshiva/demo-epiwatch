"""
app.services.cache -- must degrade to "no cache" when Redis is unreachable,
never raise. This is exercised for real here (no local Redis in dev/CI),
not mocked, so it proves the actual fallback path works.
"""

from app.services import cache


def test_get_json_returns_none_without_raising_when_redis_is_down():
    assert cache.get_json("nonexistent-key") is None


def test_set_json_does_not_raise_when_redis_is_down():
    cache.set_json("some-key", {"a": 1})  # must not raise
