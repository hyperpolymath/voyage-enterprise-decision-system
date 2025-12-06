# VEDS Data Flow Diagram - Level 2 (Sub-processes)

## Overview

Level 2 decomposes each Level 1 process into its constituent sub-processes.
This document covers all 8 major processes.

---

## 1.0 DATA INGESTION - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          1.0 DATA INGESTION                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

  TRANSPORT APIs
       │
       │ raw API responses (JSON, XML, EDI)
       ▼
┌─────────────────┐
│ 1.1 API         │
│ CONNECTORS      │──────────┐
│                 │          │
│ • Maritime      │          │ connection errors, rate limits
│ • Rail          │          │
│ • Road          │          ▼
│ • Air           │    ┌─────────────────┐
└────────┬────────┘    │ 1.5 ERROR       │
         │             │ HANDLER         │
         │ raw data    │                 │──────► alerting, retry queue
         ▼             └─────────────────┘
┌─────────────────┐           ▲
│ 1.2 SCHEMA      │           │ validation errors
│ NORMALIZER      │───────────┘
│                 │
│ • EDI → JSON    │
│ • XML → JSON    │
│ • Field mapping │
└────────┬────────┘
         │
         │ normalized records
         ▼
┌─────────────────┐
│ 1.3 DATA        │
│ VALIDATOR       │
│                 │
│ • Type checks   │
│ • Range checks  │
│ • Referential   │
│   integrity     │
└────────┬────────┘
         │
         │ validated records
         ▼
┌─────────────────┐         ┌─────────────────┐
│ 1.4 GRAPH       │────────►│ DS2: SurrealDB  │
│ BUILDER         │         │ (transport net) │
│                 │         └─────────────────┘
│ • Create nodes  │
│ • Create edges  │         ┌─────────────────┐
│ • Update costs  │────────►│ DS3: Dragonfly  │
└─────────────────┘         │ (rate cache)    │
                            └─────────────────┘
```

### Sub-process Details

| ID | Name | Input | Output | Technology |
|----|------|-------|--------|------------|
| 1.1 | API Connectors | External API calls | Raw responses | Elixir HTTPoison, Tesla |
| 1.2 | Schema Normalizer | Raw JSON/XML/EDI | Normalized JSON | Elixir, custom parsers |
| 1.3 | Data Validator | Normalized records | Validated records | Elixir Ecto changesets |
| 1.4 | Graph Builder | Validated records | Graph mutations | SurrealDB client |
| 1.5 | Error Handler | All error types | Alerts, retries | Elixir Supervisor |

---

## 2.0 CONSTRAINT ENGINE - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        2.0 CONSTRAINT ENGINE                                    │
└─────────────────────────────────────────────────────────────────────────────────┘

  POLICY ADMIN
       │
       │ constraint definitions (DSL, UI)
       ▼
┌─────────────────┐
│ 2.1 CONSTRAINT  │
│ PARSER          │
│                 │
│ • DSL → AST     │
│ • UI → AST      │
│ • Validation    │
└────────┬────────┘
         │
         │ AST representation
         ▼
┌─────────────────┐
│ 2.2 DATALOG     │
│ COMPILER        │
│                 │
│ • AST → Datalog │
│ • Rule gen      │
│ • Optimization  │
└────────┬────────┘
         │                              ┌─────────────────┐
         │ Datalog rules               │ DS1: XTDB       │
         ▼                              │                 │
┌─────────────────┐                    │ • Rule storage  │
│ 2.3 RULE        │◄──────────────────►│ • Bitemporal    │
│ STORE           │                    │ • History       │
│                 │                    └─────────────────┘
│ • Version ctrl  │
│ • Activation    │
│ • Rollback      │
└────────┬────────┘
         │
         │ active ruleset
         ▼
┌─────────────────┐
│ 2.4 EVALUATION  │◄─────────── route candidates (from 3.0)
│ ENGINE          │
│                 │
│ • Query exec    │
│ • Fact matching │
│ • Result agg    │
└────────┬────────┘
         │
         │ constraint results (pass/fail + details)
         ▼
       TO 3.0 ROUTE OPTIMIZER
```

