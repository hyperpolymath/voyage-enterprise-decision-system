# SPDX-License-Identifier: MPL-2.0
module VEDSViz

using Dates, Colors, Graphs, StaticArrays, Statistics
using CairoMakie, GeoMakie, GraphMakie, WGLMakie
using Genie, HTTP, JSON3, StructTypes, LibPQ, Redis

include("components/GeoMap.jl")
include("components/ParetoPlot.jl")
include("components/ConstraintDash.jl")
include("components/RealTimeTracker.jl")

using .GeoMap, .ParetoPlot, .ConstraintDash, .RealTimeTracker

const MODE_COLORS = Dict{Symbol, Colorant}(
    :maritime => colorant"#1E88E5",
    :rail     => colorant"#43A047",
    :road     => colorant"#FB8C00",
    :air      => colorant"#8E24AA",
)

struct Segment
    id::String
    origin_lat::Float64
    origin_lon::Float64
    dest_lat::Float64
    dest_lon::Float64
    mode::Symbol
    carrier::String
    cost_usd::Float64
    time_hours::Float64
    carbon_kg::Float64
    wage_cents::Int
    violations::Vector{Symbol}
end

Segment(id::String, olat::Real, olon::Real, dlat::Real, dlon::Real, mode::Symbol, carrier::String, cost::Real, hrs::Real, co2::Real, wage::Integer) =
    Segment(id, Float64(olat), Float64(olon), Float64(dlat), Float64(dlon), mode, carrier, Float64(cost), Float64(hrs), Float64(co2), Int(wage), Symbol[])

StructTypes.StructType(::Type{Segment}) = StructTypes.Struct()

struct Route
    id::String
    segments::Vector{Segment}
    total_cost::Float64
    total_time_hours::Float64
    total_carbon_kg::Float64
    pareto_rank::Int
end
StructTypes.StructType(::Type{Route}) = StructTypes.Struct()

struct ParetoPoint
    route_id::String
    cost_usd::Float64
    time_hours::Float64
    carbon_kg::Float64
    is_optimal::Bool
end
StructTypes.StructType(::Type{ParetoPoint}) = StructTypes.Struct()

struct VEDSApp
    port::Int
    host::String
    VEDSApp(; port::Int = 8080, host::String = "0.0.0.0") = new(port, host)
end

function start_server(app::VEDSApp = VEDSApp(); async::Bool = false)
    Genie.route("/health") do
        Genie.Renderer.Json.json(Dict("status" => "ok"))
    end
    Genie.up(app.port, app.host; async = async)
end

function haversine_distance(lat1::Real, lon1::Real, lat2::Real, lon2::Real)::Float64
    r_km = 6371.0
    dlat = deg2rad(Float64(lat2) - Float64(lat1))
    dlon = deg2rad(Float64(lon2) - Float64(lon1))
    a = sin(dlat / 2)^2 + cos(deg2rad(Float64(lat1))) * cos(deg2rad(Float64(lat2))) * sin(dlon / 2)^2
    return 2.0 * r_km * atan(sqrt(a), sqrt(1.0 - a))
end

function generate_sample_route()::Route
    segs = [
        Segment("seg-1", 31.2304, 121.4737, 22.3193, 114.1694, :maritime, "COSCO", 1200.0, 36.0, 420.0, 1800),
        Segment("seg-2", 22.3193, 114.1694, 1.3521, 103.8198, :maritime, "Maersk", 1800.0, 72.0, 610.0, 1950),
        Segment("seg-3", 1.3521, 103.8198, 51.9225, 4.4792, :maritime, "MSC", 4100.0, 360.0, 1450.0, 2100),
        Segment("seg-4", 51.9225, 4.4792, 53.5511, 9.9937, :rail, "DB Cargo", 650.0, 8.0, 95.0, 2400),
    ]
    return Route("route-001", segs, sum(s.cost_usd for s in segs), sum(s.time_hours for s in segs), sum(s.carbon_kg for s in segs), 1)
end

function render_route_map(routes::Vector{Route}; backend::Symbol = :cairo)
    fig, ax = GeoMap.create_world_map()
    for r in routes
        GeoMap.add_route_overlay(ax, r.segments)
    end
    return fig
end

function render_pareto_frontier(points::Vector{ParetoPoint}; objectives = (:cost, :time, :carbon))
    sols = [ParetoPlot.Solution(pt.route_id, Dict(:cost => pt.cost_usd, :time => pt.time_hours, :carbon => pt.carbon_kg), pt.is_optimal, Dict{Symbol, Any}()) for pt in points]
    return ParetoPlot.plot_pareto_2d(sols, objectives[1], objectives[2])
end

export Segment, Route, ParetoPoint, MODE_COLORS
export VEDSApp, start_server, haversine_distance, generate_sample_route, render_route_map, render_pareto_frontier

end # module VEDSViz
