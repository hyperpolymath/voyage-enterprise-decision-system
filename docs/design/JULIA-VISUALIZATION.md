# VEDS Julia Visualization Layer

## Overview

Julia provides the analytics and visualization backbone for VEDS. Its strengths:

1. **Performance** - Near-C speed for numerical computing
2. **Ecosystem** - Makie.jl for publication-quality graphics
3. **Interactivity** - Pluto.jl notebooks for exploration
4. **Web** - Genie.jl for dashboards
5. **Graphs** - Graphs.jl + GraphMakie.jl for network visualization

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        JULIA VISUALIZATION LAYER                                │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Presentation                                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │ Genie.jl        │    │ Pluto.jl        │    │ Static Export   │             │
│  │ Web Dashboard   │    │ Notebooks       │    │ PNG/SVG/PDF     │             │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘             │
│           │                      │                      │                       │
└───────────┼──────────────────────┼──────────────────────┼───────────────────────┘
            │                      │                      │
            └──────────────────────┼──────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────────┐
│                              Visualization                                      │
│                                  │                                              │
│  ┌─────────────────┐    ┌────────▼────────┐    ┌─────────────────┐             │
│  │ Network Viz     │    │ Makie.jl        │    │ Geospatial      │             │
│  │ GraphMakie.jl   │    │ (Core Engine)   │    │ GeoMakie.jl     │             │
│  │                 │    │                 │    │                 │             │
│  │ • Transport     │    │ • 2D plots      │    │ • World maps    │             │
│  │   graph layout  │    │ • 3D scenes     │    │ • Route overlay │             │
│  │ • Flow viz      │    │ • Animations    │    │ • Heatmaps      │             │
│  │ • Constraint    │    │ • Interactive   │    │ • Live tracking │             │
│  │   highlighting  │    │                 │    │                 │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────────┐
│                              Analytics                                          │
│                                  │                                              │
│  ┌─────────────────┐    ┌────────▼────────┐    ┌─────────────────┐             │
│  │ Time Series     │    │ DataFrames.jl   │    │ Optimization    │             │
│  │ TimeSeries.jl   │    │ (Data Layer)    │    │ JuMP.jl         │             │
│  │ StateSpaceModels│    │                 │    │                 │             │
│  │                 │    │ • ETL           │    │ • Pareto        │             │
│  │ • Demand        │    │ • Aggregation   │    │   analysis      │             │
│  │   forecasting   │    │ • Joins         │    │ • Sensitivity   │             │
│  │ • Trend         │    │                 │    │   analysis      │             │
│  │   analysis      │    │                 │    │                 │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                   │
┌──────────────────────────────────┼──────────────────────────────────────────────┐
│                              Data Connectors                                    │
│                                  │                                              │
│  ┌─────────────────┐    ┌────────▼────────┐    ┌─────────────────┐             │
│  │ XTDB Client     │    │ SurrealDB       │    │ Dragonfly       │             │
│  │ (HTTP/Transit)  │    │ Client          │    │ (Redis.jl)      │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Package Dependencies

```julia
# Project.toml
[deps]
# Core visualization
Makie = "ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a"
GLMakie = "e9467ef8-e4e7-5192-8a1a-b1aee30e663a"      # OpenGL backend
WGLMakie = "276b4fcb-3e11-5398-bf8b-a0c2d153d008"     # WebGL backend
CairoMakie = "13f3f980-e62b-5c42-98c6-ff1f3baf88f0"   # Static export

# Graph visualization
Graphs = "86223c79-3864-5bf0-83f7-82e725a168b6"
GraphMakie = "1ecd5474-83a3-4783-bb4f-06765db800d2"

# Geospatial
GeoMakie = "db073c08-6b98-4ee5-b6a4-5efafb3259c6"
GeoJSON = "61d90e0f-e114-555e-ac52-39dfb47f3c3b"
Proj = "c94c279d-25a6-4763-9509-64d165bea63e"

# Data handling
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
Tables = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"

# Time series
TimeSeries = "9e3dc215-6440-5c97-bce1-76c03772f85e"
StateSpaceModels = "99342f36-827c-5390-97c9-d7f9ee765c78"

# HTTP clients
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
Redis = "0cf705f9-a9e2-50d4-9215-a28820244b7b"

# Web framework
Genie = "c43c736e-a2d1-11e8-161f-af95117fbd1e"
Stipple = "4acbeb90-81a0-11ea-1966-bdaff6155698"

# Interactive notebooks
Pluto = "c3e4b0f8-55cb-11ea-2926-15256bba5781"

# Optimization
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"

# Statistics
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
```

