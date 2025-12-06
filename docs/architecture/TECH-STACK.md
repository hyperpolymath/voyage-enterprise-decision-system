# VEDS Technology Stack

## Final Architecture Decision

Based on discussion and requirements, VEDS uses the following technology stack:

---

## Stack Summary

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          VEDS TECHNOLOGY STACK                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   LAYER              TECHNOLOGY           PURPOSE                              │
│   ═════              ══════════           ═══════                              │
│                                                                                 │
│   Presentation       Phoenix LiveView     Real-time dashboard                  │
│                      Julia/Genie.jl       Advanced analytics & visualization   │
│                      Pluto.jl             Interactive notebooks                │
│                                                                                 │
│   API                Elixir/Phoenix       REST, GraphQL, WebSocket, gRPC       │
│                                                                                 │
│   Domain Services                                                               │
│   ├─ Routing         Rust                 High-perf path optimization          │
│   ├─ Constraints     Clojure              Datalog rules, XTDB integration      │
│   ├─ Verification    Ada/SPARK            Formal proofs                        │
│   └─ Tracking        Elixir               Real-time position processing        │
│                                                                                 │
│   Data Layer                                                                    │
│   ├─ Bitemporal      XTDB                 Decisions, audit trail, constraints  │
│   ├─ Graph/Doc       SurrealDB            Transport network, shipments         │
│   └─ Cache           Dragonfly            Positions, rates, sessions           │
│                                                                                 │
│   Infrastructure     Docker/Podman        Containerization                     │
│                      Kubernetes           Orchestration (optional)             │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Language Selection Rationale

### Rust - Route Optimizer
```
WHY: Performance + Safety
├── Path algorithms need sub-second response for 50K+ node graphs
├── Memory safety without GC prevents latency spikes
├── Rayon for parallel path search
├── Strong type system catches constraint bugs at compile time
└── Excellent FFI for inter-language communication

LIBRARIES:
├── petgraph - Graph algorithms
├── pathfinding - Dijkstra, A*, Yen's K-shortest
├── rayon - Parallel iterators
├── ndarray - Matrix operations for scoring
├── serde - Serialization
└── tonic - gRPC server
```

### Elixir/Phoenix - API & Tracking
```
WHY: Fault Tolerance + Real-Time
├── OTP supervisors handle crashes gracefully
├── GenStage for backpressure in position streaming
├── Phoenix Channels for WebSocket at scale
├── Hot code reloading for zero-downtime deploys
└── Pattern matching for clean data transformation

LIBRARIES:
├── Phoenix - Web framework
├── Ecto - Database queries (for SurrealDB via adapter)
├── GenStage - Backpressure handling
├── Oban - Background jobs
└── Tesla - HTTP client for external APIs
```

### Clojure - Constraint Engine
```
WHY: XTDB Native + Datalog
├── XTDB is written in Clojure, native integration
├── Datalog is natural for constraint rules
├── REPL-driven development for rule experimentation
├── Immutable data structures for safe concurrency
└── Spec for constraint validation

LIBRARIES:
├── xtdb-core - Database client
├── spec-alpha2 - Constraint validation
├── core.async - Async constraint evaluation
├── cheshire - JSON handling
└── mount - State management
```

### Ada/SPARK - Formal Verification
```
WHY: Mathematical Proof
├── SPARK subset enables formal verification
├── GNATprove generates proof obligations
├── Why3 backend connects to SMT solvers
├── Designed for safety-critical systems
└── Contracts (Pre/Post) catch errors at design time

TOOLS:
├── GNAT Community Edition - Compiler
├── GNATprove - Proof engine
├── Why3 - Intermediate verification language
├── Z3 / CVC5 - SMT solvers
└── GPS - IDE with proof integration
```

