# VEDS Data Flow Diagram - Level 3 (Detailed Flows)

## Overview

Level 3 provides the most granular view of data flows, focusing on critical sub-processes.
This document details the hot paths and complex interactions.

---

## 3.0 ROUTE OPTIMIZER - Detailed (Hot Path Critical)

### 3.3 Multi-Objective Scorer - Detailed

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 3.3 MULTI-OBJECTIVE SCORER (DETAILED)                           │
└─────────────────────────────────────────────────────────────────────────────────┘

  CANDIDATE PATHS (from 3.2)
       │
       │ Vec<CandidatePath>
       ▼
┌─────────────────┐
│ 3.3.1 COST      │
│ CALCULATOR      │
│                 │
│ For each segment:
│ ┌───────────────────────────────────────────────────────────────┐
│ │ cost = base_rate                                              │
│ │      + (weight_kg × rate_per_kg)                              │
│ │      + (volume_m3 × rate_per_m3)                              │
│ │      + fuel_surcharge                                         │
│ │      + port_fees + customs_fees                               │
│ │      + carbon_tax (if applicable)                             │
│ └───────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │ cost_usd: Decimal
         ▼
┌─────────────────┐
│ 3.3.2 TIME      │
│ CALCULATOR      │
│                 │
│ For each segment:
│ ┌───────────────────────────────────────────────────────────────┐
│ │ transit_time = distance_km / avg_speed_kmh                    │
│ │ dwell_time = port_handling + customs_clearance                │
│ │ buffer = historical_delay_factor × confidence_interval        │
│ │ segment_time = transit_time + dwell_time + buffer             │
│ └───────────────────────────────────────────────────────────────┘
│
│ Mode transitions add transfer time:
│ ┌───────────────────────────────────────────────────────────────┐
│ │ MARITIME → RAIL: 24-48h (port crane + rail loading)           │
│ │ RAIL → ROAD: 4-8h (yard transfer)                             │
│ │ MARITIME → ROAD: 8-16h (port gate + trucking)                 │
│ └───────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │ time_hours: Duration
         ▼
┌─────────────────┐
│ 3.3.3 CARBON    │
│ CALCULATOR      │
│                 │
│ Per mode emission factors (kg CO2 per tonne-km):
│ ┌───────────────────────────────────────────────────────────────┐
│ │ MARITIME (container): 0.015 - 0.030                           │
│ │ RAIL (electric):      0.005 - 0.020                           │
│ │ RAIL (diesel):        0.025 - 0.040                           │
│ │ ROAD (truck):         0.060 - 0.150                           │
│ │ AIR (cargo):          0.500 - 1.200                           │
│ └───────────────────────────────────────────────────────────────┘
│
│ carbon_kg = Σ (segment_km × cargo_tonnes × emission_factor)
└────────┬────────┘
         │ carbon_kg: f64
         ▼
┌─────────────────┐
│ 3.3.4 LABOR     │
│ SCORER          │
│                 │
│ For each segment, score 0.0 - 1.0:
│ ┌───────────────────────────────────────────────────────────────┐
│ │ wage_score = min(1.0, actual_wage / (2 × min_wage))           │
│ │ hours_score = 1.0 - (weekly_hours - 40) / 40                  │
│ │ safety_score = carrier_safety_rating / 5.0                    │
│ │ union_score = 1.0 if unionized else 0.5                       │
│ │                                                               │
│ │ labor_score = 0.4×wage + 0.3×hours + 0.2×safety + 0.1×union   │
│ └───────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │ labor_score: f64
         ▼
┌─────────────────┐
│ 3.3.5 PARETO    │
│ RANKER          │
│                 │
│ ┌───────────────────────────────────────────────────────────────┐
│ │ For each pair of routes (A, B):                               │
│ │   A dominates B if:                                           │
│ │     A.cost ≤ B.cost AND                                       │
│ │     A.time ≤ B.time AND                                       │
│ │     A.carbon ≤ B.carbon AND                                   │
│ │     A.labor ≥ B.labor AND                                     │
│ │     at least one inequality is strict                         │
│ │                                                               │
│ │ Pareto frontier = routes not dominated by any other           │
│ └───────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │
         │ Vec<ScoredPath> with pareto_rank
         ▼
       TO 3.4 CONSTRAINT CHECKER