---

## Visualization Components

### 1. Transport Network Graph

```julia
module NetworkViz

using Graphs, GraphMakie, GLMakie, Colors

"""
    TransportNetwork

In-memory representation of the transport network for visualization.
"""
struct TransportNetwork
    graph::SimpleDiGraph{Int}
    node_data::Dict{Int, NodeData}
    edge_data::Dict{Edge{Int}, EdgeData}
end

struct NodeData
    id::String
    name::String
    type::Symbol  # :hub, :terminal, :waypoint
    lat::Float64
    lon::Float64
    modes::Vector{Symbol}
end

struct EdgeData
    id::String
    mode::Symbol  # :maritime, :rail, :road, :air
    distance_km::Float64
    cost_usd::Float64
    carbon_kg::Float64
    transit_hours::Float64
    carrier::String
    constraint_status::Symbol  # :valid, :warning, :violation
end

"""
    visualize_network(network::TransportNetwork; layout=:geo)

Create an interactive visualization of the transport network.

# Arguments
- `network`: The transport network to visualize
- `layout`: Layout algorithm (:geo for geographic, :spring for force-directed)
"""
function visualize_network(network::TransportNetwork; layout=:geo)
    fig = Figure(size=(1400, 900), fontsize=12)

    # Main network view
    ax = Axis(fig[1, 1],
              title="VEDS Transport Network",
              aspect=DataAspect())

    # Node positions
    if layout == :geo
        positions = [Point2f(n.lon, n.lat) for n in values(network.node_data)]
    else
        positions = spring_layout(network.graph)
    end

    # Node colors by type
    node_colors = map(values(network.node_data)) do n
        n.type == :hub ? colorant"#2E86AB" :
        n.type == :terminal ? colorant"#A23B72" :
        colorant"#F18F01"
    end

    # Edge colors by mode
    edge_colors = map(edges(network.graph)) do e
        ed = network.edge_data[e]
        ed.mode == :maritime ? colorant"#1E88E5" :
        ed.mode == :rail ? colorant"#43A047" :
        ed.mode == :road ? colorant"#FB8C00" :
        colorant"#8E24AA"  # air
    end

    # Edge widths by volume (could be parameterized)
    edge_widths = [2.0 for _ in edges(network.graph)]

    # Draw network
    graphplot!(ax, network.graph,
        layout=positions,
        node_color=node_colors,
        node_size=15,
        edge_color=edge_colors,
        edge_width=edge_widths,
        nlabels=[n.name for n in values(network.node_data)],
        nlabels_fontsize=8
    )

    # Legend
    Legend(fig[1, 2],
        [MarkerElement(color=c, marker=:circle) for c in
            [colorant"#2E86AB", colorant"#A23B72", colorant"#F18F01"]],
        ["Hub", "Terminal", "Waypoint"],
        "Node Types"
    )

    Legend(fig[2, 2],
        [LineElement(color=c) for c in
            [colorant"#1E88E5", colorant"#43A047", colorant"#FB8C00", colorant"#8E24AA"]],
        ["Maritime", "Rail", "Road", "Air"],
        "Transport Modes"
    )

    fig
end

"""
    highlight_route(fig, network, route_segments)

Overlay a specific route on the network visualization.
"""
function highlight_route!(ax, network::TransportNetwork, route_segments::Vector{EdgeData})
    # Draw route with thick highlighted lines
    for seg in route_segments
        edge = findfirst(e -> network.edge_data[e].id == seg.id, edges(network.graph))
        if !isnothing(edge)
            from_pos = Point2f(network.node_data[src(edge)].lon,
                              network.node_data[src(edge)].lat)
            to_pos = Point2f(network.node_data[dst(edge)].lon,
                            network.node_data[dst(edge)].lat)

            lines!(ax, [from_pos, to_pos],
                   color=:red,
                   linewidth=4,
                   linestyle=:dash)
        end
    end
end

"""
    animate_shipment(network, positions_over_time)

Create an animation of a shipment moving through the network.
"""
function animate_shipment(network::TransportNetwork,
                          positions::Vector{Tuple{Float64, Float64, DateTime}})
    fig = Figure(size=(1200, 800))
    ax = Axis(fig[1, 1])

    # Draw base network
    # ...

    # Animated shipment marker
    shipment_pos = Observable(Point2f(positions[1][1], positions[1][2]))
    scatter!(ax, shipment_pos, marker=:star5, markersize=20, color=:red)

    # Animation
    record(fig, "shipment_animation.mp4", 1:length(positions); framerate=30) do i
        shipment_pos[] = Point2f(positions[i][1], positions[i][2])
    end
end

end # module
```

