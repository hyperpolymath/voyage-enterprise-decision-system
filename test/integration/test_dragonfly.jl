# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
Dragonfly (Redis-compatible) Integration Tests
Tests constraint caching and pub/sub for hot path

Uses Docker containers for isolated testing.
"""

module TestDragonfly

using Test
using JSON3
using Redis

# =============================================================================
# Test Configuration
# =============================================================================

const DRAGONFLY_HOST = get(ENV, "DRAGONFLY_HOST", "localhost")
const DRAGONFLY_PORT = parse(Int, get(ENV, "DRAGONFLY_PORT", "6379"))

function get_redis_client()
    Redis.RedisConnection(; host=DRAGONFLY_HOST, port=DRAGONFLY_PORT)
end

# =============================================================================
# Connection Tests
# =============================================================================

@testset "Dragonfly Connection" begin
    @testset "ping" begin
        client = get_redis_client()
        result = Redis.ping(client)
        @test result == "PONG"
        Redis.disconnect!(client)
    end

    @testset "info" begin
        client = get_redis_client()
        info = Redis.execute(client, ["INFO"])
        @test !isempty(info)
        Redis.disconnect!(client)
    end
end

# =============================================================================
# Constraint Cache Tests
# =============================================================================

@testset "Constraint Cache" begin
    client = get_redis_client()

    @testset "cache_constraint" begin
        constraint = Dict(
            "id" => "constraint:ilo_min_wage_de",
            "name" => "ILO Minimum Wage (Germany)",
            "category" => "wage",
            "is_hard" => true,
            "country" => "DE",
            "threshold" => 1260,
        )
        key = "constraint:$(constraint["id"])"
        value = JSON3.write(constraint)

        Redis.set(client, key, value)
        retrieved = Redis.get(client, key)

        @test !isnothing(retrieved)
        parsed = JSON3.read(retrieved, Dict)
        @test parsed["name"] == constraint["name"]
    end

    @testset "cache_constraint_with_ttl" begin
        constraint = Dict("id" => "test_ttl", "name" => "TTL Test")
        key = "constraint:test_ttl"
        value = JSON3.write(constraint)

        Redis.setex(client, key, 60, value)
        ttl = Redis.ttl(client, key)

        @test ttl > 0
        @test ttl <= 60
    end

    @testset "cache_multiple_constraints" begin
        constraints = [
            Dict("id" => "c1", "name" => "Wage DE", "threshold" => 1260),
            Dict("id" => "c2", "name" => "Wage NL", "threshold" => 1355),
            Dict("id" => "c3", "name" => "Carbon", "threshold" => 10000),
        ]

        # Set all constraints
        for c in constraints
            Redis.set(client, "constraint:$(c["id"])", JSON3.write(c))
        end

        # Verify all cached
        for c in constraints
            @test Redis.exists(client, "constraint:$(c["id"])") == 1
        end
    end

    @testset "get_constraints_by_pattern" begin
        Redis.set(client, "constraint:wage_de", JSON3.write(Dict("id" => "wage_de")))
        Redis.set(client, "constraint:wage_nl", JSON3.write(Dict("id" => "wage_nl")))
        Redis.set(client, "constraint:carbon", JSON3.write(Dict("id" => "carbon")))

        keys = Redis.keys(client, "constraint:*")
        @test length(keys) >= 3
    end

    @testset "hash_constraint_storage" begin
        constraint = Dict(
            "id" => "hash_test",
            "name" => "Hash Test Constraint",
            "category" => "wage",
            "threshold" => 1260,
            "is_hard" => true,
        )
        key = "constraint:hash:$(constraint["id"])"

        Redis.hset(client, key, "name", constraint["name"])
        Redis.hset(client, key, "category", constraint["category"])
        Redis.hset(client, key, "threshold", string(constraint["threshold"]))
        Redis.hset(client, key, "is_hard", string(constraint["is_hard"]))

        # Get single field
        name = Redis.hget(client, key, "name")
        @test name == constraint["name"]

        # Get all fields
        all_fields = Redis.hgetall(client, key)
        @test length(all_fields) == 4
    end

    Redis.execute(client, ["FLUSHALL"])
    Redis.disconnect!(client)
end

# =============================================================================
# Constraint Set Tests
# =============================================================================

@testset "Constraint Sets" begin
    client = get_redis_client()

    @testset "country_constraint_set" begin
        Redis.sadd(client, "country:DE:constraints", "wage_de", "carbon", "safety")
        Redis.sadd(client, "country:NL:constraints", "wage_nl", "carbon", "safety")
        Redis.sadd(client, "country:global:constraints", "carbon", "safety")

        de_constraints = Redis.smembers(client, "country:DE:constraints")
        @test "wage_de" in de_constraints

        global_constraints = Redis.smembers(client, "country:global:constraints")
        @test "carbon" in global_constraints
    end

    @testset "hard_constraint_set" begin
        Redis.sadd(client, "constraints:hard", "wage_de", "wage_nl", "safety", "sanctions")
        Redis.sadd(client, "constraints:soft", "carbon", "time_preference")

        hard = Redis.smembers(client, "constraints:hard")
        soft = Redis.smembers(client, "constraints:soft")

        @test "wage_de" in hard
        @test "carbon" in soft
        @test !("wage_de" in soft)
    end

    Redis.execute(client, ["FLUSHALL"])
    Redis.disconnect!(client)
end

# =============================================================================
# Pub/Sub Tests
# =============================================================================

@testset "Tracking PubSub" begin
    client = get_redis_client()

    @testset "publish_tracking_event" begin
        event = Dict(
            "shipment_id" => "SHIP-001",
            "timestamp" => "2025-01-15T10:30:00Z",
            "lat" => 31.2304,
            "lon" => 121.4737,
            "status" => "in_transit",
            "carrier" => "COSCO",
        )

        # Publish to channel (no subscribers, returns 0)
        subscribers = Redis.publish(client, "tracking:updates", JSON3.write(event))
        @test subscribers >= 0
    end

    Redis.disconnect!(client)
end

# =============================================================================
# Hot Path Cache Tests
# =============================================================================

@testset "Hot Path Cache" begin
    client = get_redis_client()

    @testset "compiled_constraint_cache" begin
        compiled = Dict(
            "id" => "wage_de",
            "check_fn" => ">=",
            "threshold" => 1260,
            "field" => "wage_cents",
        )

        key = "compiled:v1:wage_de"
        Redis.set(client, key, JSON3.write(compiled))

        retrieved = JSON3.read(Redis.get(client, key), Dict)
        @test retrieved["threshold"] == 1260
    end

    @testset "batch_constraint_fetch" begin
        constraints = Dict(
            "compiled:v1:wage_de" => Dict("threshold" => 1260),
            "compiled:v1:wage_nl" => Dict("threshold" => 1355),
            "compiled:v1:carbon" => Dict("threshold" => 10000),
        )

        for (k, v) in constraints
            Redis.set(client, k, JSON3.write(v))
        end

        # Batch fetch with MGET
        keys = collect(keys(constraints))
        values = Redis.mget(client, keys...)

        @test length(values) == 3
        @test all(!isnothing(v) for v in values)
    end

    @testset "constraint_version_tracking" begin
        Redis.set(client, "constraint_version", "1")

        # Cache constraint with version
        Redis.set(client, "compiled:v1:wage_de", JSON3.write(Dict("threshold" => 1260)))

        # Simulate constraint update - increment version
        new_version = Redis.incr(client, "constraint_version")
        @test new_version == 2

        # New cache key with new version
        Redis.set(client, "compiled:v2:wage_de", JSON3.write(Dict("threshold" => 1300)))

        # Old version still exists
        @test Redis.exists(client, "compiled:v1:wage_de") == 1
        @test Redis.exists(client, "compiled:v2:wage_de") == 1
    end

    Redis.execute(client, ["FLUSHALL"])
    Redis.disconnect!(client)
end

end # module
