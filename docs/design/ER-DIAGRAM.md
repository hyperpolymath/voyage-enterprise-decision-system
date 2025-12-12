# VEDS Entity-Relationship Diagram

## Overview

This document defines the core entities and their relationships across all three data stores.
VEDS uses a polyglot persistence strategy with entities distributed based on query patterns.

---

## Data Store Mapping

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         ENTITY → DATA STORE MAPPING                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│   XTDB (Bitemporal)              SurrealDB (Graph/Doc)       Dragonfly (Cache) │
│   ══════════════════             ═══════════════════════     ════════════════  │
│                                                                                 │
│   • Decision                     • TransportNode             • Position (TTL)  │
│   • Constraint                   • TransportEdge             • Rate (TTL)      │
│   • ConstraintEvaluation         • Shipment                  • Session         │
│   • AuditEntry                   • Carrier                   • ConstraintLookup│
│   • ProofCertificate             • Route                     • HotRoute        │
│                                  • Segment                                     │
│                                  • CargoType                                   │
│                                  • Port                                        │
│                                  • Country                                     │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Master ER Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              VEDS ER DIAGRAM                                    │
└─────────────────────────────────────────────────────────────────────────────────┘


                              REFERENCE DATA
    ┌──────────────────────────────────────────────────────────────┐
    │                                                              │
    │  ┌─────────────┐        ┌─────────────┐      ┌───────────┐  │
    │  │  Country    │        │  Port       │      │ CargoType │  │
    │  │ ─────────── │        │ ─────────── │      │ ───────── │  │
    │  │ PK code     │◄───────│ PK id       │      │ PK id     │  │
    │  │    name     │        │ FK country  │      │    name   │  │
    │  │    min_wage │        │    name     │      │    hazmat │  │
    │  │    max_hours│        │    lat/lon  │      │    temp   │  │
    │  │    currency │        │    timezone │      │    stackbl│  │
    │  └─────────────┘        │    type     │      └───────────┘  │
    │         │               └──────┬──────┘            │        │
    │         │                      │                   │        │
    └─────────┼──────────────────────┼───────────────────┼────────┘
              │                      │                   │
              │                      │                   │
              ▼                      ▼                   │
    ┌─────────────────────────────────────────────────────────────┐
    │                    TRANSPORT NETWORK (Graph)                │
    │                                                             │
    │  ┌─────────────────┐           ┌─────────────────────────┐  │
    │  │ TransportNode   │           │ TransportEdge           │  │
    │  │ ─────────────── │           │ ─────────────────────── │  │
    │  │ PK id           │◄──────────│ PK id                   │  │
    │  │ FK port_id      │           │ FK from_node            │  │
    │  │    type (HUB/   │           │ FK to_node              │  │
    │  │      TERMINAL)  │           │ FK carrier_id           │  │
    │  │    modes[]      │           │    mode (MARITIME/RAIL/ │  │
    │  │    capacity     │◄──────────│         ROAD/AIR)       │  │
    │  └─────────────────┘           │    distance_km          │  │
    │                                │    base_cost_usd        │  │
    │                                │    transit_hours        │  │
    │                                │    carbon_per_tonne_km  │  │
    │                                │    schedule             │  │
    │                                └────────────┬────────────┘  │
    │                                             │               │
    └─────────────────────────────────────────────┼───────────────┘
                                                  │
              ┌───────────────────────────────────┘
              │
              ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                         CARRIER                             │
    │                                                             │
    │  ┌─────────────────────────────────────────────────────┐    │
    │  │ Carrier                                             │    │
    │  │ ─────────────────────────────────────────────────── │    │
    │  │ PK id                                               │    │
    │  │    name                                             │    │
    │  │    type (SHIPPING_LINE/RAIL_OPERATOR/TRUCKING/      │    │
    │  │          AIRLINE)                                   │    │
    │  │    safety_rating (1-5)                              │    │
    │  │    unionized (bool)                                 │    │
    │  │    avg_wage_cents                                   │    │
    │  │    avg_weekly_hours                                 │    │
    │  │    sanctioned (bool)                                │    │
    │  │    api_endpoint                                     │    │
    │  │    api_credentials_ref                              │    │
    │  └─────────────────────────────────────────────────────┘    │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘


    ┌─────────────────────────────────────────────────────────────┐
    │                      SHIPMENT & ROUTING                     │
    │                                                             │
    │  ┌─────────────────┐                                        │
    │  │ Shipment        │                                        │
    │  │ ─────────────── │                                        │
    │  │ PK id           │                                        │
    │  │ FK shipper_id   │                                        │
    │  │ FK origin_port  │                                        │
    │  │ FK dest_port    │        ┌─────────────────────────┐     │
    │  │ FK cargo_type   │        │ Route                   │     │
    │  │    weight_kg    │        │ ───────────────────────│     │
    │  │    volume_m3    │◄───────│ PK id                   │     │
    │  │    value_usd    │        │ FK shipment_id          │     │
    │  │    pickup_after │        │    status (DRAFT/       │     │
    │  │    deliver_by   │        │      ACTIVE/COMPLETED)  │     │
    │  │    status       │        │    total_cost_usd       │     │
    │  │    created_at   │        │    total_time_hours     │     │
    │  └────────┬────────┘        │    total_carbon_kg      │     │
    │           │                 │    pareto_rank          │     │
    │           │                 │    verified (bool)      │     │
    │           │ constraints     │ FK proof_cert_id        │     │
    │           ▼                 │    created_at           │     │
    │  ┌─────────────────┐        └───────────┬─────────────┘     │
    │  │ShipmentConstraint        │             │                  │
    │  │ ─────────────── │        │             │ segments         │
    │  │ PK id           │        │             ▼                  │
    │  │ FK shipment_id  │        │   ┌─────────────────────────┐ │
    │  │ FK constraint_id│        │   │ Segment                 │ │
    │  │    priority     │        │   │ ─────────────────────── │ │
    │  │    hard (bool)  │        │   │ PK id                   │ │
    │  └─────────────────┘        │   │ FK route_id             │ │
    │           │                 │   │ FK edge_id              │ │
    │           │ references      │   │    sequence_num         │ │
    │           ▼                 │   │    departure_time       │ │
    │  ┌─────────────────┐        │   │    arrival_time         │ │
    │  │ Constraint      │        │   │    cost_usd             │ │
    │  │ (XTDB)          │        │   │    carbon_kg            │ │
    │  │ ─────────────── │        │   │    carrier_wage_cents   │ │
    │  │ PK id           │        │   │    status               │ │
    │  │    type         │        │   └─────────────────────────┘ │
    │  │    name         │        │                               │
    │  │    datalog_rule │        │                               │
    │  │    params (JSON)│        │                               │
    │  │    active (bool)│        │                               │
    │  │    valid_from   │        │                               │
    │  │    valid_to     │        │                               │
    │  └─────────────────┘        │                               │
    │                             │                               │
    └─────────────────────────────┼───────────────────────────────┘
                                  │
                                  │
                                  ▼
    ┌─────────────────────────────────────────────────────────────┐
    │                    TRACKING & POSITIONS                     │
    │                                                             │
    │  ┌─────────────────────────┐     ┌─────────────────────┐    │
    │  │ Position (Dragonfly)   │     │ TrackingEvent       │    │
    │  │ ─────────────────────── │     │ ─────────────────── │    │
    │  │ KEY vessel:{id}:pos    │     │ PK id               │    │
    │  │     lat                │     │ FK shipment_id      │    │
    │  │     lon                │     │ FK segment_id       │    │
    │  │     heading            │     │    event_type       │    │
    │  │     speed_knots        │     │    (DEPARTED/       │    │
    │  │     timestamp          │     │     ARRIVED/        │    │
    │  │     TTL: 5 min         │     │     DELAYED/        │    │
    │  └─────────────────────────┘     │     ALERT)          │    │
    │                                  │    timestamp        │    │
    │  ┌─────────────────────────┐     │    details (JSON)   │    │
    │  │ ETA (Dragonfly)        │     └─────────────────────┘    │
    │  │ ─────────────────────── │                                │
    │  │ KEY shipment:{id}:eta  │                                │
    │  │     segment_id         │                                │
    │  │     eta_timestamp      │                                │
    │  │     confidence         │                                │
    │  │     delay_minutes      │                                │
    │  │     TTL: 1 min         │                                │
    │  └─────────────────────────┘                                │
    │                                                             │
    └─────────────────────────────────────────────────────────────┘


    ┌─────────────────────────────────────────────────────────────┐
    │                    AUDIT & VERIFICATION                     │
    │                    (XTDB - Bitemporal)                      │
    │                                                             │
    │  ┌─────────────────────────┐     ┌─────────────────────────┐│
    │  │ Decision                │     │ ConstraintEvaluation    ││
    │  │ ─────────────────────── │     │ ─────────────────────── ││
    │  │ PK id                   │◄────│ PK id                   ││
    │  │ FK route_id             │     │ FK decision_id          ││
    │  │    decision_type        │     │ FK constraint_id        ││
    │  │    rationale            │     │    result (PASS/FAIL)   ││
    │  │    alternatives_count   │     │    score (0.0-1.0)      ││
    │  │    user_id              │     │    details (JSON)       ││
    │  │    valid_time           │     │    evaluated_at         ││
    │  │    tx_time              │     │    valid_time           ││
    │  └─────────────────────────┘     │    tx_time              ││
    │                                  └─────────────────────────┘│
    │                                                             │
    │  ┌─────────────────────────┐     ┌─────────────────────────┐│
    │  │ ProofCertificate       │     │ AuditEntry              ││
    │  │ ─────────────────────── │     │ ─────────────────────── ││
    │  │ PK id                   │     │ PK id                   ││
    │  │ FK route_id             │     │    entity_type          ││
    │  │    properties[]         │     │    entity_id            ││
    │  │    prover (CVC5/Z3)     │     │    action (CREATE/      ││
    │  │    proof_time_ms        │     │      UPDATE/DELETE)     ││
    │  │    status (PROVEN/      │     │    old_value (JSON)     ││
    │  │      UNPROVEN/TIMEOUT)  │     │    new_value (JSON)     ││
    │  │    certificate_hash     │     │    user_id              ││
    │  │    created_at           │     │    reason               ││
    │  │    valid_time           │     │    valid_time           ││
    │  │    tx_time              │     │    tx_time              ││
    │  └─────────────────────────┘     └─────────────────────────┘│
    │                                                             │
    └─────────────────────────────────────────────────────────────┘