### 2. Geospatial Route Mapping

```julia
module GeoViz

using GeoMakie, CairoMakie, GeoJSON, Downloads

"""
    plot_world_routes(routes::Vector{Route})

Plot routes on a world map with proper projections.
"""
function plot_world_routes(routes::Vector{Route}; projection="+proj=robin")
    fig = Figure(size=(1600, 900))
    ga = GeoAxis(fig[1, 1],
                 dest=projection,
                 title="VEDS Global Routes")

    # Coastlines
    lines!(ga, GeoMakie.coastlines(), color=:gray70, linewidth=0.5)

    # Plot each route
    for (i, route) in enumerate(routes)
        coords = route_to_coordinates(route)

        # Color by carbon efficiency
        carbon_color = carbon_to_color(route.total_carbon_kg)

        lines!(ga, coords,
               color=carbon_color,
               linewidth=2,
               label="Route $(route.id)")

        # Mark origin and destination
        scatter!(ga, [coords[1]], marker=:circle, markersize=15, color=:green)
        scatter!(ga, [coords[end]], marker=:star5, markersize=15, color=:red)
    end

    # Colorbar for carbon
    Colorbar(fig[1, 2], limits=(0, 10000),
             colormap=:viridis,
             label="Carbon (kg CO2)")

    fig
end

"""
    heatmap_traffic(positions::DataFrame, time_window::Tuple{DateTime, DateTime})

Create a heatmap of shipping traffic density.
"""
function heatmap_traffic(positions::DataFrame; resolution=1.0)
    fig = Figure(size=(1400, 800))
    ga = GeoAxis(fig[1, 1], dest="+proj=robin")

    # Bin positions into grid
    lons = range(-180, 180, step=resolution)
    lats = range(-90, 90, step=resolution)

    density = zeros(length(lons), length(lats))
    for row in eachrow(positions)
        lon_idx = searchsortedfirst(lons, row.lon)
        lat_idx = searchsortedfirst(lats, row.lat)
        if 1 <= lon_idx <= length(lons) && 1 <= lat_idx <= length(lats)
            density[lon_idx, lat_idx] += 1
        end
    end

    # Plot heatmap
    heatmap!(ga, lons, lats, log1p.(density'),
             colormap=:thermal,
             alpha=0.7)

    # Coastlines on top
    lines!(ga, GeoMakie.coastlines(), color=:white, linewidth=0.5)

    Colorbar(fig[1, 2], limits=(0, maximum(log1p.(density))),
             colormap=:thermal,
             label="Log Traffic Density")

    fig
end

"""
    realtime_tracking_map(shipment_ids::Vector{String})

Create a live-updating map of active shipments.
Returns an Observable figure that updates with new positions.
"""
function realtime_tracking_map(dragonfly_conn, shipment_ids::Vector{String})
    fig = Figure(size=(1200, 800))
    ga = GeoAxis(fig[1, 1], dest="+proj=merc")

    lines!(ga, GeoMakie.coastlines(), color=:gray70)

    # Observable positions for each shipment
    positions = Dict(
        id => Observable(Point2f(0, 0))
        for id in shipment_ids
    )

    # Plot markers
    for (id, pos) in positions
        scatter!(ga, pos, marker=:circle, markersize=10, color=:red)
    end

    # Update function (called from timer)
    function update_positions!()
        for id in shipment_ids
            pos = get_position_from_dragonfly(dragonfly_conn, id)
            if !isnothing(pos)
                positions[id][] = Point2f(pos.lon, pos.lat)
            end
        end
    end

    # Return figure and update function
    fig, update_positions!
end

end # module
```

### 3. Analytics Dashboards