### Datalog Rule Examples

```clojure
;; 2.2 compiles this DSL:
;;   "wage >= country_minimum"
;; Into this Datalog:

[:find ?segment ?status
 :in $ ?route-id
 :where
 [?route :route/id ?route-id]
 [?route :route/segments ?segment]
 [?segment :segment/hourly-wage ?wage]
 [?segment :segment/country ?country]
 [?country :country/minimum-wage ?min]
 [(>= ?wage ?min)]
 [(ground :pass) ?status]]

;; Carbon budget constraint
[:find ?route ?total-carbon ?status
 :in $ ?route-id ?carbon-budget
 :where
 [?route :route/id ?route-id]
 [?route :route/segments ?seg]
 [?seg :segment/carbon-kg ?carbon]
 [(sum ?carbon) ?total-carbon]
 [(<= ?total-carbon ?carbon-budget)]
 [(ground :pass) ?status]]
```

---

## 3.0 ROUTE OPTIMIZER - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         3.0 ROUTE OPTIMIZER                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

  SHIPMENT REQUEST                    TRANSPORT GRAPH (from 1.0)
       │                                      │
       │ origin, dest, cargo, constraints     │ nodes, edges, costs
       ▼                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.1 GRAPH LOADER                             │
│                                                                 │
│   Load relevant subgraph from SurrealDB into memory            │
│   Prune unreachable nodes, filter by transport modes            │
└─────────────────────────────────────────────────────────────────┘
         │
         │ in-memory graph (petgraph)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.2 PATH FINDER                              │
│                                                                 │
│   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐    │
│   │ Dijkstra      │   │ A* Search     │   │ K-Shortest    │    │
│   │ (baseline)    │   │ (heuristic)   │   │ Paths (Yen)   │    │
│   └───────────────┘   └───────────────┘   └───────────────┘    │
│                                                                 │
│   Output: Top-K candidate paths (K=10 default)                  │
└─────────────────────────────────────────────────────────────────┘
         │
         │ candidate paths
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.3 MULTI-OBJECTIVE SCORER                   │
│                                                                 │
│   For each path, compute:                                       │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│   │ Cost ($) │ │ Time (h) │ │ Carbon   │ │ Labor    │          │
│   │          │ │          │ │ (kg CO2) │ │ Score    │          │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                 │
│   Pareto frontier identification                                │
└─────────────────────────────────────────────────────────────────┘
         │
         │ scored candidates
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.4 CONSTRAINT CHECKER                       │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │                    HTTP to 2.0                          │   │
│   │  POST /evaluate                                         │   │
│   │  { route: [...], constraints: ["wage", "carbon", ...] } │   │
│   └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│   Filter out routes that fail hard constraints                  │
│   Annotate routes with soft constraint scores                   │
└─────────────────────────────────────────────────────────────────┘
         │
         │ constraint-checked routes
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.5 PROOF GENERATOR                          │
│                                                                 │
│   For routes requiring formal verification:                     │
│   - Generate proof obligations                                  │
│   - Serialize to Ada/SPARK input format                         │
│   - Queue for 4.0 FORMAL VERIFIER                               │
└─────────────────────────────────────────────────────────────────┘
         │
         │ routes + proof obligations
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    3.6 ROUTE RANKER                             │
│                                                                 │
│   Apply user preferences:                                       │
│   - Weight: cost=0.4, time=0.3, carbon=0.2, labor=0.1           │
│   - Or: user-specified weights                                  │
│                                                                 │
│   Rank routes, return top 5 with explanations                   │
└─────────────────────────────────────────────────────────────────┘
         │
         │ ranked routes with explanations
         ▼
       TO 5.0 DECISION STORE