### Julia - Analytics & Visualization
```
WHY: Performance + Ecosystem
├── Near-C speed for numerical computing
├── Makie.jl - Best-in-class visualization
├── Graphs.jl - Network analysis
├── Multiple dispatch enables clean abstractions
└── Jupyter/Pluto for interactive exploration

LIBRARIES:
├── Makie.jl / GLMakie / CairoMakie - Visualization
├── GraphMakie.jl - Network visualization
├── GeoMakie.jl - Geospatial mapping
├── DataFrames.jl - Tabular data
├── Genie.jl + Stipple - Web dashboards
├── JuMP.jl - Optimization modeling
└── HTTP.jl + Redis.jl - Data connectors
```

---

## Database Selection Rationale

### XTDB - Bitemporal Store
```
WHY: Bitemporal + Datalog
├── First-class bitemporality (valid-time + tx-time)
├── "What did we know when?" queries for audit
├── Native Datalog for constraint evaluation
├── Immutable history (never lose data)
└── Open source, Clojure ecosystem

USE CASES:
├── Constraint definitions (versioned)
├── Routing decisions (auditable)
├── Constraint evaluations (traceable)
├── Proof certificates (immutable)
└── Audit entries (complete history)

SCHEMA: Datalog-native documents
```

### SurrealDB - Graph/Document Store
```
WHY: Multi-Model Simplicity
├── Graph + Document + Relational in one
├── Native graph traversals for route queries
├── SurrealQL is SQL-like but graph-aware
├── Real-time subscriptions built-in
├── Written in Rust (performance)
└── Single database reduces operational complexity

USE CASES:
├── Transport network (graph)
├── Shipments (documents)
├── Routes and segments (relations)
├── Carriers and ports (reference data)
└── Tracking events (time-series lite)

SCHEMA: Strongly typed with SurrealQL
```

### Dragonfly - Cache Layer
```
WHY: Redis-Compatible + Fast
├── Drop-in Redis replacement
├── 25x faster than Redis (multi-threaded)
├── Geo commands for position indexing
├── Pub/Sub for real-time events
└── HyperLogLog for deduplication

USE CASES:
├── Position cache (TTL: 5 min)
├── Rate cache (TTL: 15 min)
├── Constraint lookup tables (TTL: 5 min)
├── Session storage (TTL: 24 hr)
├── Hot route cache (TTL: 1 hr)
└── Geo-indexed vessel positions

SCHEMA: Redis data structures
```

---

## Inter-Service Communication

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         COMMUNICATION PATTERNS                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

  SYNCHRONOUS (Request/Response)
  ══════════════════════════════

  ┌──────────────┐     gRPC/Protobuf      ┌──────────────┐
  │   Elixir     │◄──────────────────────►│    Rust      │
  │   API        │     (type-safe)        │   Optimizer  │
  └──────────────┘                        └──────────────┘

  ┌──────────────┐     HTTP/JSON          ┌──────────────┐
  │   Rust       │◄──────────────────────►│   Clojure    │
  │   Optimizer  │     (constraint eval)  │   Constraints│
  └──────────────┘                        └──────────────┘

  ┌──────────────┐     HTTP/Transit       ┌──────────────┐
  │   Clojure    │◄──────────────────────►│    XTDB      │
  │   Constraints│     (native client)    │              │
  └──────────────┘                        └──────────────┘


  ASYNCHRONOUS (Event-Driven)
  ═══════════════════════════

  ┌──────────────┐     Dragonfly Pub/Sub  ┌──────────────┐
  │   Elixir     │◄──────────────────────►│   Julia      │
  │   Tracking   │     (position events)  │   Analytics  │
  └──────────────┘                        └──────────────┘

  ┌──────────────┐     Dragonfly Pub/Sub  ┌──────────────┐
  │   Clojure    │────────────────────────►│   Rust       │
  │   Constraints│     (sync complete)    │   Optimizer  │
  └──────────────┘                        └──────────────┘


  HOT PATH (Ultra-Low Latency)
  ════════════════════════════

  ┌──────────────┐     Dragonfly GET      ┌──────────────┐
  │   Rust       │◄──────────────────────►│  Dragonfly   │
  │   Optimizer  │     (~1μs latency)     │  (in-memory) │
  └──────────────┘                        └──────────────┘

  Constraint lookup tables pre-compiled by Clojure,
  pulled by Rust for local evaluation. No network
  call per route evaluation.
