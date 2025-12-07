"""
Dragonfly (Redis-compatible) Integration Tests
Tests constraint caching and pub/sub for hot path
"""

import pytest
import json
import time
import threading
from typing import List

import redis


class TestDragonflyConnection:
    """Test basic Dragonfly connectivity."""

    @pytest.fixture
    def redis_client(self, dragonfly_url: str):
        """Create Redis client for Dragonfly."""
        client = redis.from_url(dragonfly_url, decode_responses=True)
        yield client
        client.close()

    def test_ping(self, redis_client):
        """Verify Dragonfly is responding."""
        assert redis_client.ping() is True

    def test_info(self, redis_client):
        """Get server info."""
        info = redis_client.info()
        assert "redis_version" in info or "dragonfly_version" in info


class TestConstraintCache:
    """Test constraint caching operations."""

    @pytest.fixture
    def redis_client(self, dragonfly_url: str):
        """Create Redis client."""
        client = redis.from_url(dragonfly_url, decode_responses=True)
        yield client
        client.flushall()
        client.close()

    def test_cache_constraint(self, redis_client, sample_constraint):
        """Cache a constraint."""
        key = f"constraint:{sample_constraint['id']}"
        value = json.dumps(sample_constraint)

        redis_client.set(key, value)

        retrieved = redis_client.get(key)
        assert retrieved is not None
        assert json.loads(retrieved)["name"] == sample_constraint["name"]

    def test_cache_constraint_with_ttl(self, redis_client, sample_constraint):
        """Cache constraint with expiration."""
        key = f"constraint:{sample_constraint['id']}"
        value = json.dumps(sample_constraint)

        redis_client.setex(key, 60, value)  # 60 second TTL

        ttl = redis_client.ttl(key)
        assert ttl > 0 and ttl <= 60

    def test_cache_multiple_constraints(self, redis_client):
        """Cache multiple constraints in pipeline."""
        constraints = [
            {"id": "c1", "name": "Wage DE", "threshold": 1260},
            {"id": "c2", "name": "Wage NL", "threshold": 1355},
            {"id": "c3", "name": "Carbon", "threshold": 10000},
        ]

        pipe = redis_client.pipeline()
        for c in constraints:
            pipe.set(f"constraint:{c['id']}", json.dumps(c))
        pipe.execute()

        # Verify all cached
        for c in constraints:
            assert redis_client.exists(f"constraint:{c['id']}")

    def test_get_constraints_by_pattern(self, redis_client):
        """Get all constraints matching pattern."""
        # Set up test data
        redis_client.set("constraint:wage_de", json.dumps({"id": "wage_de"}))
        redis_client.set("constraint:wage_nl", json.dumps({"id": "wage_nl"}))
        redis_client.set("constraint:carbon", json.dumps({"id": "carbon"}))

        # Find all constraints
        keys = redis_client.keys("constraint:*")
        assert len(keys) >= 3

    def test_hash_constraint_storage(self, redis_client, sample_constraint):
        """Store constraint as hash for partial updates."""
        key = f"constraint:hash:{sample_constraint['id']}"

        redis_client.hset(key, mapping={
            "name": sample_constraint["name"],
            "category": sample_constraint["category"],
            "threshold": str(sample_constraint["threshold"]),
            "is_hard": str(sample_constraint["is_hard"]),
        })

        # Get single field
        name = redis_client.hget(key, "name")
        assert name == sample_constraint["name"]

        # Get all fields
        all_fields = redis_client.hgetall(key)
        assert len(all_fields) == 4


class TestConstraintSets:
    """Test constraint set operations for efficient lookup."""

    @pytest.fixture
    def redis_client(self, dragonfly_url: str):
        """Create Redis client."""
        client = redis.from_url(dragonfly_url, decode_responses=True)
        yield client
        client.flushall()
        client.close()

    def test_country_constraint_set(self, redis_client):
        """Maintain set of constraints by country."""
        # Add constraints to country sets
        redis_client.sadd("country:DE:constraints", "wage_de", "carbon", "safety")
        redis_client.sadd("country:NL:constraints", "wage_nl", "carbon", "safety")
        redis_client.sadd("country:*:constraints", "carbon", "safety")  # Global

        # Get constraints for Germany
        de_constraints = redis_client.smembers("country:DE:constraints")
        assert "wage_de" in de_constraints

        # Get global constraints
        global_constraints = redis_client.smembers("country:*:constraints")
        assert "carbon" in global_constraints

    def test_hard_constraint_set(self, redis_client):
        """Maintain set of hard constraints for quick filtering."""
        redis_client.sadd("constraints:hard", "wage_de", "wage_nl", "safety", "sanctions")
        redis_client.sadd("constraints:soft", "carbon", "time_preference")

        hard = redis_client.smembers("constraints:hard")
        soft = redis_client.smembers("constraints:soft")

        assert "wage_de" in hard
        assert "carbon" in soft
        assert "wage_de" not in soft