```

### Rust Structures

```rust
// 3.2 Path representation
pub struct CandidatePath {
    pub segments: Vec<Segment>,
    pub total_cost: Decimal,
    pub total_time: Duration,
    pub total_carbon_kg: f64,
    pub modes_used: HashSet<TransportMode>,
}

// 3.3 Multi-objective score
pub struct PathScore {
    pub cost_normalized: f64,      // 0.0 - 1.0
    pub time_normalized: f64,
    pub carbon_normalized: f64,
    pub labor_score: f64,
    pub pareto_rank: u32,          // 1 = Pareto optimal
}

// 3.5 Proof obligation
pub struct ProofObligation {
    pub route_id: Uuid,
    pub constraint_type: ConstraintType,
    pub property: String,          // e.g., "∀ segment, wage >= min_wage"
    pub context: serde_json::Value,
}
```

---

## 4.0 FORMAL VERIFIER - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        4.0 FORMAL VERIFIER                                      │
└─────────────────────────────────────────────────────────────────────────────────┘

  PROOF OBLIGATIONS (from 3.0)
       │
       │ route + properties to prove
       ▼
┌─────────────────┐
│ 4.1 OBLIGATION  │
│ PARSER          │
│                 │
│ • JSON → Ada    │
│ • Type checking │
│ • Preconditions │
└────────┬────────┘
         │
         │ Ada/SPARK proof context
         ▼
┌─────────────────┐
│ 4.2 SPARK       │
│ ANNOTATOR       │
│                 │
│ • Add contracts │
│ • Pre/Post cond │
│ • Loop inv      │
└────────┬────────┘
         │
         │ annotated SPARK code
         ▼
┌─────────────────┐
│ 4.3 PROOF       │
│ ENGINE          │
│                 │
│ • GNATprove     │
│ • Why3 backend  │
│ • Z3/CVC5 SMT   │
└────────┬────────┘
         │
         ├──────── PROVEN ────────┐
         │                        ▼
         │              ┌─────────────────┐
         │              │ 4.5 CERTIFICATE │
         │              │ GENERATOR       │
         │              │                 │
         │              │ • Proof cert    │
         │              │ • Timestamp     │
         │              │ • Signature     │
         │              └────────┬────────┘
         │                       │
         ├──────── UNPROVEN ─────┼───────┐
         │                       │       │
         ▼                       │       ▼
┌─────────────────┐              │  ┌─────────────────┐
│ 4.4 COUNTER-    │              │  │ 4.6 RESULT      │
│ EXAMPLE ANALYZER│              │  │ REPORTER        │
│                 │              │  │                 │
│ • Why failed    │              │  │ • JSON output   │
│ • Edge cases    │              │  │ • Audit trail   │
└────────┬────────┘              │  └────────┬────────┘
         │                       │           │
         │ failure analysis      │           │ verification result
         └───────────────────────┴───────────┘
                                             │
                                             ▼
                                   TO 5.0 DECISION STORE
```

### Ada/SPARK Example

```ada
-- 4.2 Annotated SPARK procedure
package Route_Verifier with SPARK_Mode is

   type Wage_Cents is range 0 .. 100_000_000;
   type Country_Code is new String (1 .. 2);

   function Minimum_Wage (Country : Country_Code) return Wage_Cents
     with Global => null,
          Post   => Minimum_Wage'Result >= 0;

   function Segment_Wage_Valid
     (Segment_Wage : Wage_Cents;
      Country      : Country_Code) return Boolean
   is (Segment_Wage >= Minimum_Wage (Country))
     with Global => null;

   procedure Verify_Route_Wages
     (Route   : Route_Type;
      Valid   : out Boolean)
     with Global  => null,
          Depends => (Valid => Route),
          Post    => (if Valid then
                        (for all S of Route.Segments =>
                           Segment_Wage_Valid (S.Wage, S.Country)));

end Route_Verifier;
```