```julia
module AnalyticsDashboard

using Genie, Stipple, StipplePlotly
using DataFrames, Statistics

"""
Dashboard for VEDS analytics using Genie.jl + Stipple
"""

# Reactive model for dashboard state
@reactive mutable struct DashboardModel <: ReactiveModel
    # Filters
    date_range::R{Tuple{Date, Date}} = (today() - Day(30), today())
    selected_modes::R{Vector{Symbol}} = [:maritime, :rail, :road, :air]
    selected_corridor::R{String} = "all"

    # KPIs
    total_shipments::R{Int} = 0
    avg_cost::R{Float64} = 0.0
    avg_carbon::R{Float64} = 0.0
    on_time_rate::R{Float64} = 0.0

    # Chart data
    cost_trend::R{Vector{PlotData}} = []
    carbon_by_mode::R{Vector{PlotData}} = []
    route_efficiency::R{Vector{PlotData}} = []
    constraint_violations::R{Vector{PlotData}} = []
end

function handlers(model)
    on(model.date_range) do range
        refresh_data!(model, range)
    end

    on(model.selected_modes) do modes
        filter_by_modes!(model, modes)
    end
end

function refresh_data!(model, date_range)
    # Fetch from XTDB/SurrealDB
    shipments = fetch_shipments(date_range...)

    # Update KPIs
    model.total_shipments[] = nrow(shipments)
    model.avg_cost[] = mean(shipments.cost_usd)
    model.avg_carbon[] = mean(shipments.carbon_kg)
    model.on_time_rate[] = count(shipments.on_time) / nrow(shipments)

    # Update charts
    model.cost_trend[] = build_cost_trend(shipments)
    model.carbon_by_mode[] = build_carbon_by_mode(shipments)
end

# HTML template
function ui()
    page(
        model,
        class="container",
        [
            heading("VEDS Analytics Dashboard"),

            row([
                cell(class="col-md-3", [
                    card([
                        card_header("Total Shipments"),
                        card_body([
                            h2("{{ total_shipments }}")
                        ])
                    ])
                ]),
                cell(class="col-md-3", [
                    card([
                        card_header("Avg Cost (USD)"),
                        card_body([
                            h2("\${{ avg_cost.toFixed(2) }}")
                        ])
                    ])
                ]),
                cell(class="col-md-3", [
                    card([
                        card_header("Avg Carbon (kg)"),
                        card_body([
                            h2("{{ avg_carbon.toFixed(1) }} kg")
                        ])
                    ])
                ]),
                cell(class="col-md-3", [
                    card([
                        card_header("On-Time Rate"),
                        card_body([
                            h2("{{ (on_time_rate * 100).toFixed(1) }}%")
                        ])
                    ])
                ])
            ]),

            row([
                cell(class="col-md-6", [
                    card([
                        card_header("Cost Trend"),
                        card_body([
                            plot(:cost_trend)
                        ])
                    ])
                ]),
                cell(class="col-md-6", [
                    card([
                        card_header("Carbon by Mode"),
                        card_body([
                            plot(:carbon_by_mode)
                        ])
                    ])
                ])
            ])
        ]
    )
end

# Genie route
route("/dashboard") do
    model = DashboardModel |> init |> handlers
    html(ui(), model)
end

end # module
```

### 4. Constraint Visualization