class TestTrackingPubSub:
    """Test pub/sub for real-time tracking updates."""

    @pytest.fixture
    def redis_client(self, dragonfly_url: str):
        """Create Redis client."""
        client = redis.from_url(dragonfly_url, decode_responses=True)
        yield client
        client.close()

    def test_publish_tracking_event(self, redis_client):
        """Publish a tracking event."""
        event = {
            "shipment_id": "SHIP-001",
            "timestamp": "2025-01-15T10:30:00Z",
            "lat": 31.2304,
            "lon": 121.4737,
            "status": "in_transit",
            "carrier": "COSCO",
        }

        # Publish to channel
        subscribers = redis_client.publish("tracking:updates", json.dumps(event))
        # No subscribers yet, that's OK
        assert subscribers >= 0

    def test_subscribe_tracking_events(self, redis_client, dragonfly_url):
        """Subscribe to tracking events."""
        received_messages: List[dict] = []

        def subscriber_thread():
            sub_client = redis.from_url(dragonfly_url, decode_responses=True)
            pubsub = sub_client.pubsub()
            pubsub.subscribe("tracking:updates")

            for message in pubsub.listen():
                if message["type"] == "message":
                    received_messages.append(json.loads(message["data"]))
                    break  # Exit after first message

            pubsub.unsubscribe()
            sub_client.close()

        # Start subscriber in thread
        thread = threading.Thread(target=subscriber_thread)
        thread.start()

        # Wait for subscription to be ready
        time.sleep(0.5)

        # Publish event
        event = {"shipment_id": "SHIP-002", "status": "arrived"}
        redis_client.publish("tracking:updates", json.dumps(event))

        # Wait for message
        thread.join(timeout=2)

        assert len(received_messages) == 1
        assert received_messages[0]["shipment_id"] == "SHIP-002"


class TestHotPathCache:
    """Test hot path constraint caching for optimizer."""

    @pytest.fixture
    def redis_client(self, dragonfly_url: str):
        """Create Redis client."""
        client = redis.from_url(dragonfly_url, decode_responses=True)
        yield client
        client.flushall()
        client.close()

    def test_compiled_constraint_cache(self, redis_client):
        """Cache pre-compiled constraints for fast evaluation."""
        # Simulated compiled constraint (would be MessagePack in production)
        compiled = {
            "id": "wage_de",
            "check_fn": ">=",
            "threshold": 1260,
            "field": "wage_cents",
        }

        # Store with constraint version for cache invalidation
        key = "compiled:v1:wage_de"
        redis_client.set(key, json.dumps(compiled))

        retrieved = json.loads(redis_client.get(key))
        assert retrieved["threshold"] == 1260

    def test_batch_constraint_fetch(self, redis_client):
        """Fetch multiple compiled constraints in one round-trip."""
        # Set up compiled constraints
        constraints = {
            "compiled:v1:wage_de": {"threshold": 1260},
            "compiled:v1:wage_nl": {"threshold": 1355},
            "compiled:v1:carbon": {"threshold": 10000},
        }

        for k, v in constraints.items():
            redis_client.set(k, json.dumps(v))

        # Batch fetch with MGET
        keys = list(constraints.keys())
        values = redis_client.mget(keys)

        assert len(values) == 3
        assert all(v is not None for v in values)

    def test_constraint_version_tracking(self, redis_client):
        """Track constraint versions for cache invalidation."""
        # Set initial version
        redis_client.set("constraint_version", "1")

        # Cache constraint with version
        redis_client.set("compiled:v1:wage_de", json.dumps({"threshold": 1260}))

        # Simulate constraint update - increment version
        new_version = redis_client.incr("constraint_version")
        assert new_version == 2

        # New cache key with new version
        redis_client.set("compiled:v2:wage_de", json.dumps({"threshold": 1300}))

        # Old version still exists (until TTL or explicit delete)
        assert redis_client.exists("compiled:v1:wage_de")
        assert redis_client.exists("compiled:v2:wage_de")