---

## 5.0 DECISION STORE - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         5.0 DECISION STORE                                      │
└─────────────────────────────────────────────────────────────────────────────────┘

  DECISIONS (from 3.0, 4.0)
       │
       │ routes, proofs, scores
       ▼
┌─────────────────┐
│ 5.1 DECISION    │
│ RECORDER        │
│                 │
│ • Assign ID     │
│ • Timestamp     │
│ • Validate      │
└────────┬────────┘
         │
         ├────────────────────────────────────┐
         │                                    │
         ▼                                    ▼
┌─────────────────┐                  ┌─────────────────┐
│ 5.2 XTDB        │                  │ 5.3 SURREALDB   │
│ WRITER          │                  │ WRITER          │
│                 │                  │                 │
│ • Bitemporal    │                  │ • Graph update  │
│ • valid-time    │                  │ • Shipment doc  │
│ • tx-time       │                  │ • Relations     │
└────────┬────────┘                  └────────┬────────┘
         │                                    │
         ▼                                    ▼
   ┌───────────┐                        ┌───────────┐
   │   XTDB    │                        │ SurrealDB │
   └───────────┘                        └───────────┘
         │                                    │
         └────────────────┬───────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ 5.4 CACHE       │
                 │ INVALIDATOR     │
                 │                 │
                 │ • Clear stale   │
                 │ • Warm hot data │
                 └────────┬────────┘
                          │
                          ▼
                    ┌───────────┐
                    │ Dragonfly │
                    └───────────┘
```

### Bitemporal Storage Example

```clojure
;; 5.2 XTDB transaction
(xt/submit-tx node
  [[::xt/put
    {:xt/id :route/12345
     :route/id "12345"
     :route/origin "CNSHA"      ; Shanghai
     :route/destination "GBLHR" ; London Heathrow
     :route/segments [{:mode :maritime :from "CNSHA" :to "NLRTM"}
                      {:mode :rail :from "NLRTM" :to "DEHAM"}
                      {:mode :road :from "DEHAM" :to "GBLHR"}]
     :route/cost-usd 42000.00
     :route/carbon-kg 3200.0
     :route/computed-at #inst "2025-12-06T10:30:00Z"
     :route/verified? true
     :route/proof-cert "proof:abc123"}
    #inst "2025-12-06T10:30:00Z"  ; valid-time (when route is valid)
    #inst "2025-12-10T00:00:00Z"  ; valid-time end (rate expires)
   ]])

