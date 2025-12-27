# VEDS MVP Tech Stack

## Philosophy: Narrow First, Expand Later

The MVP uses the **minimum viable stack** to ship working software fast.
Formal verification, advanced analytics, and bitemporal queries are **deferred to v2**.

---

## MVP Stack (4 components)

```
┌─────────────────────────────────────────────────────────┐
│                    REST API (:4000)                     │
│                      Deno + ReScript                    │
├─────────────────────────────────────────────────────────┤
│                  Route Optimizer (gRPC :50051)          │
│                         Rust                            │
├──────────────────────────┬──────────────────────────────┤
│     SurrealDB (:8000)    │      Dragonfly (:6379)       │
│   graph/doc/SQL + audit  │     cache (positions/rates)  │
└──────────────────────────┴──────────────────────────────┘
```

### Languages

| Role | Language | Why |
|------|----------|-----|
| **Core Logic** | Rust | Performance, safety, single binary |
| **API Glue** | Deno + ReScript | Per language policy, type-safe |
| **Scripts** | Bash | Build automation only |

### Databases

| DB | Purpose | Data |
|----|---------|------|
| **SurrealDB** | Primary store | Network, shipments, routes, constraints, audit |
| **Dragonfly** | Hot cache | Real-time positions, rate quotes, sessions |

### Proof Path: Runtime Constraints

**Single approach:** Evaluate constraints at runtime via ReScript DSL.

- Constraints defined declaratively in `Constraint.res`
- Evaluated during route optimization
- Results stored with routes for audit

**Deferred to v2:**
- Ada/SPARK formal verification
- Julia property-based testing
- XTDB Datalog queries

---

## Architecture Decisions

### Why SurrealDB as primary?
- Graph queries for network traversal
- Document store for flexible schemas
- SQL for familiar queries
- Built-in valid_from/valid_until for pseudo-bitemporal
- Single database = simpler ops

### Why Dragonfly for cache?
- Redis API compatibility
- Higher performance than Redis
- Needed for real-time position tracking (high write volume)

### Why Rust for optimizer?
- Already implemented with Petgraph
- gRPC for internal RPC
- Can absorb more logic if needed

### Why Deno + ReScript for API?
- Per CLAUDE.md language policy
- ReScript provides type safety
- Deno provides secure runtime

---

## What's Deferred to v2

| Component | Reason for Deferral |
|-----------|---------------------|
| XTDB | SurrealDB handles MVP needs; true bitemporal can wait |
| Ada/SPARK | Formal proofs are v2 once core logic stabilizes |
| Julia viz | Nice-to-have; ship without dashboards first |
| WebSocket tracking | REST polling is sufficient for MVP |
| Clojure constraints | Replaced by ReScript DSL |
| Elixir API | Replaced by Deno per policy |

---

## Running MVP

```bash
# Start core services (4 containers)
docker-compose up -d

# Initialize schema
just db-init

# Seed sample data
just db-seed

# Health check
just health
```

### With v2 features (when ready)
```bash
docker-compose --profile v2 up -d
```

---

## Container Summary

| Service | Port | Profile |
|---------|------|---------|
| surrealdb | 8000 | default |
| dragonfly | 6379 | default |
| rust-optimizer | 50051, 8090 | default |
| deno-api | 4000 | default |
| xtdb | 3000 | v2 |
| julia-viz | 8081 | v2 |
| adminer | 8082 | tools |