```

---

## Detailed Entity Definitions

### SurrealDB Entities (SurrealQL Schema)

```surql
-- Reference Data
DEFINE TABLE country SCHEMAFULL;
DEFINE FIELD code ON country TYPE string ASSERT $value = /^[A-Z]{2}$/;
DEFINE FIELD name ON country TYPE string;
DEFINE FIELD min_wage_cents ON country TYPE int;
DEFINE FIELD max_weekly_hours ON country TYPE int;
DEFINE FIELD currency ON country TYPE string;
DEFINE INDEX idx_country_code ON country FIELDS code UNIQUE;

DEFINE TABLE port SCHEMAFULL;
DEFINE FIELD id ON port TYPE string;
DEFINE FIELD country ON port TYPE record(country);
DEFINE FIELD name ON port TYPE string;
DEFINE FIELD unlocode ON port TYPE string;
DEFINE FIELD location ON port TYPE geometry(point);
DEFINE FIELD timezone ON port TYPE string;
DEFINE FIELD port_type ON port TYPE string ASSERT $value IN ['SEAPORT', 'RAILYARD', 'AIRPORT', 'INLAND'];
DEFINE INDEX idx_port_unlocode ON port FIELDS unlocode UNIQUE;
DEFINE INDEX idx_port_location ON port FIELDS location;