```julia
module ConstraintViz

using Makie, Colors

"""
Visualize constraint satisfaction across routes.
"""

"""
    constraint_heatmap(routes::Vector{Route}, constraints::Vector{Constraint})

Create a heatmap showing constraint satisfaction across routes.
"""
function constraint_heatmap(routes::Vector{Route}, constraints::Vector{Constraint})
    fig = Figure(size=(1200, 800))
    ax = Axis(fig[1, 1],
              title="Constraint Satisfaction Matrix",
              xlabel="Constraints",
              ylabel="Routes")

    # Build satisfaction matrix
    n_routes = length(routes)
    n_constraints = length(constraints)
    satisfaction = zeros(n_routes, n_constraints)

    for (i, route) in enumerate(routes)
        for (j, constraint) in enumerate(constraints)
            eval_result = evaluate_constraint(route, constraint)
            satisfaction[i, j] = eval_result.score
        end
    end

    # Heatmap
    hm = heatmap!(ax, satisfaction,
                  colormap=:RdYlGn,  # Red=fail, Yellow=marginal, Green=pass
                  colorrange=(0, 1))

    # Labels
    ax.xticks = (1:n_constraints, [c.name for c in constraints])
    ax.yticks = (1:n_routes, [r.id[1:8] for r in routes])

    Colorbar(fig[1, 2], hm, label="Satisfaction Score")

    fig
end

"""
    pareto_frontier(routes::Vector{Route}; objectives=[:cost, :carbon])

Visualize the Pareto frontier for multi-objective optimization.
"""
function pareto_frontier(routes::Vector{Route};
                         obj_x=:cost_usd,
                         obj_y=:carbon_kg)
    fig = Figure(size=(800, 600))
    ax = Axis(fig[1, 1],
              title="Pareto Frontier: Cost vs Carbon",
              xlabel="Cost (USD)",
              ylabel="Carbon (kg CO2)")

    # Extract objective values
    x_vals = [getproperty(r, obj_x) for r in routes]
    y_vals = [getproperty(r, obj_y) for r in routes]

    # Identify Pareto optimal points
    pareto_mask = compute_pareto_mask(x_vals, y_vals)

    # Plot all points
    scatter!(ax, x_vals, y_vals,
             color=[p ? :blue : :gray for p in pareto_mask],
             markersize=[p ? 15 : 8 for p in pareto_mask],
             label="Routes")

    # Draw Pareto frontier line
    pareto_x = x_vals[pareto_mask]
    pareto_y = y_vals[pareto_mask]
    order = sortperm(pareto_x)
    lines!(ax, pareto_x[order], pareto_y[order],
           color=:red,
           linewidth=2,
           linestyle=:dash,
           label="Pareto Frontier")

    axislegend(ax)

    fig
end

"""
    labor_compliance_radar(carrier::Carrier)

Radar chart showing labor compliance metrics for a carrier.
"""
function labor_compliance_radar(carrier::Carrier)
    fig = Figure(size=(600, 600))
    ax = PolarAxis(fig[1, 1], title="Labor Compliance: $(carrier.name)")

    # Metrics (normalized 0-1)
    metrics = [
        ("Wage", min(1.0, carrier.avg_wage / (2 * country_min_wage(carrier.country)))),
        ("Hours", 1.0 - min(1.0, (carrier.avg_hours - 40) / 20)),
        ("Safety", carrier.safety_rating / 5.0),
        ("Union", carrier.unionized ? 1.0 : 0.5),
        ("Benefits", carrier.benefits_score)
    ]

    angles = range(0, 2π, length=length(metrics)+1)[1:end-1]
    values = [m[2] for m in metrics]

    # Draw radar
    poly!(ax, Point2f.(angles .* cos.(angles), angles .* sin.(angles) .* values),
          color=(:blue, 0.3),
          strokecolor=:blue,
          strokewidth=2)

    # Labels
    for (i, (name, _)) in enumerate(metrics)
        text!(ax, angles[i], 1.1, text=name, align=(:center, :center))
    end

    fig
end

end # module
```

---

## Data Connectors

### XTDB Connector

```julia
module XTDBClient

using HTTP, JSON3

struct XTDBConnection
    url::String
    timeout::Int
end

XTDBConnection(url::String) = XTDBConnection(url, 30)

"""
    query(conn::XTDBConnection, datalog::String)

Execute a Datalog query against XTDB.
"""
function query(conn::XTDBConnection, datalog::String;
               valid_time=nothing, tx_time=nothing)
    body = Dict("query" => datalog)

    if !isnothing(valid_time)
        body["valid-time"] = string(valid_time)
    end
    if !isnothing(tx_time)
        body["tx-time"] = string(tx_time)
    end

    response = HTTP.post(
        "$(conn.url)/_xtdb/query",
        ["Content-Type" => "application/json"],
        JSON3.write(body);
        readtimeout=conn.timeout
    )

    JSON3.read(response.body)
end

"""
    fetch_decisions(conn, date_range)

Fetch routing decisions for analytics.
"""
function fetch_decisions(conn::XTDBConnection, start_date::Date, end_date::Date)
    query_str = """
    {:find [?id ?route ?cost ?carbon ?time ?verified]
     :where [[?d :decision/id ?id]
             [?d :decision/route-id ?route]
             [?d :decision/cost-usd ?cost]
             [?d :decision/carbon-kg ?carbon]
             [?d :decision/time-hours ?time]
             [?d :decision/verified? ?verified]]
     :order-by [[?time :desc]]}
    """

    results = query(conn, query_str)

    # Convert to DataFrame
    DataFrame(
        id = [r[1] for r in results],
        route_id = [r[2] for r in results],
        cost_usd = [r[3] for r in results],
        carbon_kg = [r[4] for r in results],
        time_hours = [r[5] for r in results],
        verified = [r[6] for r in results]
    )
end

end # module
```

