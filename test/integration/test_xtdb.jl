# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
XTDB Integration Tests
Tests bitemporal constraint storage and SQL queries
"""

module TestXTDB

using Test
using HTTP
using JSON3
using Dates

# =============================================================================
# Test Configuration
# =============================================================================

const XTDB_URL = get(ENV, "XTDB_URL", "http://localhost:3000")

function xtdb_query(query::String)
    body = JSON3.write(Dict("query" => query))
    resp = HTTP.post(
        "$XTDB_URL/query",
        ["Content-Type" => "application/json", "Accept" => "application/json"],
        body;
        status_exception=false,
    )
    (status=resp.status, body=String(resp.body))
end

function xtdb_tx(ops::Vector)
    body = JSON3.write(Dict("tx-ops" => ops))
    resp = HTTP.post(
        "$XTDB_URL/tx",
        ["Content-Type" => "application/json", "Accept" => "application/json"],
        body;
        status_exception=false,
    )
    (status=resp.status, body=String(resp.body))
end

# =============================================================================
# Connection Tests
# =============================================================================

@testset "XTDB Connection" begin
    @testset "health_check" begin
        resp = HTTP.get("$XTDB_URL/status"; status_exception=false)
        @test resp.status == 200
    end

    @testset "query_empty" begin
        result = xtdb_query("SELECT * FROM constraints LIMIT 1")
        # May return 200 with empty results or 400 if table doesn't exist
        @test result.status in [200, 400]
    end
end

# =============================================================================
# Constraint Operations Tests
# =============================================================================

@testset "Constraint Operations" begin
    sample_constraint = Dict(
        "id" => "constraint:ilo_min_wage_de",
        "name" => "ILO Minimum Wage (Germany)",
        "category" => "wage",
        "is_hard" => true,
        "country" => "DE",
        "threshold" => 1260,
        "operator" => ">=",
        "description" => "Minimum hourly wage in Germany per ILO standards",
    )

    @testset "insert_constraint" begin
        ops = [
            ["put", "constraints", Dict(
                "xt/id" => sample_constraint["id"],
                "name" => sample_constraint["name"],
                "category" => sample_constraint["category"],
                "is_hard" => sample_constraint["is_hard"],
                "country" => sample_constraint["country"],
                "threshold" => sample_constraint["threshold"],
                "operator" => sample_constraint["operator"],
                "description" => sample_constraint["description"],
            )]
        ]
        result = xtdb_tx(ops)
        @test result.status in [200, 202]
    end

    @testset "query_constraint" begin
        result = xtdb_query("SELECT * FROM constraints WHERE _id = '$(sample_constraint["id"])'")
        @test result.status == 200
    end

    @testset "query_constraints_by_category" begin
        result = xtdb_query("SELECT * FROM constraints WHERE category = 'wage'")
        @test result.status == 200
    end

    @testset "query_hard_constraints" begin
        result = xtdb_query("SELECT * FROM constraints WHERE is_hard = true")
        @test result.status == 200
    end
end

# =============================================================================
# Bitemporal Query Tests
# =============================================================================

@testset "Bitemporal Queries" begin
    # Set up constraints with different valid times
    now = Dates.now(Dates.UTC)
    past = now - Day(30)
    future = now + Day(30)

    # Insert constraint valid from past
    ops1 = [
        ["put", "constraints", Dict(
            "xt/id" => "constraint:carbon_2024",
            "name" => "Carbon Budget 2024",
            "category" => "carbon",
            "threshold" => 10000,
            "valid_from" => Dates.format(past, "yyyy-mm-ddTHH:MM:SS"),
            "valid_to" => Dates.format(now, "yyyy-mm-ddTHH:MM:SS"),
        )]
    ]
    xtdb_tx(ops1)

    # Insert updated constraint valid from now
    ops2 = [
        ["put", "constraints", Dict(
            "xt/id" => "constraint:carbon_2025",
            "name" => "Carbon Budget 2025",
            "category" => "carbon",
            "threshold" => 8000,
            "valid_from" => Dates.format(now, "yyyy-mm-ddTHH:MM:SS"),
            "valid_to" => Dates.format(future, "yyyy-mm-ddTHH:MM:SS"),
        )]
    ]
    xtdb_tx(ops2)

    @testset "query_current_constraints" begin
        result = xtdb_query("SELECT * FROM constraints WHERE category = 'carbon'")
        @test result.status == 200
    end

    @testset "query_historical_constraints" begin
        past_str = Dates.format(now - Day(15), "yyyy-mm-ddTHH:MM:SS")
        result = xtdb_query("""
            SELECT * FROM constraints
            WHERE category = 'carbon'
            AND valid_from <= '$past_str'
            AND valid_to > '$past_str'
        """)
        @test result.status == 200
    end
end

# =============================================================================
# Constraint Evaluation Tests
# =============================================================================

@testset "Constraint Evaluation" begin
    # Set up various constraints
    constraints = [
        Dict(
            "xt/id" => "constraint:wage_de",
            "name" => "ILO Min Wage DE",
            "category" => "wage",
            "country" => "DE",
            "threshold" => 1260,
            "operator" => ">=",
            "is_hard" => true,
        ),
        Dict(
            "xt/id" => "constraint:wage_nl",
            "name" => "ILO Min Wage NL",
            "category" => "wage",
            "country" => "NL",
            "threshold" => 1355,
            "operator" => ">=",
            "is_hard" => true,
        ),
        Dict(
            "xt/id" => "constraint:carbon_limit",
            "name" => "Carbon per Route",
            "category" => "carbon",
            "threshold" => 10000,
            "operator" => "<=",
            "is_hard" => false,
        ),
        Dict(
            "xt/id" => "constraint:safety_min",
            "name" => "Minimum Safety Score",
            "category" => "safety",
            "threshold" => 0.7,
            "operator" => ">=",
            "is_hard" => true,
        ),
    ]

    for c in constraints
        xtdb_tx([["put", "constraints", c]])
    end

    @testset "get_constraints_for_country" begin
        result = xtdb_query("SELECT * FROM constraints WHERE country = 'DE' OR country IS NULL")
        @test result.status == 200
    end

    @testset "get_hard_constraints_only" begin
        result = xtdb_query("SELECT _id, name, category, threshold FROM constraints WHERE is_hard = true")
        @test result.status == 200
    end

    @testset "constraint_categories" begin
        result = xtdb_query("SELECT DISTINCT category FROM constraints")
        @test result.status == 200
    end
end

# =============================================================================
# Audit Trail Tests
# =============================================================================

@testset "Audit Trail" begin
    @testset "insert_and_update" begin
        # Initial insert
        ops1 = [["put", "constraints", Dict(
            "xt/id" => "constraint:test_audit",
            "name" => "Test Constraint",
            "threshold" => 100,
        )]]
        result1 = xtdb_tx(ops1)
        @test result1.status in [200, 202]

        # Update
        ops2 = [["put", "constraints", Dict(
            "xt/id" => "constraint:test_audit",
            "name" => "Test Constraint Updated",
            "threshold" => 200,
        )]]
        result2 = xtdb_tx(ops2)
        @test result2.status in [200, 202]
    end

    @testset "delete_constraint" begin
        # First insert
        xtdb_tx([["put", "constraints", Dict(
            "xt/id" => "constraint:to_delete",
            "name" => "To Be Deleted",
            "threshold" => 50,
        )]])

        # Delete
        result = xtdb_tx([["delete", "constraints", "constraint:to_delete"]])
        @test result.status in [200, 202]
    end
end

end # module