DEFINE TABLE cargo_type SCHEMAFULL;
DEFINE FIELD id ON cargo_type TYPE string;
DEFINE FIELD name ON cargo_type TYPE string;
DEFINE FIELD hazmat_class ON cargo_type TYPE option<string>;
DEFINE FIELD temp_min_c ON cargo_type TYPE option<float>;
DEFINE FIELD temp_max_c ON cargo_type TYPE option<float>;
DEFINE FIELD stackable ON cargo_type TYPE bool DEFAULT true;

-- Transport Network (Graph)
DEFINE TABLE transport_node SCHEMAFULL;
DEFINE FIELD id ON transport_node TYPE string;
DEFINE FIELD port ON transport_node TYPE record(port);
DEFINE FIELD node_type ON transport_node TYPE string ASSERT $value IN ['HUB', 'TERMINAL', 'WAYPOINT'];
DEFINE FIELD modes ON transport_node TYPE array<string>;
DEFINE FIELD capacity_teu ON transport_node TYPE int;

DEFINE TABLE transport_edge SCHEMAFULL;
DEFINE FIELD id ON transport_edge TYPE string;
DEFINE FIELD in ON transport_edge TYPE record(transport_node);
DEFINE FIELD out ON transport_edge TYPE record(transport_node);
DEFINE FIELD carrier ON transport_edge TYPE record(carrier);
DEFINE FIELD mode ON transport_edge TYPE string ASSERT $value IN ['MARITIME', 'RAIL', 'ROAD', 'AIR'];
DEFINE FIELD distance_km ON transport_edge TYPE float;
DEFINE FIELD base_cost_usd ON transport_edge TYPE decimal;
DEFINE FIELD transit_hours ON transport_edge TYPE float;
DEFINE FIELD carbon_kg_per_tonne_km ON transport_edge TYPE float;
DEFINE FIELD schedule ON transport_edge TYPE object; -- JSON schedule