```

### 3.4 Constraint Checker - Hot Path Detail

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│              3.4 CONSTRAINT CHECKER - HOT PATH DETAIL                           │
└─────────────────────────────────────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────────────────────┐
  │                    CONSTRAINT CACHE LAYER                       │
  │                       (Dragonfly)                               │
  │                                                                 │
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
  │  │ Hard        │  │ Soft        │  │ Lookup      │             │
  │  │ Constraints │  │ Constraints │  │ Tables      │             │
  │  │             │  │             │  │             │             │
  │  │ • min_wage  │  │ • pref_mode │  │ • country   │             │
  │  │ • max_hours │  │ • carrier   │  │   → wage    │             │
  │  │ • hazmat    │  │   rating    │  │ • port      │             │
  │  │ • sanctions │  │ • carbon    │  │   → times   │             │
  │  │             │  │   target    │  │             │             │
  │  └─────────────┘  └─────────────┘  └─────────────┘             │
  │        │                │                │                      │
  └────────┼────────────────┼────────────────┼──────────────────────┘
           │ ~1μs           │                │
           ▼                ▼                ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                    RUST CONSTRAINT EVALUATOR                    │
  │                    (In-Process, No Network)                     │
  │                                                                 │
  │  ┌────────────────────────────────────────────────────────────┐ │
  │  │ fn evaluate_constraints(path: &Path) -> ConstraintResult   │ │
  │  │ {                                                          │ │
  │  │     // Step 1: Check hard constraints (fail-fast)          │ │
  │  │     for segment in &path.segments {                        │ │
  │  │         if segment.wage < min_wage[segment.country] {      │ │
  │  │             return ConstraintResult::HardFail("wage");     │ │
  │  │         }                                                  │ │
  │  │         if segment.weekly_hours > 60 {                     │ │
  │  │             return ConstraintResult::HardFail("hours");    │ │
  │  │         }                                                  │ │
  │  │         if is_sanctioned(segment.carrier) {                │ │
  │  │             return ConstraintResult::HardFail("sanction"); │ │
  │  │         }                                                  │ │
  │  │     }                                                      │ │
  │  │                                                            │ │
  │  │     // Step 2: Score soft constraints                      │ │
  │  │     let soft_score = compute_soft_score(path);             │ │
  │  │                                                            │ │
  │  │     ConstraintResult::Pass { soft_score }                  │ │
  │  │ }                                                          │ │
  │  └────────────────────────────────────────────────────────────┘ │
  │                                                                 │
  │  Execution time: ~5-10μs per route                              │
  └─────────────────────────────────────────────────────────────────┘
           │
           │ ConstraintResult
           ▼
  ┌─────────────────────────────────────────────────────────────────┐
  │                    CONSTRAINT SYNC (COLD PATH)                  │
  │                    Runs every 5 minutes                         │
  │                                                                 │
  │  ┌────────────────────────────────────────────────────────────┐ │
  │  │ Clojure/XTDB                                               │ │
  │  │                                                            │ │
  │  │ ;; Compile constraints to efficient lookup format          │ │
  │  │ (defn compile-constraints []                               │ │
  │  │   (let [rules (xt/q node                                   │ │
  │  │                 '{:find [?id ?type ?params]                │ │
  │  │                   :where [[?c :constraint/id ?id]          │ │
  │  │                           [?c :constraint/type ?type]      │ │
  │  │                           [?c :constraint/params ?params]  │ │
  │  │                           [?c :constraint/active? true]]})│ │
  │  │         lookup-tables (build-lookup-tables rules)]         │ │
  │  │     (push-to-dragonfly lookup-tables)))                    │ │
  │  └────────────────────────────────────────────────────────────┘ │
  │                              │                                  │
  │                              │ MessagePack (not JSON)           │
  │                              ▼                                  │
  │  ┌────────────────────────────────────────────────────────────┐ │
  │  │ Dragonfly                                                  │ │
  │  │                                                            │ │
  │  │ SET constraint:min_wage:DE 1260000  ; cents/month          │ │
  │  │ SET constraint:min_wage:FR 1398000                         │ │
  │  │ SET constraint:min_wage:CN  230000                         │ │
  │  │ SET constraint:max_hours:EU 48                             │ │
  │  │ SADD constraint:sanctioned:carriers "BADCO" "EVILSHIP"     │ │
  │  └────────────────────────────────────────────────────────────┘ │
  └─────────────────────────────────────────────────────────────────┘
```

