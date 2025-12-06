# VEDS Data Flow Diagram - Level 1 (Major Processes)

## Overview

Level 1 decomposes VEDS into its major subsystems/processes.
Each numbered process will be further decomposed in Level 2.

## Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                      V E D S                                            │
└─────────────────────────────────────────────────────────────────────────────────────────┘

    ┌───────────┐                                                      ┌───────────┐
    │ TRANSPORT │                                                      │  POLICY   │
    │   APIs    │                                                      │  ADMIN    │
    └─────┬─────┘                                                      └─────┬─────┘
          │ rates, schedules                              constraints, rules │
          │                                                                  │
          ▼                                                                  ▼
    ┌───────────────────┐                                      ┌───────────────────┐
    │                   │          normalized rates            │                   │
    │   1.0 DATA        │─────────────────────────────────────►│  2.0 CONSTRAINT   │
    │   INGESTION       │                                      │  ENGINE           │
    │                   │          data quality alerts         │                   │
    │   [Elixir]        │◄─────────────────────────────────────│  [Clojure/XTDB]   │
    │                   │                                      │                   │
    └─────────┬─────────┘                                      └─────────┬─────────┘
              │                                                          │
              │ validated transport data                constraint models│
              │                                                          │
              ▼                                                          ▼
    ┌───────────────────────────────────────────────────────────────────────────────┐
    │                                                                               │
    │                           3.0 ROUTE OPTIMIZER                                 │
    │                                                                               │
    │                              [Rust Core]                                      │
    │                                                                               │
    │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
    │   │ Graph       │    │ Multi-obj   │    │ Constraint  │    │ Path        │   │
    │   │ Builder     │───►│ Optimizer   │───►│ Validator   │───►│ Ranker      │   │
    │   └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
    │                                                                               │
    └───────────────────────────────────────────────────────────────────────────────┘
              │                              │                           │
              │ candidate routes             │ proofs required           │ ranked routes
              │                              ▼                           │
              │                    ┌───────────────────┐                 │
              │                    │                   │                 │
              │                    │  4.0 FORMAL       │                 │
              │                    │  VERIFIER         │                 │
              │                    │                   │                 │
              │                    │  [Ada/SPARK]      │                 │
              │                    │                   │                 │
              │                    └─────────┬─────────┘                 │
              │                              │ verified decisions        │
              │                              ▼                           ▼
              │                    ┌───────────────────────────────────────────┐
              │                    │                                           │
              └───────────────────►│          5.0 DECISION STORE               │
                                   │                                           │
                                   │  ┌─────────────┐    ┌─────────────┐       │
                                   │  │   XTDB     │    │  SurrealDB  │       │
                                   │  │ (Bitemporal)│    │  (Graph/Doc)│       │
                                   │  └─────────────┘    └─────────────┘       │
                                   │                                           │
                                   └─────────────────────┬─────────────────────┘
                                                         │
          ┌──────────────────────────────────────────────┼──────────────────────┐
          │                                              │                      │
          ▼                                              ▼                      ▼
┌───────────────────┐                        ┌───────────────────┐    ┌───────────────────┐
│                   │                        │                   │    │                   │
│  6.0 TRACKING     │                        │  7.0 API          │    │  8.0 ANALYTICS    │
│  ENGINE           │                        │  GATEWAY          │    │  & VISUALIZATION  │
│                   │                        │                   │    │                   │
│  [Elixir+Dragon]  │                        │  [Elixir/Phoenix] │    │  [Julia]          │
│                   │                        │                   │    │                   │
└─────────┬─────────┘                        └─────────┬─────────┘    └─────────┬─────────┘
          │                                            │                        │
          │ tracking updates                           │ API responses          │ visualizations
          ▼                                            ▼                        ▼
    ┌───────────┐                              ┌───────────┐            ┌───────────┐
    │  CARRIER  │                              │  SHIPPER  │            │ ANALYST   │
    └───────────┘                              └───────────┘            └───────────┘
                                                     │
                                                     │ audit queries
                                                     ▼
                                               ┌───────────┐
                                               │  AUDITOR  │
                                               └───────────┘