```

---

## Project Structure

```
voyage-enterprise-decision-system/
├── LICENSE
├── LICENSE-MIT
├── LICENSE-AGPL
├── README.md
├── docker-compose.yml
│
├── docs/
│   ├── design/
│   │   ├── DFD-LEVEL-0-CONTEXT.md
│   │   ├── DFD-LEVEL-1-MAJOR-PROCESSES.md
│   │   ├── DFD-LEVEL-2-SUBPROCESSES.md
│   │   ├── DFD-LEVEL-3-DETAILED.md
│   │   ├── ER-DIAGRAM.md
│   │   ├── UML-DIAGRAMS.md
│   │   └── JULIA-VISUALIZATION.md
│   ├── architecture/
│   │   └── TECH-STACK.md (this file)
│   └── vocab/
│       └── VOID-MAPPING.md
│
├── src/
│   ├── rust-routing/
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── graph/
│   │       ├── optimizer/
│   │       ├── constraints/
│   │       └── grpc/
│   │
│   ├── elixir-api/
│   │   ├── mix.exs
│   │   └── lib/
│   │       ├── veds/
│   │       ├── veds_web/
│   │       └── tracking/
│   │
│   ├── clojure-constraints/
│   │   ├── deps.edn
│   │   └── src/
│   │       ├── veds/constraints/
│   │       ├── veds/datalog/
│   │       └── veds/sync/
│   │
│   ├── ada-verification/
│   │   ├── alire.toml
│   │   └── src/
│   │       ├── route_verifier.ads
│   │       ├── route_verifier.adb
│   │       └── proofs/
│   │
│   └── julia-viz/
│       ├── Project.toml
│       └── src/
│           ├── VEDS.jl
│           ├── NetworkViz.jl
│           ├── GeoViz.jl
│           ├── AnalyticsDashboard.jl
│           └── connectors/
│
├── config/
│   ├── xtdb.edn
│   ├── surrealdb.surql
│   └── dragonfly.conf
│
└── docker/
    ├── Dockerfile.rust
    ├── Dockerfile.elixir
    ├── Dockerfile.clojure
    ├── Dockerfile.ada
    └── Dockerfile.julia
```

---

## Development Environment

### Prerequisites

```bash
# Languages
rustup install stable          # Rust 1.75+
asdf install elixir 1.16       # Elixir 1.16+
asdf install erlang 26.2       # Erlang/OTP 26+
asdf install java graalvm-21   # Java 21 (for Clojure)
asdf install clojure 1.11      # Clojure 1.11+
apt install gnat-13            # GNAT (Ada compiler)
juliaup add release            # Julia 1.10+

# Databases
docker pull xtdb/xtdb:latest
docker pull surrealdb/surrealdb:latest
docker pull docker.dragonflydb.io/dragonflydb/dragonfly
```

### Docker Compose (Development)

```yaml
version: '3.8'

services:
  xtdb:
    image: xtdb/xtdb:latest
    ports:
      - "3000:3000"
    volumes:
      - xtdb_data:/var/lib/xtdb
    environment:
      - XTDB_ENABLE_HTTP=true

  surrealdb:
    image: surrealdb/surrealdb:latest
    ports:
      - "8000:8000"
    volumes:
      - surreal_data:/data
    command: start --log trace --user root --pass root file:/data/veds.db

  dragonfly:
    image: docker.dragonflydb.io/dragonflydb/dragonfly
    ports:
      - "6379:6379"
    ulimits:
      memlock: -1

  # Application services
  rust-optimizer:
    build:
      context: ./src/rust-routing
      dockerfile: ../../docker/Dockerfile.rust
    ports:
      - "50051:50051"
    depends_on:
      - surrealdb
      - dragonfly

  elixir-api:
    build:
      context: ./src/elixir-api
      dockerfile: ../../docker/Dockerfile.elixir
    ports:
      - "4000:4000"
    depends_on:
      - rust-optimizer
      - xtdb
      - surrealdb
      - dragonfly

  clojure-constraints:
    build:
      context: ./src/clojure-constraints
      dockerfile: ../../docker/Dockerfile.clojure
    ports:
      - "8080:8080"
    depends_on:
      - xtdb
      - dragonfly

  julia-viz:
    build:
      context: ./src/julia-viz
      dockerfile: ../../docker/Dockerfile.julia
    ports:
      - "8081:8080"
    depends_on:
      - xtdb
      - surrealdb
      - dragonfly