---

## 2.0 CONSTRAINT ENGINE - Datalog Compilation Detail

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 2.2 DATALOG COMPILER (DETAILED)                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

  USER CONSTRAINT DEFINITION (DSL)
       │
       │ "For all segments where country = 'DE', wage >= €12.60/hour"
       ▼
┌─────────────────┐
│ 2.2.1 LEXER     │
│                 │
│ Tokens:         │
│ • FOR_ALL       │
│ • SEGMENTS      │
│ • WHERE         │
│ • COUNTRY       │
│ • EQUALS        │
│ • STRING("DE")  │
│ • WAGE          │
│ • GTE           │
│ • CURRENCY(€)   │
│ • NUMBER(12.60) │
│ • PER_HOUR      │
└────────┬────────┘
         │
         │ Vec<Token>
         ▼
┌─────────────────┐
│ 2.2.2 PARSER    │
│                 │
│ AST:            │
│ ┌──────────────────────────────────────┐
│ │ Constraint {                         │
│ │   quantifier: ForAll,                │
│ │   entity: Segment,                   │
│ │   filter: Eq(country, "DE"),         │
│ │   predicate: Gte(wage, 1260)         │
│ │ }                                    │
│ └──────────────────────────────────────┘
└────────┬────────┘
         │
         │ ConstraintAST
         ▼
┌─────────────────┐
│ 2.2.3 TYPE      │
│ CHECKER         │
│                 │
│ Verify:         │
│ • 'country' is String
│ • 'wage' is Money   │
│ • Comparison valid  │
│ • Units compatible  │
└────────┬────────┘
         │
         │ TypedAST
         ▼
┌─────────────────┐
│ 2.2.4 DATALOG   │
│ EMITTER         │
│                 │
│ Output:         │
│ ┌──────────────────────────────────────────────────────────────┐
│ │ [:find ?segment ?violation                                   │
│ │  :in $ ?route-id                                             │
│ │  :where                                                      │
│ │  [?route :route/id ?route-id]                                │
│ │  [?route :route/segments ?segment]                           │
│ │  [?segment :segment/country "DE"]                            │
│ │  [?segment :segment/wage-cents ?wage]                        │
│ │  [(< ?wage 126000)]                                          │
│ │  [(identity ?segment) ?violation]]                           │
│ └──────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │
         │ Datalog Query
         ▼