```

## Process Descriptions

### 1.0 DATA INGESTION [Elixir]

**Purpose:** Collect, normalize, and validate data from external transport APIs

**Inputs:**
- Raw rates from maritime APIs (Maersk, CMA CGM)
- Rail schedules from DB Cargo, SNCF
- Road transport availability from TMS providers
- Air cargo rates from IATA feeds
- GPS/AIS positions from vessel tracking

**Outputs:**
- Normalized rate objects (common schema)
- Validated transport graph edges
- Data quality metrics and alerts

**Data Stores Used:**
- Dragonfly (caching hot rates)
- SurrealDB (transport graph edges)

---

### 2.0 CONSTRAINT ENGINE [Clojure/XTDB]

**Purpose:** Model, store, and evaluate business/regulatory constraints using Datalog

**Inputs:**
- Constraint definitions from Policy Admin
- Labor rules (ILO standards, national minimums)
- Carbon budgets
- Regulatory requirements (customs, hazmat, etc.)

**Outputs:**
- Compiled constraint models (Datalog rules)
- Constraint evaluation results
- Historical constraint state (bitemporal)

**Data Stores Used:**
- XTDB (constraint definitions, bitemporal history)

**Datalog Example:**
```clojure
;; Rule: Route segment must pay at least minimum wage
[:find ?segment ?violation
 :where
 [?segment :segment/wage-per-hour ?wage]
 [?segment :segment/country ?country]
 [?country :country/min-wage ?min-wage]
 [(< ?wage ?min-wage)]
 [(ground "wage-violation") ?violation]]