### SurrealDB Connector

```julia
module SurrealDBClient

using HTTP, JSON3

struct SurrealConnection
    url::String
    namespace::String
    database::String
    auth_token::String
end

"""
    query(conn::SurrealConnection, surql::String)

Execute a SurrealQL query.
"""
function query(conn::SurrealConnection, surql::String)
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "Authorization" => "Bearer $(conn.auth_token)",
        "NS" => conn.namespace,
        "DB" => conn.database
    ]

    response = HTTP.post(
        "$(conn.url)/sql",
        headers,
        surql
    )

    JSON3.read(response.body)
end

"""
    fetch_transport_graph(conn)

Load the transport network for visualization.
"""
function fetch_transport_graph(conn::SurrealConnection)
    nodes_query = "SELECT * FROM transport_node FETCH port"
    edges_query = "SELECT * FROM transport_edge FETCH carrier"

    nodes = query(conn, nodes_query)
    edges = query(conn, edges_query)

    # Build graph structure
    build_transport_network(nodes, edges)
end

end # module
```

---

## Pluto Notebook Templates

```julia
### A Pluto.jl notebook ###
# v0.19.x

using Markdown
using InteractiveUtils

# ╔═╡ Cell 1 - Setup
begin
    using Pkg
    Pkg.activate(".")
    using VEDS
    using DataFrames, Statistics
    using CairoMakie
end

# ╔═╡ Cell 2 - Load Data
begin
    xtdb = XTDBClient.XTDBConnection("http://localhost:3000")
    decisions = XTDBClient.fetch_decisions(xtdb, Date(2025, 1, 1), today())
    @info "Loaded $(nrow(decisions)) decisions"
end

# ╔═╡ Cell 3 - Cost Analysis
begin
    fig = Figure(size=(800, 400))
    ax = Axis(fig[1, 1], title="Cost Distribution", xlabel="Cost (USD)")
    hist!(ax, decisions.cost_usd, bins=50)
    fig
end

# ╔═╡ Cell 4 - Carbon vs Cost Pareto
ConstraintViz.pareto_frontier(decisions, obj_x=:cost_usd, obj_y=:carbon_kg)

# ╔═╡ Cell 5 - Interactive Network
begin
    surrealdb = SurrealDBClient.SurrealConnection(
        "http://localhost:8000",
        "veds", "production",
        ENV["SURREAL_TOKEN"]
    )
    network = SurrealDBClient.fetch_transport_graph(surrealdb)
    NetworkViz.visualize_network(network)
end
```

---

## Performance Considerations

| Operation | Expected Time | Notes |
|-----------|--------------|-------|
| Load transport graph (50K edges) | ~2s | One-time at startup |
| Render network visualization | ~100ms | With GLMakie |
| Update real-time positions (1000 ships) | ~10ms | Observable updates |
| Generate static report | ~500ms | CairoMakie export |
| Pareto frontier (1000 routes) | ~50ms | Pure Julia |
| Dashboard page load | ~200ms | Genie + Stipple |

---

## Deployment

### Docker Container

```dockerfile
FROM julia:1.10

WORKDIR /app
COPY Project.toml Manifest.toml ./
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

COPY src/ ./src/

EXPOSE 8080

CMD ["julia", "--project=.", "-e", "using VEDS; VEDS.start_dashboard(8080)"]
```

### Systemd Service

```ini
[Unit]
Description=VEDS Julia Analytics
After=network.target

[Service]
Type=simple
User=veds
WorkingDirectory=/opt/veds/julia-viz
ExecStart=/usr/local/julia/bin/julia --project=. -e "using VEDS; VEDS.start_dashboard(8080)"
Restart=always

[Install]
WantedBy=multi-user.target
```