┌─────────────────┐
│ 2.2.5 OPTIMIZER │
│                 │
│ Transformations:
│ • Predicate pushdown
│ • Join reordering
│ • Index hints
│ • Constant folding
└────────┬────────┘
         │
         │ Optimized Datalog + Lookup Tables
         ├──────────────────────────────────────┐
         │                                      │
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ XTDB (storage)  │                    │ Dragonfly       │
│                 │                    │ (hot cache)     │
│ • Full Datalog  │                    │                 │
│ • Bitemporal    │                    │ • Lookup tables │
│ • Audit trail   │                    │ • Fast eval     │
└─────────────────┘                    └─────────────────┘
```

---

## 4.0 FORMAL VERIFIER - Proof Generation Detail

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 4.3 PROOF ENGINE (DETAILED)                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

  ANNOTATED SPARK CODE (from 4.2)
       │
       │ .ads/.adb files with SPARK annotations
       ▼
┌─────────────────┐
│ 4.3.1 GNAT      │
│ FRONT-END       │
│                 │
│ • Parse Ada     │
│ • Type check    │
│ • Generate SPARK│
│   intermediate  │
└────────┬────────┘
         │
         │ SPARK IR
         ▼
┌─────────────────┐
│ 4.3.2 SPARK2014 │
│ FLOW ANALYSIS   │
│                 │
│ Check:          │
│ • No aliasing   │
│ • Data deps     │
│ • Init before   │
│   use           │
│ • No globals    │
│   in pure funcs │
└────────┬────────┘
         │
         │ Flow-clean IR
         ▼
┌─────────────────┐
│ 4.3.3 WHY3      │
│ GENERATOR       │
│                 │
│ Transform to    │
│ Why3 logic:     │
│ ┌────────────────────────────────────────────────────────────┐
│ │ theory Route_Wages                                         │
│ │                                                            │
│ │ use int.Int                                                │
│ │ use list.List                                              │
│ │                                                            │
│ │ type segment = {                                           │
│ │   wage_cents: int;                                         │
│ │   country: int;  (* country code *)                        │
│ │ }                                                          │
│ │                                                            │
│ │ function min_wage (c: int) : int                           │
│ │                                                            │
│ │ predicate valid_wage (s: segment) =                        │
│ │   s.wage_cents >= min_wage s.country                       │
│ │                                                            │
│ │ predicate all_wages_valid (segs: list segment) =           │
│ │   forall s. mem s segs -> valid_wage s                     │
│ │                                                            │
│ │ goal route_wages_proof:                                    │
│ │   forall route. all_wages_valid route.segments             │
│ │                                                            │
│ │ end                                                        │
│ └────────────────────────────────────────────────────────────┘
└────────┬────────┘
         │
         │ Why3 theory
         ▼
┌─────────────────┐
│ 4.3.4 SMT       │
│ DISPATCHER      │
│                 │
│ Try provers in  │
│ order:          │
│ 1. CVC5 (fast)  │
│ 2. Z3 (thorough)│
│ 3. Alt-Ergo     │
│                 │
│ Timeout: 30s/VC │
└────────┬────────┘
         │
         ├──── PROVED ──────────────────────────────────┐
         │                                              │
         ├──── TIMEOUT ──────┐                          │
         │                   │                          │
         ├──── UNKNOWN ──────┤                          │
         │                   │                          │
         ▼                   ▼                          ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────────────┐
│ 4.3.5 COUNTER-  │ │ 4.3.6 MANUAL    │ │ 4.3.7 CERTIFICATE       │
│ EXAMPLE         │ │ PROOF QUEUE     │ │ GENERATOR               │
│ GENERATOR       │ │                 │ │                         │
│                 │ │ • Flag for      │ │ ┌─────────────────────┐ │
│ • Extract model │ │   human review  │ │ │ {                   │ │
│ • Show failing  │ │ • Interactive   │ │ │   "route_id": "123",│ │
│   case          │ │   proof (Coq)   │ │ │   "property":       │ │
│                 │ │                 │ │ │     "all_wages_valid│ │
└─────────────────┘ └─────────────────┘ │ │   "status": "PROVEN"│ │
                                        │ │   "prover": "CVC5", │ │
                                        │ │   "time_ms": 1523,  │ │
                                        │ │   "hash": "a1b2c3", │ │
                                        │ │   "timestamp": ...  │ │
                                        │ │ }                   │ │
                                        │ └─────────────────────┘ │
                                        └─────────────────────────┘
```

---

## 6.0 TRACKING ENGINE - Real-Time Flow Detail

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                 6.0 TRACKING ENGINE - REAL-TIME DETAIL                          │
└─────────────────────────────────────────────────────────────────────────────────┘

  AIS/GPS STREAM
       │
       │ ~10,000 position updates/second (global fleet)
       ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.1.1 INGRESS LOAD BALANCER                                     │