```

---

### 3.0 ROUTE OPTIMIZER [Rust]

**Purpose:** Find optimal multi-modal paths satisfying all constraints

**Inputs:**
- Transport graph (nodes: hubs, edges: routes with costs)
- Shipment request (origin, destination, cargo, constraints)
- Constraint models from 2.0

**Outputs:**
- Candidate routes (top-K paths)
- Optimization metrics (cost, time, carbon, labor score)
- Proof obligations for formal verifier

**Sub-processes:**
- 3.1 Graph Builder - Construct/update transport network
- 3.2 Multi-objective Optimizer - Pareto-optimal path search
- 3.3 Constraint Validator - Check constraints on paths
- 3.4 Path Ranker - Score and rank candidates

---

### 4.0 FORMAL VERIFIER [Ada/SPARK]

**Purpose:** Mathematically prove that selected routes satisfy critical constraints

**Inputs:**
- Candidate route from 3.0
- Critical constraints (safety, regulatory, labor)
- Proof obligations

**Outputs:**
- Formal proof certificate (or rejection)
- Verification report
- Confidence level (PROVEN, VALIDATED, UNVERIFIED)

**Guarantees:**
- Routes marked PROVEN mathematically satisfy all specified constraints
- No runtime constraint violations possible for PROVEN routes

---

### 5.0 DECISION STORE [XTDB + SurrealDB]

**Purpose:** Persist all decisions with full bitemporal history

**Components:**

| Store | Purpose | Data Types |
|-------|---------|------------|
| XTDB | Bitemporal audit trail | Decisions, constraint evaluations, "what we knew when" |
| SurrealDB | Graph + documents | Transport network, shipments, live state |
| Dragonfly | Cache layer | Hot routes, session state, real-time positions |

**Bitemporal Queries (XTDB):**
```clojure
;; What route did we compute on Oct 15, using data available on Oct 14?
(xt/q db
  '{:find [?route ?cost ?carbon]
    :where [[?e :route/id ?route]
            [?e :route/cost ?cost]
            [?e :route/carbon ?carbon]]
    :valid-time #inst "2025-10-15"
    :tx-time #inst "2025-10-14"})
```

---

### 6.0 TRACKING ENGINE [Elixir + Dragonfly]

**Purpose:** Real-time tracking of shipments in transit

**Inputs:**
- GPS/AIS positions from carriers
- Status updates (loaded, departed, delayed, arrived)
- ETA revisions

**Outputs:**
- Real-time position updates to shippers
- Delay alerts
- Re-routing triggers (when ETA exceeds threshold)

**Technologies:**
- Elixir GenStage for backpressure handling
- Phoenix PubSub for real-time push
- Dragonfly for position cache

---

### 7.0 API GATEWAY [Elixir/Phoenix]

**Purpose:** External API for shippers, carriers, and integrations

**Endpoints:**
- `POST /shipments` - Create shipment request
- `GET /routes/{id}` - Get optimized route
- `GET /tracking/{id}` - Real-time tracking
- `GET /audit/{id}` - Historical decision audit
- `POST /constraints` - Define business rules

**Features:**
- GraphQL and REST support
- WebSocket for real-time updates
- Rate limiting, authentication
- OpenAPI 3.0 documentation

---

### 8.0 ANALYTICS & VISUALIZATION [Julia]

**Purpose:** Advanced analytics, visualization, and decision support

**Capabilities:**
- Network visualization (transport graph)
- Carbon impact dashboards
- Cost optimization trends
- Constraint satisfaction analysis
- Predictive analytics (demand forecasting)

**Julia Stack:**
- Makie.jl / GLMakie - Interactive 3D visualizations
- Graphs.jl - Network analysis
- DataFrames.jl - Tabular analytics
- Pluto.jl - Interactive notebooks
- Genie.jl - Web dashboard framework

---

## Data Stores Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                        DATA STORES                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│   │     DS1         │  │     DS2         │  │    DS3        │  │
│   │    XTDB         │  │   SurrealDB     │  │  Dragonfly    │  │
│   │                 │  │                 │  │               │  │
│   │ • Bitemporal    │  │ • Transport     │  │ • Rate cache  │  │
│   │ • Constraints   │  │   graph         │  │ • Positions   │  │
│   │ • Decisions     │  │ • Shipments     │  │ • Sessions    │  │
│   │ • Audit trail   │  │ • Documents     │  │ • Hot routes  │  │
│   │                 │  │ • Real-time     │  │               │  │
│   │ [Datalog query] │  │ [SurrealQL]     │  │ [Redis proto] │  │
│   └─────────────────┘  └─────────────────┘  └───────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Inter-Process Data Flows

| From | To | Data | Volume | Latency Req |
|------|-----|------|--------|-------------|
| 1.0 | 3.0 | Transport graph updates | 10K edges/day | Minutes |
| 1.0 | DS3 | Rate cache | 100K rates/hour | Seconds |
| 2.0 | 3.0 | Constraint models | 100/day | Minutes |
| 3.0 | 4.0 | Proof obligations | 1K routes/day | Seconds |
| 3.0 | 5.0 | Candidate routes | 5K/day | Seconds |
| 4.0 | 5.0 | Verified decisions | 1K/day | Seconds |
| 5.0 | 6.0 | Active shipments | 10K concurrent | Real-time |
| 5.0 | 7.0 | Query responses | 100K/day | <100ms |
| 5.0 | 8.0 | Analytics datasets | 1M rows/day | Batch |

## Technology Mapping

| Process | Primary Language | Secondary | Database |
|---------|------------------|-----------|----------|
| 1.0 Data Ingestion | Elixir | - | SurrealDB, Dragonfly |
| 2.0 Constraint Engine | Clojure | Datalog | XTDB |
| 3.0 Route Optimizer | Rust | - | SurrealDB |
| 4.0 Formal Verifier | Ada/SPARK | - | - |
| 5.0 Decision Store | - | - | XTDB, SurrealDB |
| 6.0 Tracking Engine | Elixir | - | Dragonfly |
| 7.0 API Gateway | Elixir | - | All |
| 8.0 Analytics | Julia | - | All (read) |
