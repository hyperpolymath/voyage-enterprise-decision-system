#!/usr/bin/env julia
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
VEDS Synthetic Data Generator

Generates realistic transport network data for the Shanghai → Rotterdam → London corridor.
Seeds both SurrealDB (transport network) and Dragonfly (constraint cache).

Usage:
    julia scripts/seed_data.jl [--surrealdb-url URL] [--dragonfly-url URL]
"""

using HTTP
using JSON3
using Redis
using ArgParse
using Random

# =============================================================================
# REFERENCE DATA
# =============================================================================

const COUNTRIES = Dict(
    "CN" => Dict("name" => "China", "min_wage_cents" => 350, "max_hours" => 44, "region" => "APAC"),
    "SG" => Dict("name" => "Singapore", "min_wage_cents" => 0, "max_hours" => 44, "region" => "APAC"),
    "MY" => Dict("name" => "Malaysia", "min_wage_cents" => 280, "max_hours" => 48, "region" => "APAC"),
    "EG" => Dict("name" => "Egypt", "min_wage_cents" => 180, "max_hours" => 48, "region" => "MENA"),
    "NL" => Dict("name" => "Netherlands", "min_wage_cents" => 1395, "max_hours" => 40, "region" => "EU"),
    "DE" => Dict("name" => "Germany", "min_wage_cents" => 1260, "max_hours" => 48, "region" => "EU"),
    "BE" => Dict("name" => "Belgium", "min_wage_cents" => 1955, "max_hours" => 38, "region" => "EU"),
    "FR" => Dict("name" => "France", "min_wage_cents" => 1398, "max_hours" => 35, "region" => "EU"),
    "GB" => Dict("name" => "United Kingdom", "min_wage_cents" => 1340, "max_hours" => 48, "region" => "EU"),
    "PL" => Dict("name" => "Poland", "min_wage_cents" => 660, "max_hours" => 48, "region" => "EU"),
)

const PORTS = [
    # China
    Dict("unlocode" => "CNSHA", "name" => "Shanghai", "country" => "CN", "lat" => 31.2304, "lon" => 121.4737,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL", "ROAD"], "dwell_hours" => 24),
    Dict("unlocode" => "CNNGB", "name" => "Ningbo", "country" => "CN", "lat" => 29.8683, "lon" => 121.5440,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL"], "dwell_hours" => 18),
    # Singapore
    Dict("unlocode" => "SGSIN", "name" => "Singapore", "country" => "SG", "lat" => 1.2644, "lon" => 103.8200,
         "type" => "SEAPORT", "modes" => ["MARITIME", "ROAD"], "dwell_hours" => 12),
    # Suez Canal
    Dict("unlocode" => "EGSUZ", "name" => "Port Said", "country" => "EG", "lat" => 31.2653, "lon" => 32.3019,
         "type" => "SEAPORT", "modes" => ["MARITIME"], "dwell_hours" => 6),
    # Europe
    Dict("unlocode" => "NLRTM", "name" => "Rotterdam", "country" => "NL", "lat" => 51.9225, "lon" => 4.4792,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL", "ROAD"], "dwell_hours" => 18),
    Dict("unlocode" => "DEHAM", "name" => "Hamburg", "country" => "DE", "lat" => 53.5511, "lon" => 9.9937,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL", "ROAD"], "dwell_hours" => 18),
    Dict("unlocode" => "BEANR", "name" => "Antwerp", "country" => "BE", "lat" => 51.2194, "lon" => 4.4025,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL", "ROAD"], "dwell_hours" => 18),
    # Inland/Rail hubs
    Dict("unlocode" => "DEDUI", "name" => "Duisburg", "country" => "DE", "lat" => 51.4344, "lon" => 6.7623,
         "type" => "RAILYARD", "modes" => ["RAIL", "ROAD"], "dwell_hours" => 8),
    Dict("unlocode" => "PLWAW", "name" => "Warsaw", "country" => "PL", "lat" => 52.2297, "lon" => 21.0122,
         "type" => "RAILYARD", "modes" => ["RAIL", "ROAD"], "dwell_hours" => 8),
    # UK
    Dict("unlocode" => "GBFXT", "name" => "Felixstowe", "country" => "GB", "lat" => 51.9536, "lon" => 1.3511,
         "type" => "SEAPORT", "modes" => ["MARITIME", "RAIL", "ROAD"], "dwell_hours" => 18),
    Dict("unlocode" => "GBLHR", "name" => "London Heathrow", "country" => "GB", "lat" => 51.4700, "lon" => -0.4543,
         "type" => "AIRPORT", "modes" => ["AIR", "ROAD"], "dwell_hours" => 4),
    Dict("unlocode" => "GBLON", "name" => "London (Distribution)", "country" => "GB", "lat" => 51.5074, "lon" => -0.1278,
         "type" => "INLAND_PORT", "modes" => ["ROAD", "RAIL"], "dwell_hours" => 6),
]

const CARRIERS = [
    # Shipping lines
    Dict("code" => "MAEU", "name" => "Maersk", "type" => "SHIPPING_LINE", "country" => "NL",
         "safety" => 5, "unionized" => true, "wage" => 2800, "hours" => 42),
    Dict("code" => "CMDU", "name" => "CMA CGM", "type" => "SHIPPING_LINE", "country" => "FR",
         "safety" => 4, "unionized" => true, "wage" => 2600, "hours" => 40),
    Dict("code" => "COSU", "name" => "COSCO", "type" => "SHIPPING_LINE", "country" => "CN",
         "safety" => 4, "unionized" => false, "wage" => 1200, "hours" => 48),
    Dict("code" => "MSCU", "name" => "MSC", "type" => "SHIPPING_LINE", "country" => "NL",
         "safety" => 4, "unionized" => true, "wage" => 2700, "hours" => 42),
    # Rail operators
    Dict("code" => "DBCG", "name" => "DB Cargo", "type" => "RAIL_OPERATOR", "country" => "DE",
         "safety" => 5, "unionized" => true, "wage" => 2400, "hours" => 38),
    Dict("code" => "SNCF", "name" => "SNCF Fret", "type" => "RAIL_OPERATOR", "country" => "FR",
         "safety" => 5, "unionized" => true, "wage" => 2500, "hours" => 35),
    Dict("code" => "PKPC", "name" => "PKP Cargo", "type" => "RAIL_OPERATOR", "country" => "PL",
         "safety" => 4, "unionized" => true, "wage" => 1400, "hours" => 42),
    # Trucking
    Dict("code" => "DFDS", "name" => "DFDS Logistics", "type" => "TRUCKING", "country" => "NL",
         "safety" => 4, "unionized" => true, "wage" => 2200, "hours" => 45),
    Dict("code" => "RHEL", "name" => "Rhenus Logistics", "type" => "TRUCKING", "country" => "DE",
         "safety" => 4, "unionized" => true, "wage" => 2100, "hours" => 45),
    Dict("code" => "EDLS", "name" => "Eddie Stobart", "type" => "TRUCKING", "country" => "GB",
         "safety" => 4, "unionized" => false, "wage" => 1800, "hours" => 48),
    # Air cargo
    Dict("code" => "LHCG", "name" => "Lufthansa Cargo", "type" => "AIRLINE", "country" => "DE",
         "safety" => 5, "unionized" => true, "wage" => 3500, "hours" => 40),
]

const CARBON_FACTORS = Dict(
    "MARITIME" => 0.015,
    "RAIL" => 0.025,
    "ROAD" => 0.100,
    "AIR" => 0.800,
)

const ROUTES = [
    # Maritime routes (Shanghai corridor)
    Dict("from" => "CNSHA", "to" => "SGSIN", "mode" => "MARITIME", "km" => 3800, "hours" => 120, "carriers" => ["MAEU", "COSU", "CMDU"]),
    Dict("from" => "SGSIN", "to" => "EGSUZ", "mode" => "MARITIME", "km" => 8500, "hours" => 288, "carriers" => ["MAEU", "COSU", "CMDU", "MSCU"]),
    Dict("from" => "EGSUZ", "to" => "NLRTM", "mode" => "MARITIME", "km" => 5200, "hours" => 168, "carriers" => ["MAEU", "CMDU", "MSCU"]),
    Dict("from" => "EGSUZ", "to" => "DEHAM", "mode" => "MARITIME", "km" => 5800, "hours" => 192, "carriers" => ["MAEU", "MSCU"]),
    Dict("from" => "CNSHA", "to" => "NLRTM", "mode" => "MARITIME", "km" => 19500, "hours" => 672, "carriers" => ["MAEU", "CMDU", "COSU"]),
    # Rail routes (Europe)
    Dict("from" => "NLRTM", "to" => "DEDUI", "mode" => "RAIL", "km" => 220, "hours" => 6, "carriers" => ["DBCG"]),
    Dict("from" => "DEDUI", "to" => "PLWAW", "mode" => "RAIL", "km" => 900, "hours" => 18, "carriers" => ["DBCG", "PKPC"]),
    Dict("from" => "PLWAW", "to" => "CNSHA", "mode" => "RAIL", "km" => 9000, "hours" => 336, "carriers" => ["PKPC"]),
    Dict("from" => "DEHAM", "to" => "DEDUI", "mode" => "RAIL", "km" => 350, "hours" => 8, "carriers" => ["DBCG"]),
    Dict("from" => "NLRTM", "to" => "BEANR", "mode" => "RAIL", "km" => 100, "hours" => 3, "carriers" => ["DBCG", "SNCF"]),
    # Road routes (last mile)
    Dict("from" => "NLRTM", "to" => "GBLON", "mode" => "ROAD", "km" => 450, "hours" => 10, "carriers" => ["DFDS", "RHEL"]),
    Dict("from" => "GBFXT", "to" => "GBLON", "mode" => "ROAD", "km" => 130, "hours" => 3, "carriers" => ["EDLS", "DFDS"]),
    Dict("from" => "DEDUI", "to" => "GBFXT", "mode" => "ROAD", "km" => 600, "hours" => 14, "carriers" => ["DFDS", "RHEL"]),
    Dict("from" => "BEANR", "to" => "GBFXT", "mode" => "ROAD", "km" => 350, "hours" => 8, "carriers" => ["DFDS"]),
    # Air routes
    Dict("from" => "CNSHA", "to" => "GBLHR", "mode" => "AIR", "km" => 9200, "hours" => 14, "carriers" => ["LHCG"]),
    Dict("from" => "GBLHR", "to" => "GBLON", "mode" => "ROAD", "km" => 30, "hours" => 1, "carriers" => ["EDLS"]),
]

# =============================================================================
# EDGE GENERATION
# =============================================================================

function generate_edge(route::Dict, carrier::Dict)::Dict
    mode = route["mode"]

    # Base cost calculation (USD)
    base_cost = if mode == "MARITIME"
        route["km"] * 0.5 + rand() * 2000 + 1000
    elseif mode == "RAIL"
        route["km"] * 0.8 + rand() * 1000 + 500
    elseif mode == "ROAD"
        route["km"] * 1.2 + rand() * 300 + 200
    else  # AIR
        route["km"] * 3.0 + rand() * 3000 + 2000
    end

    variance = route["hours"] * 0.1
    transit_hours = route["hours"] + (rand() * 2 - 1) * variance

    Dict(
        "code" => "$(route["from"])-$(route["to"])-$(mode[1])-$(carrier["code"])",
        "from_node" => "transport_node:$(route["from"])",
        "to_node" => "transport_node:$(route["to"])",
        "carrier" => "carrier:$(carrier["code"])",
        "mode" => mode,
        "distance_km" => route["km"],
        "base_cost_usd" => round(base_cost, digits=2),
        "cost_per_kg_usd" => round(base_cost / 10000 * 0.01, digits=4),
        "transit_hours" => round(transit_hours, digits=1),
        "carbon_kg_per_tonne_km" => CARBON_FACTORS[mode],
        "frequency" => mode in ["ROAD", "AIR"] ? "DAILY" : "WEEKLY",
        "active" => true,
    )
end

# =============================================================================
# DATABASE SEEDING
# =============================================================================

struct SurrealDBSeeder
    url::String
    user::String
    password::String
end

function query(seeder::SurrealDBSeeder, sql::String)
    headers = [
        "Content-Type" => "application/text",
        "Accept" => "application/json",
        "NS" => "veds",
        "DB" => "production",
    ]

    resp = HTTP.post(
        "$(seeder.url)/sql",
        headers,
        sql;
        basic_authorization=(seeder.user, seeder.password),
        connect_timeout=30,
        readtimeout=30,
    )

    JSON3.read(String(resp.body))
end

function seed_countries!(seeder::SurrealDBSeeder)
    println("Seeding countries...")
    for (code, data) in COUNTRIES
        sql = """
        CREATE country:$code SET
            code = '$code',
            name = '$(data["name"])',
            min_wage_cents_hourly = $(data["min_wage_cents"]),
            max_weekly_hours = $(data["max_hours"]),
            region = '$(data["region"])',
            currency = 'USD';
        """
        query(seeder, sql)
    end
    println("  Created $(length(COUNTRIES)) countries")
end

function seed_ports!(seeder::SurrealDBSeeder)
    println("Seeding ports...")
    for port in PORTS
        modes_json = JSON3.write(port["modes"])
        sql = """
        CREATE port:$(port["unlocode"]) SET
            unlocode = '$(port["unlocode"])',
            name = '$(port["name"])',
            country = country:$(port["country"]),
            location = { type: 'Point', coordinates: [$(port["lon"]), $(port["lat"])] },
            timezone = 'UTC',
            port_type = '$(port["type"])',
            modes = $modes_json,
            avg_dwell_hours = $(port["dwell_hours"]);
        """
        query(seeder, sql)
    end
    println("  Created $(length(PORTS)) ports")
end

function seed_carriers!(seeder::SurrealDBSeeder)
    println("Seeding carriers...")
    for carrier in CARRIERS
        unionized = carrier["unionized"] ? "true" : "false"
        sql = """
        CREATE carrier:$(carrier["code"]) SET
            code = '$(carrier["code"])',
            name = '$(carrier["name"])',
            carrier_type = '$(carrier["type"])',
            country = country:$(carrier["country"]),
            safety_rating = $(carrier["safety"]),
            unionized = $unionized,
            avg_wage_cents_hourly = $(carrier["wage"]),
            avg_weekly_hours = $(carrier["hours"]),
            sanctioned = false,
            active = true;
        """
        query(seeder, sql)
    end
    println("  Created $(length(CARRIERS)) carriers")
end

function seed_transport_nodes!(seeder::SurrealDBSeeder)
    println("Seeding transport nodes...")
    for port in PORTS
        modes_json = JSON3.write(port["modes"])
        sql = """
        CREATE transport_node:$(port["unlocode"]) SET
            code = '$(port["unlocode"])',
            port = port:$(port["unlocode"]),
            node_type = 'HUB',
            modes = $modes_json,
            active = true;
        """
        query(seeder, sql)
    end
    println("  Created $(length(PORTS)) transport nodes")
end

function seed_transport_edges!(seeder::SurrealDBSeeder)
    println("Seeding transport edges...")
    carrier_map = Dict(c["code"] => c for c in CARRIERS)
    edge_count = 0

    for route in ROUTES
        for carrier_code in route["carriers"]
            edge = generate_edge(route, carrier_map[carrier_code])
            sql = """
            CREATE transport_edge SET
                code = '$(edge["code"])',
                from_node = transport_node:$(route["from"]),
                to_node = transport_node:$(route["to"]),
                carrier = carrier:$carrier_code,
                mode = '$(edge["mode"])',
                distance_km = $(edge["distance_km"]),
                base_cost_usd = $(edge["base_cost_usd"]),
                cost_per_kg_usd = $(edge["cost_per_kg_usd"]),
                transit_hours = $(edge["transit_hours"]),
                carbon_kg_per_tonne_km = $(edge["carbon_kg_per_tonne_km"]),
                frequency = '$(edge["frequency"])',
                active = true;
            """
            query(seeder, sql)
            edge_count += 1
        end
    end

    println("  Created $edge_count transport edges")
end

function seed_cargo_types!(seeder::SurrealDBSeeder)
    println("Seeding cargo types...")
    cargo_types = [
        Dict("code" => "GEN", "name" => "General Cargo", "hazmat" => nothing, "temp" => false),
        Dict("code" => "REF", "name" => "Refrigerated", "hazmat" => nothing, "temp" => true, "min_c" => -25, "max_c" => 5),
        Dict("code" => "HAZ1", "name" => "Explosives", "hazmat" => "Class 1", "temp" => false),
        Dict("code" => "HAZ3", "name" => "Flammable Liquids", "hazmat" => "Class 3", "temp" => false),
        Dict("code" => "HVY", "name" => "Heavy Machinery", "hazmat" => nothing, "temp" => false),
    ]

    for ct in cargo_types
        temp_fields = if get(ct, "temp", false)
            ", temp_min_c = $(get(ct, "min_c", -20)), temp_max_c = $(get(ct, "max_c", 10))"
        else
            ""
        end
        hazmat = isnothing(ct["hazmat"]) ? "NONE" : "'$(ct["hazmat"])'"
        temp_str = ct["temp"] ? "true" : "false"

        sql = """
        CREATE cargo_type:$(ct["code"]) SET
            code = '$(ct["code"])',
            name = '$(ct["name"])',
            hazmat_class = $hazmat,
            temp_controlled = $temp_str$temp_fields;
        """
        query(seeder, sql)
    end
    println("  Created $(length(cargo_types)) cargo types")
end

function seed_all!(seeder::SurrealDBSeeder)
    seed_countries!(seeder)
    seed_ports!(seeder)
    seed_carriers!(seeder)
    seed_cargo_types!(seeder)
    seed_transport_nodes!(seeder)
    seed_transport_edges!(seeder)
end

# =============================================================================
# DRAGONFLY SEEDER
# =============================================================================

struct DragonflySeeder
    conn::Redis.RedisConnection
end

function DragonflySeeder(url::String, password::Union{String, Nothing}=nothing)
    # Parse redis://host:port format
    m = match(r"redis://([^:]+):(\d+)", url)
    host = isnothing(m) ? "localhost" : m.captures[1]
    port = isnothing(m) ? 6379 : parse(Int, m.captures[2])

    conn = Redis.RedisConnection(; host=host, port=port, password=password)
    DragonflySeeder(conn)
end

function seed_constraints!(seeder::DragonflySeeder)
    println("Seeding constraint cache in Dragonfly...")

    # Minimum wages by country
    for (code, data) in COUNTRIES
        Redis.set(seeder.conn, "constraint:min_wage:$code", string(data["min_wage_cents"]))
    end

    # Maximum hours by region
    regions = Dict{String, Int}()
    for (code, data) in COUNTRIES
        region = data["region"]
        if !haskey(regions, region) || data["max_hours"] < regions[region]
            regions[region] = data["max_hours"]
        end
    end

    for (region, hours) in regions
        Redis.set(seeder.conn, "constraint:max_hours:$region", string(hours))
    end

    # Default carbon budget
    Redis.set(seeder.conn, "constraint:carbon_budget:default", "5000")

    println("  Set $(length(COUNTRIES)) wage constraints")
    println("  Set $(length(regions)) hour constraints")
end

function seed_all!(seeder::DragonflySeeder)
    seed_constraints!(seeder)
end

# =============================================================================
# MAIN
# =============================================================================

function parse_commandline()
    s = ArgParseSettings(description="Seed VEDS with synthetic data")

    @add_arg_table! s begin
        "--surrealdb-url"
            help = "SurrealDB URL"
            default = "http://localhost:8000"
        "--surrealdb-user"
            help = "SurrealDB username"
            default = "root"
        "--surrealdb-pass"
            help = "SurrealDB password"
            default = "veds_dev_password"
        "--dragonfly-url"
            help = "Dragonfly URL"
            default = "redis://localhost:6379"
        "--dragonfly-pass"
            help = "Dragonfly password"
            default = nothing
    end

    parse_args(s)
end

function main()
    args = parse_commandline()

    println("=" ^ 60)
    println("VEDS Synthetic Data Generator (Julia)")
    println("=" ^ 60)
    println()

    println("Seeding SurrealDB...")
    surreal = SurrealDBSeeder(args["surrealdb-url"], args["surrealdb-user"], args["surrealdb-pass"])
    try
        seed_all!(surreal)
    catch e
        println("Warning: SurrealDB seeding failed: $e")
        println("Make sure SurrealDB is running and the schema is loaded.")
    end

    println()
    println("Seeding Dragonfly...")
    try
        dragonfly = DragonflySeeder(args["dragonfly-url"], args["dragonfly-pass"])
        seed_all!(dragonfly)
    catch e
        println("Warning: Dragonfly seeding failed: $e")
        println("Make sure Dragonfly is running.")
    end

    println()
    println("=" ^ 60)
    println("Data seeding complete!")
    println("=" ^ 60)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