│                                                                 │
│ Elixir GenStage with demand-based backpressure                  │
│                                                                 │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │ Stage 1 │ │ Stage 1 │ │ Stage 1 │ │ Stage 1 │ │ Stage 1 │    │
│ │ Worker  │ │ Worker  │ │ Worker  │ │ Worker  │ │ Worker  │    │
│ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘    │
│      │           │           │           │           │          │
│      └───────────┴───────────┴───────────┴───────────┘          │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
                               │ demand: 1000/worker
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.1.2 DEDUPLICATOR                                              │
│                                                                 │
│ Dragonfly HyperLogLog for duplicate detection                   │
│                                                                 │
│ Key: {vessel_id}:{timestamp_minute}                             │
│ If exists → drop (duplicate)                                    │
│ Else → add to HLL, pass through                                 │
│                                                                 │
│ Reduces ~10,000/s → ~3,000/s (unique positions)                 │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.2 SHIPMENT MATCHER                                            │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Dragonfly Geo Index                                         │ │
│ │                                                             │ │
│ │ GEOADD active:vessels {lon} {lat} {vessel_id}               │ │
│ │ GEOADD active:shipments {lon} {lat} {shipment_id}           │ │
│ │                                                             │ │
│ │ For each position update:                                   │ │
│ │   1. Update vessel position                                 │ │
│ │   2. GEORADIUS to find shipments on this vessel             │ │
│ │   3. Emit matched (shipment_id, position, timestamp)        │ │
│ └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ matched positions
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.3 ETA CALCULATOR                                              │
│                                                                 │
│ For each shipment position update:                              │
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ current_segment = find_segment(shipment, position)          │ │
│ │ remaining_distance = segment.end - position                 │ │
│ │                                                             │ │
│ │ # Historical speed for this route                           │ │
│ │ avg_speed = dragonfly.get("speed:{route}:{segment}")        │ │
│ │                                                             │ │
│ │ # Weather adjustment from external API                      │ │
│ │ weather_factor = weather_service.get_factor(position)       │ │
│ │                                                             │ │
│ │ eta_segment = remaining_distance / (avg_speed * weather)    │ │
│ │ eta_total = eta_segment + sum(remaining_segments.eta)       │ │
│ │                                                             │ │
│ │ # Compare to promised ETA                                   │ │
│ │ delay = eta_total - promised_eta                            │ │
│ └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ (shipment_id, eta, delay)
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.4 ALERT GENERATOR                                             │
│                                                                 │
│ Thresholds:                                                     │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ DELAY_WARNING:  delay > 2 hours                             │ │
│ │ DELAY_CRITICAL: delay > 8 hours                             │ │
│ │ DEVIATION:      distance_from_route > 50 km                 │ │
│ │ CONSTRAINT:     any hard constraint now violated            │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ If threshold crossed:                                           │
│   1. Create Alert record                                        │
│   2. Push to Phoenix.PubSub                                     │
│   3. Trigger re-routing if CRITICAL                             │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ alerts + position updates
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6.6 EVENT BROADCASTER                                           │
│                                                                 │
│ Phoenix.PubSub Topics:                                          │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ "tracking:shipment:{id}"     → position updates             │ │
│ │ "tracking:alerts:{id}"       → delay/deviation alerts       │ │
│ │ "tracking:all"               → firehose (admin only)        │ │
│ │ "analytics:positions"        → aggregated for 8.0           │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ WebSocket push to connected clients                             │
│ Latency target: <100ms from position received to client push    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Hot Path Performance Budget

| Stage | Target Latency | Technology | Notes |
|-------|---------------|------------|-------|
| Position ingestion | <1ms | Elixir GenStage | Backpressure managed |
| Deduplication | <0.1ms | Dragonfly HLL | In-memory |
| Shipment matching | <1ms | Dragonfly Geo | Geo-indexed |
| ETA calculation | <5ms | Rust (if needed) | Could be Elixir |
| Alert check | <0.5ms | Elixir pattern match | Simple conditionals |
| PubSub broadcast | <10ms | Phoenix.PubSub | In-process |
| WebSocket push | <50ms | Phoenix Channels | Network bound |
| **Total (ingress → client)** | **<100ms** | | Target met |

| Stage | Target Latency | Technology | Notes |
|-------|---------------|------------|-------|
| Route optimization (cold) | <500ms | Rust | First route for request |
| Constraint eval (hot) | <10μs | Rust + Dragonfly | Per-route |
| Graph lookup | <1ms | SurrealDB | Indexed |
| Formal proof | <30s | SPARK/Why3 | Async, not in hot path |