volumes:
  xtdb_data:
  surreal_data:
```

---

## Performance Targets

| Component | Metric | Target | Notes |
|-----------|--------|--------|-------|
| Route Optimization | Latency (cold) | <500ms | First route for request |
| Route Optimization | Latency (warm) | <100ms | Cached graph |
| Constraint Eval | Latency (hot path) | <10μs | Per-route, in-memory |
| Position Update | Latency | <100ms | Ingest → WebSocket push |
| API Response | p99 Latency | <200ms | Standard queries |
| Formal Proof | Time | <30s | Async, not blocking |
| Dashboard Load | Time | <500ms | Initial page load |

---

## Scaling Strategy

### Horizontal Scaling

| Component | Scaling Method |
|-----------|----------------|
| Elixir API | Add nodes to cluster (OTP distribution) |
| Rust Optimizer | Replicate behind load balancer |
| Clojure Constraints | Stateless, replicate freely |
| XTDB | Add read replicas |
| SurrealDB | Cluster mode (when available) |
| Dragonfly | Cluster mode |

### Vertical Scaling

| Component | Bottleneck | Mitigation |
|-----------|------------|------------|
| Rust Optimizer | Graph size in memory | Use Rayon for parallelism |
| XTDB | Query complexity | Optimize Datalog, add indexes |
| Dragonfly | Connection count | Increase file descriptors |

---

## Security Considerations

1. **API Authentication:** JWT tokens, API keys via Phoenix Guardian
2. **Database Access:** Network isolation, credentials in secrets manager
3. **Inter-Service:** mTLS between containers
4. **Audit Trail:** XTDB provides immutable history
5. **Formal Verification:** Proofs ensure constraints cannot be bypassed

---

## Monitoring & Observability

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              OBSERVABILITY STACK                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   Metrics:      Prometheus + Grafana                                            │
│   Traces:       OpenTelemetry → Jaeger                                          │
│   Logs:         Loki (structured JSON logs)                                     │
│   Alerts:       Alertmanager                                                    │
│                                                                                 │
│   Per-Service Instrumentation:                                                  │
│   ├─ Elixir:    Telemetry + PromEx                                              │
│   ├─ Rust:      tracing + tracing-opentelemetry                                 │
│   ├─ Clojure:   prometheus-clj + iapetos                                        │
│   ├─ Julia:     Prometheus.jl                                                   │
│   └─ Ada:       Custom metrics via HTTP endpoint                                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Comparison to Infor

| Capability | Infor | VEDS |
|------------|-------|------|
| Multi-modal optimization | ✅ | ✅ (with formal proofs) |
| Real-time tracking | ✅ | ✅ (Dragonfly + Phoenix) |
| Constraint engine | ✅ (rules engine) | ✅ (Datalog + SMT) |
| Carbon accounting | ✅ | ✅ (first-class objective) |
| Labor conditions | ❓ | ✅ (ILO constraints) |
| Formal verification | ❌ | ✅ (Ada/SPARK proofs) |
| Bitemporal audit | ❌ | ✅ (XTDB native) |
| Open source | ❌ | ✅ (MIT/AGPL + Palimpsest) |
| VoID/Linked Data | ❌ | ✅ (SPARQL endpoint) |
| Advanced visualization | ✅ | ✅ (Julia + Makie) |

**VEDS differentiation:** Formal verification + labor ethics + open source + bitemporality