;; Query: What route would we have computed on Dec 7, using Dec 6 data?
(xt/q (xt/db node
             {:valid-time #inst "2025-12-07"
              :tx-time #inst "2025-12-06"})
  '{:find [?route ?cost]
    :where [[?e :route/id ?route]
            [?e :route/cost-usd ?cost]]})
```

---

## 6.0 TRACKING ENGINE - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         6.0 TRACKING ENGINE                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

  CARRIER UPDATES
       │
       │ GPS, AIS, status
       ▼
┌─────────────────┐
│ 6.1 POSITION    │
│ RECEIVER        │
│                 │
│ • AIS decode    │
│ • GPS normalize │
│ • Dedup         │
└────────┬────────┘
         │
         │ position events
         ▼
┌─────────────────┐
│ 6.2 SHIPMENT    │
│ MATCHER         │
│                 │
│ • Correlate to  │
│   active ships  │
│ • Multi-cargo   │
└────────┬────────┘
         │
         │ matched updates
         ├────────────────────────────────────┐
         │                                    │
         ▼                                    ▼
┌─────────────────┐                  ┌─────────────────┐
│ 6.3 ETA         │                  │ 6.5 POSITION    │
│ CALCULATOR      │                  │ CACHE           │
│                 │                  │                 │
│ • Historical    │                  │ • Dragonfly     │
│ • Weather adj   │                  │ • TTL: 5 min    │
│ • Traffic adj   │                  │ • Geo-indexed   │
└────────┬────────┘                  └─────────────────┘
         │
         │ updated ETAs
         ▼
┌─────────────────┐
│ 6.4 ALERT       │
│ GENERATOR       │
│                 │
│ • Delay > thresh│
│ • Route deviat  │
│ • Constraint    │
│   violation     │
└────────┬────────┘
         │
         │ alerts
         ▼
┌─────────────────┐
│ 6.6 EVENT       │──────────► TO 7.0 API (WebSocket push)
│ BROADCASTER     │
│                 │──────────► TO 8.0 ANALYTICS (metrics)
│ • Phoenix PubSub│
│ • Per-shipment  │
└─────────────────┘
```

---

## 7.0 API GATEWAY - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          7.0 API GATEWAY                                        │
└─────────────────────────────────────────────────────────────────────────────────┘

  EXTERNAL REQUESTS
       │
       │ HTTP/WebSocket
       ▼
┌─────────────────┐
│ 7.1 ROUTER      │
│                 │
│ • Path matching │
│ • Versioning    │
│ • Method check  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ 7.2 AUTH        │────►│ 7.7 RATE        │
│ MIDDLEWARE      │     │ LIMITER         │
│                 │     │                 │
│ • JWT verify    │     │ • Per-client    │
│ • API key       │     │ • Dragonfly     │
│ • Permissions   │     └─────────────────┘
└────────┬────────┘
         │
         ▼
    ┌────┴────┬─────────────┬─────────────┐
    │         │             │             │
    ▼         ▼             ▼             ▼
┌───────┐ ┌───────┐   ┌───────────┐ ┌───────────┐
│ 7.3   │ │ 7.4   │   │ 7.5       │ │ 7.6       │
│ REST  │ │GraphQL│   │ WebSocket │ │ gRPC      │
│ CTRL  │ │ CTRL  │   │ HANDLER   │ │ HANDLER   │
└───┬───┘ └───┬───┘   └─────┬─────┘ └─────┬─────┘
    │         │             │             │
    └─────────┴─────────────┴─────────────┘
                      │
                      ▼
               INTERNAL SERVICES
               (1.0 - 6.0, 8.0)
```

### API Endpoints

```elixir
# 7.3 REST Controller routes
scope "/api/v1", VedsWeb do
  pipe_through [:api, :authenticated]

  # Shipments
  resources "/shipments", ShipmentController
  post "/shipments/:id/optimize", ShipmentController, :optimize

  # Routes
  get "/routes/:id", RouteController, :show
  get "/routes/:id/proof", RouteController, :proof_certificate

  # Tracking
  get "/tracking/:shipment_id", TrackingController, :show
  get "/tracking/:shipment_id/history", TrackingController, :history

  # Constraints
  resources "/constraints", ConstraintController
  post "/constraints/evaluate", ConstraintController, :evaluate

  # Audit
  get "/audit/:entity_id", AuditController, :show
  get "/audit/:entity_id/as-of/:timestamp", AuditController, :as_of
end
```

---

## 8.0 ANALYTICS & VISUALIZATION - Decomposition

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    8.0 ANALYTICS & VISUALIZATION                                │
└─────────────────────────────────────────────────────────────────────────────────┘

  DATA SOURCES (5.0 stores, 6.0 events)
       │
       │ historical + real-time
       ▼
┌─────────────────┐
│ 8.1 DATA        │
│ CONNECTOR       │
│                 │
│ • XTDB client   │
│ • SurrealDB     │
│ • Dragonfly sub │
└────────┬────────┘
         │
         │ raw data streams
         ▼
┌─────────────────┐
│ 8.2 ETL         │
│ PIPELINE        │
│                 │
│ • Transform     │
│ • Aggregate     │
│ • Window        │
└────────┬────────┘
         │
         │ analytics-ready data
         ├────────────────────────────────────────────────────┐
         │                        │                           │
         ▼                        ▼                           ▼
┌─────────────────┐      ┌─────────────────┐         ┌─────────────────┐
│ 8.3 NETWORK     │      │ 8.4 TIME-SERIES │         │ 8.5 GEOSPATIAL  │
│ VISUALIZER      │      │ ANALYZER        │         │ MAPPER          │
│                 │      │                 │         │                 │
│ • Graph layout  │      │ • Trends        │         │ • Route maps    │
│ • Flow viz      │      │ • Forecasting   │         │ • Heatmaps      │
│ • Constraint    │      │ • Anomaly det   │         │ • Live tracking │
│   highlighting  │      │                 │         │                 │
└────────┬────────┘      └────────┬────────┘         └────────┬────────┘
         │                        │                           │
         └────────────────────────┴───────────────────────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ 8.6 DASHBOARD   │
                         │ RENDERER        │
                         │                 │
                         │ • Makie.jl      │
                         │ • Genie.jl web  │
                         │ • Pluto.jl      │
                         └────────┬────────┘
                                  │
                                  ▼
                            TO ANALYST/EXEC
```

### Julia Implementation

```julia
# 8.3 Network Visualizer using Makie.jl
using GLMakie, Graphs, GraphMakie

function visualize_transport_network(graph::SimpleDiGraph, node_data, edge_data)
    fig = Figure(size = (1200, 800))
    ax = Axis(fig[1, 1], title = "VEDS Transport Network")

    # Color nodes by type
    node_colors = [node_type_color(node_data[v].type) for v in vertices(graph)]

    # Color edges by constraint satisfaction
    edge_colors = [constraint_color(edge_data[e]) for e in edges(graph)]

    graphplot!(ax, graph,
        node_color = node_colors,
        edge_color = edge_colors,
        node_size = 20,
        nlabels = [node_data[v].name for v in vertices(graph)],
        elabels = [edge_data[e].mode for e in edges(graph)]
    )

    fig
end

# 8.4 Time-series with forecasting
using TimeSeries, StateSpaceModels

function forecast_demand(historical_shipments::TimeArray, horizon::Int)
    model = SARIMA(historical_shipments, order=(1,1,1), seasonal=(1,1,1,7))
    fit!(model)
    forecast(model, horizon)
end

# 8.5 Geospatial mapping
using GeoMakie, GeoJSON

function map_active_shipments(shipments::Vector{Shipment})
    fig = Figure()
    ga = GeoAxis(fig[1, 1], dest = "+proj=wintri")

    # Base map
    lines!(ga, GeoMakie.coastlines())

    # Plot routes
    for s in shipments
        lines!(ga, s.route_coordinates,
               color = status_color(s.status),
               linewidth = 2)
        scatter!(ga, [s.current_position],
                 marker = :circle,
                 markersize = 10)
    end

    fig
end
```

---

## Process Interaction Matrix

| From → To | 1.0 | 2.0 | 3.0 | 4.0 | 5.0 | 6.0 | 7.0 | 8.0 |
|-----------|-----|-----|-----|-----|-----|-----|-----|-----|
| **1.0 Data Ingestion** | - | Alert | Graph | - | - | - | - | Metrics |
| **2.0 Constraint Engine** | - | - | Rules | - | Rules | - | - | - |
| **3.0 Route Optimizer** | - | Eval | - | Proof | Routes | - | - | - |
| **4.0 Formal Verifier** | - | - | - | - | Certs | - | - | - |
| **5.0 Decision Store** | - | - | Read | - | - | Active | Query | Query |
| **6.0 Tracking Engine** | - | - | - | - | Update | - | Push | Events |
| **7.0 API Gateway** | - | - | Request | - | Read | Read | - | - |
| **8.0 Analytics** | - | - | - | - | Read | Read | - | - |