-- Carrier
DEFINE TABLE carrier SCHEMAFULL;
DEFINE FIELD id ON carrier TYPE string;
DEFINE FIELD name ON carrier TYPE string;
DEFINE FIELD carrier_type ON carrier TYPE string;
DEFINE FIELD safety_rating ON carrier TYPE int ASSERT $value >= 1 AND $value <= 5;
DEFINE FIELD unionized ON carrier TYPE bool DEFAULT false;
DEFINE FIELD avg_wage_cents ON carrier TYPE int;
DEFINE FIELD avg_weekly_hours ON carrier TYPE float;
DEFINE FIELD sanctioned ON carrier TYPE bool DEFAULT false;
DEFINE FIELD api_endpoint ON carrier TYPE option<string>;

-- Shipment & Routing
DEFINE TABLE shipment SCHEMAFULL;
DEFINE FIELD id ON shipment TYPE string;
DEFINE FIELD shipper_id ON shipment TYPE string;
DEFINE FIELD origin ON shipment TYPE record(port);
DEFINE FIELD destination ON shipment TYPE record(port);
DEFINE FIELD cargo_type ON shipment TYPE record(cargo_type);
DEFINE FIELD weight_kg ON shipment TYPE float;
DEFINE FIELD volume_m3 ON shipment TYPE float;
DEFINE FIELD value_usd ON shipment TYPE decimal;
DEFINE FIELD pickup_after ON shipment TYPE datetime;
DEFINE FIELD deliver_by ON shipment TYPE datetime;
DEFINE FIELD status ON shipment TYPE string ASSERT $value IN ['DRAFT', 'OPTIMIZING', 'ROUTED', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'];
DEFINE FIELD created_at ON shipment TYPE datetime DEFAULT time::now();

DEFINE TABLE route SCHEMAFULL;
DEFINE FIELD id ON route TYPE string;
DEFINE FIELD shipment ON route TYPE record(shipment);
DEFINE FIELD status ON route TYPE string;
DEFINE FIELD total_cost_usd ON route TYPE decimal;
DEFINE FIELD total_time_hours ON route TYPE float;
DEFINE FIELD total_carbon_kg ON route TYPE float;
DEFINE FIELD pareto_rank ON route TYPE int;
DEFINE FIELD verified ON route TYPE bool DEFAULT false;
DEFINE FIELD proof_cert_id ON route TYPE option<string>;
DEFINE FIELD created_at ON route TYPE datetime DEFAULT time::now();

DEFINE TABLE segment SCHEMAFULL;
DEFINE FIELD id ON segment TYPE string;
DEFINE FIELD route ON segment TYPE record(route);
DEFINE FIELD edge ON segment TYPE record(transport_edge);
DEFINE FIELD sequence_num ON segment TYPE int;
DEFINE FIELD departure_time ON segment TYPE datetime;
DEFINE FIELD arrival_time ON segment TYPE datetime;
DEFINE FIELD cost_usd ON segment TYPE decimal;
DEFINE FIELD carbon_kg ON segment TYPE float;
DEFINE FIELD carrier_wage_cents ON segment TYPE int;
DEFINE FIELD status ON segment TYPE string;

-- Tracking
DEFINE TABLE tracking_event SCHEMAFULL;
DEFINE FIELD id ON tracking_event TYPE string;
DEFINE FIELD shipment ON tracking_event TYPE record(shipment);
DEFINE FIELD segment ON tracking_event TYPE option<record(segment)>;
DEFINE FIELD event_type ON tracking_event TYPE string ASSERT $value IN ['DEPARTED', 'ARRIVED', 'DELAYED', 'ALERT', 'POSITION'];
DEFINE FIELD timestamp ON tracking_event TYPE datetime;
DEFINE FIELD location ON tracking_event TYPE option<geometry(point)>;
DEFINE FIELD details ON tracking_event TYPE object;
DEFINE INDEX idx_tracking_shipment ON tracking_event FIELDS shipment, timestamp;
```

### XTDB Entities (Clojure/Datalog Schema)

```clojure
;; Constraint definition
{:xt/id :constraint/wage-germany
 :constraint/id "wage-germany"
 :constraint/type :wage-minimum
 :constraint/name "Germany Minimum Wage"
 :constraint/datalog-rule
 '[:find ?segment ?violation
   :in $ ?route-id
   :where
   [?route :route/id ?route-id]
   [?route :route/segments ?segment]
   [?segment :segment/country "DE"]
   [?segment :segment/wage-cents ?wage]
   [(< ?wage 126000)]
   [(identity ?segment) ?violation]]
 :constraint/params {:country "DE" :min-wage-cents 126000}
 :constraint/active? true
 :constraint/valid-from #inst "2024-01-01"
 :constraint/valid-to #inst "2099-12-31"}

;; Decision record
{:xt/id :decision/abc123
 :decision/id "abc123"
 :decision/route-id "route-456"
 :decision/type :route-selection
 :decision/rationale "Selected based on cost/carbon Pareto optimality"
 :decision/alternatives-count 5
 :decision/user-id "system"
 :decision/constraint-evaluations [:eval/e1 :eval/e2 :eval/e3]}

;; Constraint evaluation
{:xt/id :eval/e1
 :evaluation/id "e1"
 :evaluation/decision-id "abc123"
 :evaluation/constraint-id "wage-germany"
 :evaluation/result :pass
 :evaluation/score 1.0
 :evaluation/details {:segments-checked 3 :all-valid true}
 :evaluation/evaluated-at #inst "2025-12-06T10:30:00Z"}

;; Proof certificate
{:xt/id :proof/p1
 :proof/id "p1"
 :proof/route-id "route-456"
 :proof/properties ["all-wages-valid" "carbon-under-budget" "time-within-window"]
 :proof/prover :cvc5
 :proof/time-ms 1523
 :proof/status :proven
 :proof/certificate-hash "sha256:a1b2c3d4..."
 :proof/created-at #inst "2025-12-06T10:30:05Z"}

;; Audit entry
{:xt/id :audit/a1
 :audit/id "a1"
 :audit/entity-type :constraint
 :audit/entity-id "wage-germany"
 :audit/action :update
 :audit/old-value {:min-wage-cents 106000}
 :audit/new-value {:min-wage-cents 126000}
 :audit/user-id "admin@company.com"
 :audit/reason "Germany minimum wage increased Jan 2024"
 :audit/timestamp #inst "2024-01-01T00:00:00Z"}
```

### Dragonfly Keys (Redis-compatible)

```
# Position tracking (TTL: 5 minutes)
vessel:{vessel_id}:pos -> HASH { lat, lon, heading, speed, ts }
shipment:{shipment_id}:vessel -> STRING vessel_id

# ETA cache (TTL: 1 minute)
shipment:{shipment_id}:eta -> HASH { segment_id, eta_ts, confidence, delay_min }

# Rate cache (TTL: 15 minutes)
rate:{carrier}:{from}:{to}:{mode} -> HASH { base_usd, fuel_surcharge, updated_at }

# Constraint lookup (TTL: 5 minutes, refreshed by Clojure sync)
constraint:min_wage:{country} -> STRING cents_per_month
constraint:max_hours:{region} -> STRING hours_per_week
constraint:sanctioned:carriers -> SET { carrier_id, ... }

# Session (TTL: 24 hours)
session:{session_id} -> HASH { user_id, permissions, expires_at }

# Hot routes (TTL: 1 hour)
hot_route:{origin}:{dest} -> ZSET { route_id -> score }

# Geo index (no TTL)
GEOADD geo:vessels {lon} {lat} {vessel_id}
GEOADD geo:ports {lon} {lat} {port_id}
```

---

## Relationship Summary

| From | To | Relationship | Cardinality |
|------|-----|--------------|-------------|
| Port | Country | belongs_to | N:1 |
| TransportNode | Port | located_at | 1:1 |
| TransportEdge | TransportNode | from/to | N:1 |
| TransportEdge | Carrier | operated_by | N:1 |
| Shipment | Port | origin/destination | N:1 |
| Shipment | CargoType | contains | N:1 |
| Route | Shipment | for | N:1 |
| Segment | Route | part_of | N:1 |
| Segment | TransportEdge | uses | N:1 |
| Decision | Route | selects | N:1 |
| ConstraintEvaluation | Decision | part_of | N:1 |
| ConstraintEvaluation | Constraint | evaluates | N:1 |
| ProofCertificate | Route | proves | 1:1 |
| TrackingEvent | Shipment | tracks | N:1 |

---

## VoID Vocabulary Alignment

```turtle
@prefix void: <https://rdfs.org/ns/void#> .
@prefix veds: <https://veds.example.org/vocab#> .
@prefix dct: <https://purl.org/dc/terms/> .

veds:TransportNetwork a void:Dataset ;
    dct:title "VEDS Transport Network" ;
    void:feature <https://www.w3.org/ns/formats/N-Triples> ;
    void:sparqlEndpoint <https://veds.example.org/sparql> ;
    void:exampleResource veds:port/NLRTM ;
    void:vocabulary <https://www.w3.org/2003/01/geo/wgs84_pos#> ;
    void:subset veds:Ports, veds:Edges, veds:Carriers .

veds:Ports a void:Dataset ;
    void:class veds:Port ;
    void:entities 5000 .

veds:Edges a void:Dataset ;
    void:class veds:TransportEdge ;
    void:entities 50000 .

veds:Decisions a void:Dataset ;
    dct:title "VEDS Decision Audit Trail" ;
    void:feature <https://www.w3.org/ns/formats/N-Quads> ; # bitemporality
    void:class veds:Decision ;
    void:subset veds:Constraints, veds:Evaluations, veds:Proofs .
```
