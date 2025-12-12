# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
SurrealDB Integration Tests
Tests graph operations and transport network queries
"""

module TestSurrealDB

using Test
using HTTP
using JSON3

# =============================================================================
# Test Configuration
# =============================================================================

const SURREALDB_URL = get(ENV, "SURREALDB_URL", "http://localhost:8000")
const SURREALDB_USER = get(ENV, "SURREALDB_USER", "root")
const SURREALDB_PASS = get(ENV, "SURREALDB_PASS", "root")

function surreal_query(sql::String)
    headers = [
        "Content-Type" => "application/text",
        "Accept" => "application/json",
        "NS" => "veds",
        "DB" => "transport",
    ]
    resp = HTTP.post(
        "$SURREALDB_URL/sql",
        headers,
        sql;
        basic_authorization=(SURREALDB_USER, SURREALDB_PASS),
        status_exception=false,
    )
    (status=resp.status, body=JSON3.read(String(resp.body)))
end

function setup_namespace()
    surreal_query("DEFINE NAMESPACE veds; USE NS veds; DEFINE DATABASE transport;")
end

# =============================================================================
# Connection Tests
# =============================================================================

@testset "SurrealDB Connection" begin
    @testset "health_check" begin
        resp = HTTP.get("$SURREALDB_URL/health"; status_exception=false)
        @test resp.status == 200
    end

    @testset "namespace_exists" begin
        setup_namespace()
        result = surreal_query("INFO FOR NS;")
        @test result.status == 200
    end
end

# =============================================================================
# Port Operations Tests
# =============================================================================

@testset "Port Operations" begin
    setup_namespace()

    sample_port = Dict(
        "id" => "port:shanghai",
        "name" => "Shanghai",
        "country" => "CN",
        "lat" => 31.2304,
        "lon" => 121.4737,
        "capacity_teu" => 47000000,
        "port_type" => "hub",
    )

    @testset "create_port" begin
        query = """
        CREATE port:shanghai CONTENT {
            name: '$(sample_port["name"])',
            country: '$(sample_port["country"])',
            location: {
                lat: $(sample_port["lat"]),
                lon: $(sample_port["lon"])
            },
            capacity_teu: $(sample_port["capacity_teu"]),
            port_type: '$(sample_port["port_type"])'
        };
        """
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "query_port" begin
        query = "SELECT * FROM port:shanghai;"
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "query_ports_by_country" begin
        query = "SELECT * FROM port WHERE country = 'CN';"
        result = surreal_query(query)
        @test result.status == 200
    end
end

# =============================================================================
# Edge Operations Tests
# =============================================================================

@testset "Edge Operations" begin
    setup_namespace()

    @testset "create_edge" begin
        # First create ports
        surreal_query("""
        CREATE port:shanghai CONTENT { name: 'Shanghai', country: 'CN' };
        CREATE port:hongkong CONTENT { name: 'Hong Kong', country: 'HK' };
        """)

        # Create edge using RELATE
        query = """
        RELATE port:shanghai->transport_edge->port:hongkong CONTENT {
            mode: 'maritime',
            carrier: 'carrier:cosco',
            distance_km: 1200,
            time_hours: 48,
            cost_usd: 2500,
            carbon_kg: 850,
            min_wage_cents: 1500
        };
        """
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "query_outgoing_edges" begin
        query = "SELECT ->transport_edge->port AS destinations FROM port:shanghai;"
        result = surreal_query(query)
        @test result.status == 200
    end
end

# =============================================================================
# Graph Traversal Tests
# =============================================================================

@testset "Graph Traversal" begin
    setup_namespace()

    # Set up test graph
    setup_query = """
    DELETE port;
    DELETE transport_edge;

    CREATE port:shanghai CONTENT { name: 'Shanghai', country: 'CN', lat: 31.23, lon: 121.47 };
    CREATE port:singapore CONTENT { name: 'Singapore', country: 'SG', lat: 1.35, lon: 103.82 };
    CREATE port:dubai CONTENT { name: 'Dubai', country: 'AE', lat: 25.20, lon: 55.27 };
    CREATE port:rotterdam CONTENT { name: 'Rotterdam', country: 'NL', lat: 51.92, lon: 4.48 };

    RELATE port:shanghai->transport_edge->port:singapore CONTENT {
        mode: 'maritime', distance_km: 3800, time_hours: 96, cost_usd: 1500, carbon_kg: 2000
    };
    RELATE port:singapore->transport_edge->port:dubai CONTENT {
        mode: 'maritime', distance_km: 5800, time_hours: 144, cost_usd: 2500, carbon_kg: 3500
    };
    RELATE port:dubai->transport_edge->port:rotterdam CONTENT {
        mode: 'maritime', distance_km: 6200, time_hours: 168, cost_usd: 3000, carbon_kg: 4000
    };
    RELATE port:shanghai->transport_edge->port:rotterdam CONTENT {
        mode: 'maritime', distance_km: 19000, time_hours: 480, cost_usd: 4500, carbon_kg: 8000
    };
    """
    surreal_query(setup_query)

    @testset "direct_path" begin
        query = """
        SELECT
            in.name AS origin,
            out.name AS destination,
            mode,
            distance_km,
            cost_usd
        FROM transport_edge
        WHERE in = port:shanghai AND out = port:rotterdam;
        """
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "two_hop_paths" begin
        query = """
        SELECT
            port:shanghai AS start,
            ->transport_edge->port->transport_edge->port AS two_hops
        FROM ONLY port:shanghai;
        """
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "aggregate_path_cost" begin
        query = """
        SELECT
            math::sum(cost_usd) AS total_cost,
            math::sum(carbon_kg) AS total_carbon,
            math::sum(time_hours) AS total_time
        FROM transport_edge
        WHERE in IN [port:shanghai, port:singapore, port:dubai];
        """
        result = surreal_query(query)
        @test result.status == 200
    end
end

# =============================================================================
# Carrier Operations Tests
# =============================================================================

@testset "Carrier Operations" begin
    setup_namespace()

    sample_carrier = Dict(
        "id" => "carrier:cosco",
        "name" => "COSCO Shipping",
        "country" => "CN",
        "modes" => ["maritime"],
        "fleet_size" => 1300,
        "safety_score" => 0.92,
    )

    @testset "create_carrier" begin
        modes_json = JSON3.write(sample_carrier["modes"])
        query = """
        CREATE carrier:cosco CONTENT {
            name: '$(sample_carrier["name"])',
            country: '$(sample_carrier["country"])',
            modes: $modes_json,
            fleet_size: $(sample_carrier["fleet_size"]),
            safety_score: $(sample_carrier["safety_score"])
        };
        """
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "query_carriers_by_mode" begin
        query = "SELECT * FROM carrier WHERE modes CONTAINS 'maritime';"
        result = surreal_query(query)
        @test result.status == 200
    end

    @testset "query_safe_carriers" begin
        query = "SELECT * FROM carrier WHERE safety_score >= 0.8;"
        result = surreal_query(query)
        @test result.status == 200
    end
end

end # module
