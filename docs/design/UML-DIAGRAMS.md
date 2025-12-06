# VEDS UML Diagrams

## Overview

This document contains UML diagrams for VEDS:
1. **Use Case Diagrams** - Actor interactions
2. **Sequence Diagrams** - Key workflows
3. **State Machine Diagrams** - Entity lifecycles
4. **Component Diagrams** - System architecture
5. **Activity Diagrams** - Process flows

---

## 1. Use Case Diagrams

### 1.1 Primary Actors & Use Cases

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          VEDS USE CASE DIAGRAM                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

                              ┌───────────────────────────────────────────┐
                              │                  V E D S                  │
     ┌───────┐                │                                           │
     │       │                │  ┌─────────────────────────────────────┐  │
     │SHIPPER│────────────────┼─►│ UC1: Create Shipment Request       │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                    │                      │
     │       │                │                    │ «include»            │
     │       │                │                    ▼                      │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC2: Optimize Route                 │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                    │                      │
     │       │                │                    │ «include»            │
     │       │                │                    ▼                      │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC3: Track Shipment                 │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC4: View Carbon Report             │  │
     └───────┘                │  └─────────────────────────────────────┘  │
                              │                                           │
     ┌───────┐                │  ┌─────────────────────────────────────┐  │
     │       │────────────────┼─►│ UC5: Update Position                │  │
     │CARRIER│                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC6: Confirm Pickup/Delivery        │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     └───────┘                │  │ UC7: Report Delay                   │  │
                              │  └─────────────────────────────────────┘  │
                              │                                           │
     ┌───────┐                │  ┌─────────────────────────────────────┐  │
     │POLICY │────────────────┼─►│ UC8: Define Constraint              │  │
     │ ADMIN │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC9: Update Labor Rules             │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     └───────┘                │  │ UC10: Set Carbon Budgets            │  │
                              │  └─────────────────────────────────────┘  │
                              │                                           │
     ┌───────┐                │  ┌─────────────────────────────────────┐  │
     │       │────────────────┼─►│ UC11: Query Decision History        │  │
     │AUDITOR│                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC12: Request Proof Certificate     │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     └───────┘                │  │ UC13: Bitemporal Query ("as of")    │  │
                              │  └─────────────────────────────────────┘  │
                              │                                           │
     ┌───────┐                │  ┌─────────────────────────────────────┐  │
     │       │────────────────┼─►│ UC14: View Network Visualization    │  │
     │ANALYST│                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC15: Generate Analytics Report     │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     └───────┘                │  │ UC16: Forecast Demand               │  │
                              │  └─────────────────────────────────────┘  │
                              │                                           │
     ┌───────┐                │  ┌─────────────────────────────────────┐  │
     │SYSTEM │────────────────┼─►│ UC17: Ingest External Rates         │  │
     │ TIMER │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     │       │                │  │ UC18: Sync Constraints to Cache     │  │
     │       │                │  └─────────────────────────────────────┘  │
     │       │                │                                           │
     │       │────────────────┼─►┌─────────────────────────────────────┐  │
     └───────┘                │  │ UC19: Generate Formal Proofs        │  │
                              │  └─────────────────────────────────────┘  │
                              │                                           │
                              └───────────────────────────────────────────┘
```

### 1.2 Use Case Details

| UC# | Name | Primary Actor | Description | Preconditions | Postconditions |
|-----|------|---------------|-------------|---------------|----------------|
| UC1 | Create Shipment | Shipper | Submit cargo details, origin/dest, constraints | Authenticated | Shipment in DRAFT |
| UC2 | Optimize Route | Shipper | Request optimal multimodal route | Shipment exists | Route(s) generated |
| UC3 | Track Shipment | Shipper | Real-time position and ETA | Route active | Position displayed |
| UC4 | View Carbon Report | Shipper | See carbon footprint of shipment | Route exists | Report generated |
| UC5 | Update Position | Carrier | Push GPS/AIS position | Carrier registered | Position cached |
| UC6 | Confirm Pickup/Delivery | Carrier | Mark segment start/end | Segment assigned | Status updated |
| UC7 | Report Delay | Carrier | Notify of delay with reason | Segment in transit | Alert generated |
| UC8 | Define Constraint | Policy Admin | Create new business rule | Admin role | Constraint active |
| UC9 | Update Labor Rules | Policy Admin | Modify wage/hours limits | Admin role | Rules updated |
| UC10 | Set Carbon Budgets | Policy Admin | Define carbon limits | Admin role | Budgets active |
| UC11 | Query Decision History | Auditor | Search past decisions | Auditor role | Results returned |
| UC12 | Request Proof Certificate | Auditor | Get formal verification | Route verified | Certificate returned |
| UC13 | Bitemporal Query | Auditor | Query "as of" specific time | Auditor role | Historical view |
| UC14 | View Network Viz | Analyst | Interactive transport graph | - | Visualization |
| UC15 | Generate Analytics | Analyst | Create custom reports | - | Report generated |
| UC16 | Forecast Demand | Analyst | Predict future volumes | Historical data | Forecast model |
| UC17 | Ingest Rates | System | Pull rates from APIs | API configured | Rates cached |
| UC18 | Sync Constraints | System | Push rules to cache | Rules exist | Cache updated |
| UC19 | Generate Proofs | System | Run formal verifier | Route pending | Proof generated |

---

## 2. Sequence Diagrams

### 2.1 UC2: Optimize Route (Main Success Scenario)

```
┌───────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐
│Shipper│     │ API       │     │ Optimizer │     │ Constraint│     │ Verifier  │     │ Decision  │
│       │     │ Gateway   │     │ (Rust)    │     │ (Clojure) │     │ (Ada)     │     │ Store     │
└───┬───┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
    │               │                 │                 │                 │                 │
    │ POST /routes  │                 │                 │                 │                 │
    │ {shipment_id} │                 │                 │                 │                 │
    │──────────────►│                 │                 │                 │                 │
    │               │                 │                 │                 │                 │
    │               │ optimize(req)   │                 │                 │                 │
    │               │────────────────►│                 │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ load_graph()    │                 │                 │
    │               │                 │─────────────────┼─────────────────┼────────────────►│
    │               │                 │                 │                 │                 │
    │               │                 │◄────────────────┼─────────────────┼─────────────────│
    │               │                 │ graph           │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ find_paths()    │                 │                 │
    │               │                 │────────┐        │                 │                 │
    │               │                 │        │        │                 │                 │
    │               │                 │◄───────┘        │                 │                 │
    │               │                 │ candidates[10]  │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ evaluate()      │                 │                 │
    │               │                 │────────────────►│                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │                 │ query_xtdb()    │                 │
    │               │                 │                 │─────────────────┼────────────────►│
    │               │                 │                 │                 │                 │
    │               │                 │                 │◄────────────────┼─────────────────│
    │               │                 │                 │ rules           │                 │
    │               │                 │                 │                 │                 │
    │               │                 │◄────────────────│                 │                 │
    │               │                 │ results[10]     │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ (filter failed) │                 │                 │
    │               │                 │────────┐        │                 │                 │
    │               │                 │        │        │                 │                 │
    │               │                 │◄───────┘        │                 │                 │
    │               │                 │ valid[5]        │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ verify(top_route)                 │                 │
    │               │                 │─────────────────┼────────────────►│                 │
    │               │                 │                 │                 │                 │
    │               │                 │                 │                 │ prove()         │
    │               │                 │                 │                 │────────┐        │
    │               │                 │                 │                 │        │        │
    │               │                 │                 │                 │◄───────┘        │
    │               │                 │                 │                 │ certificate     │
    │               │                 │                 │                 │                 │
    │               │                 │◄────────────────┼─────────────────│                 │
    │               │                 │ proof           │                 │                 │
    │               │                 │                 │                 │                 │
    │               │                 │ store_decision()│                 │                 │
    │               │                 │─────────────────┼─────────────────┼────────────────►│
    │               │                 │                 │                 │                 │
    │               │                 │◄────────────────┼─────────────────┼─────────────────│
    │               │                 │ ack             │                 │                 │
    │               │                 │                 │                 │                 │
    │               │◄────────────────│                 │                 │                 │
    │               │ routes[5]       │                 │                 │                 │
    │               │                 │                 │                 │                 │
    │◄──────────────│                 │                 │                 │                 │
    │ 200 OK        │                 │                 │                 │                 │
    │ {routes: [...]}                 │                 │                 │                 │
    │               │                 │                 │                 │                 │
```

### 2.2 UC3: Track Shipment (Real-Time WebSocket)

```
┌───────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐
│Shipper│     │ API       │     │ Tracking  │     │ Dragonfly │
│  (WS) │     │ Gateway   │     │ Engine    │     │           │
└───┬───┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
    │               │                 │                 │
    │ WS: subscribe │                 │                 │
    │ {shipment_id} │                 │                 │
    │──────────────►│                 │                 │
    │               │                 │                 │
    │               │ Phoenix.PubSub  │                 │
    │               │ subscribe       │                 │
    │               │────────────────►│                 │
    │               │                 │                 │
    │◄──────────────│                 │                 │
    │ WS: subscribed│                 │                 │
    │               │                 │                 │
    ════════════════╪═════════════════╪═════════════════╪══════════════
    │ (time passes) │                 │                 │
    ════════════════╪═════════════════╪═════════════════╪══════════════
    │               │                 │                 │
    │               │                 │ AIS position    │
    │               │                 │◄────────────────│ (external)
    │               │                 │                 │
    │               │                 │ GEOADD          │
    │               │                 │────────────────►│
    │               │                 │                 │
    │               │                 │ calc_eta()      │
    │               │                 │────────┐        │
    │               │                 │        │        │
    │               │                 │◄───────┘        │
    │               │                 │                 │
    │               │ PubSub.broadcast│                 │
    │               │◄────────────────│                 │
    │               │ {pos, eta}      │                 │
    │               │                 │                 │
    │◄──────────────│                 │                 │
    │ WS: position  │                 │                 │
    │ {lat, lon,    │                 │                 │
    │  eta, delay}  │                 │                 │
    │               │                 │                 │
```

### 2.3 UC18: Constraint Sync (Hot Path Setup)

```
┌───────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐
│ Scheduler │     │ Constraint│     │   XTDB    │     │ Dragonfly │
│ (Elixir)  │     │ (Clojure) │     │           │     │           │
└─────┬─────┘     └─────┬─────┘     └─────┬─────┘     └─────┬─────┘
      │                 │                 │                 │
      │ :tick (5 min)   │                 │                 │
      │────────────────►│                 │                 │
      │                 │                 │                 │
      │                 │ query_active()  │                 │
      │                 │────────────────►│                 │
      │                 │                 │                 │
      │                 │◄────────────────│                 │
      │                 │ constraints[]   │                 │
      │                 │                 │                 │
      │                 │ compile()       │                 │
      │                 │────────┐        │                 │
      │                 │        │        │                 │
      │                 │◄───────┘        │                 │
      │                 │ lookup_tables   │                 │
      │                 │                 │                 │
      │                 │ MSET (msgpack)  │                 │
      │                 │─────────────────┼────────────────►│
      │                 │                 │                 │
      │                 │◄────────────────┼─────────────────│
      │                 │ OK              │                 │
      │                 │                 │                 │
      │                 │ PUBLISH sync:done                 │
      │                 │─────────────────┼────────────────►│
      │                 │                 │                 │
      │◄────────────────│                 │                 │
      │ :ok             │                 │                 │
      │                 │                 │                 │
```

---

## 3. State Machine Diagrams

### 3.1 Shipment Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        SHIPMENT STATE MACHINE                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

                              create()
                                 │
                                 ▼
                         ┌──────────────┐
                         │    DRAFT     │
                         │              │
                         │ • Editable   │
                         │ • No route   │
                         └──────┬───────┘
                                │ submit()
                                ▼
                         ┌──────────────┐
                         │  OPTIMIZING  │◄──────────────┐
                         │              │               │
                         │ • Finding    │               │ re_optimize()
                         │   routes     │               │
                         └──────┬───────┘               │
                                │ routes_found()        │
                                ▼                       │
                         ┌──────────────┐               │
         ┌──────────────►│   ROUTED     │───────────────┘
         │               │              │
         │ select_route()│ • Routes     │
         │               │   available  │
         │               │ • Awaiting   │
         │               │   selection  │
         │               └──────┬───────┘
         │                      │ confirm_route()
         │                      ▼
         │               ┌──────────────┐
         │               │   BOOKED     │
         │               │              │
         │               │ • Carrier    │
         │               │   notified   │
         │               │ • Awaiting   │
         │               │   pickup     │
         │               └──────┬───────┘
         │                      │ pickup_confirmed()
         │                      ▼
         │               ┌──────────────┐
         │               │  IN_TRANSIT  │◄──────┐
         │               │              │       │
         │               │ • Tracking   │       │ segment_completed()
         │               │   active     │       │ (not last)
         │               │ • ETAs       │       │
         │               │   updating   │───────┘
         │               └──────┬───────┘
         │                      │
         │      ┌───────────────┼───────────────┐
         │      │               │               │
         │      │ delay() +     │ delivery_     │ exception()
         │      │ re-route      │ confirmed()   │
         │      │ needed        │               │
         │      ▼               ▼               ▼
         │┌──────────────┐┌──────────────┐┌──────────────┐
         ││  REROUTING   ││  DELIVERED   ││  EXCEPTION   │
         ││              ││              ││              │
         ││ • Finding    ││ • Complete   ││ • Problem    │
         ││   new route  ││ • Billable   ││ • Requires   │
         ││              ││              ││   attention  │
         │└──────┬───────┘└──────────────┘└──────┬───────┘
         │       │                               │
         └───────┘                               │ resolve()
                                                 │
                                                 ▼
                                          ┌──────────────┐
                                          │   CLOSED     │
                                          │              │
                                          │ • Archived   │
                                          │ • Auditable  │
                                          └──────────────┘


         ═══════════════════════════════════════════════════
         From any state except DELIVERED/CLOSED:

             cancel() ───────► CANCELLED
         ═══════════════════════════════════════════════════
```

### 3.2 Constraint Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        CONSTRAINT STATE MACHINE                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

                              define()
                                 │
                                 ▼
                         ┌──────────────┐
                         │    DRAFT     │
                         │              │
                         │ • Editing    │
                         │ • Not active │
                         └──────┬───────┘
                                │ validate()
                                ▼
                         ┌──────────────┐
                    ┌───►│  VALIDATED   │
                    │    │              │
                    │    │ • Syntax OK  │
          fix()     │    │ • Types OK   │
                    │    │ • Not active │
                    │    └──────┬───────┘
                    │           │ activate()
                    │           ▼
                    │    ┌──────────────┐         ┌──────────────┐
                    │    │   ACTIVE     │────────►│  SUPERSEDED  │
                    │    │              │ update()│              │
                    │    │ • In use     │         │ • Old version│
                    │    │ • Evaluating │         │ • History    │
                    │    │ • Caching    │         │ • Auditable  │
                    │    └──────┬───────┘         └──────────────┘
                    │           │
                    │    ┌──────┴───────┐
                    │    │              │
                    │    ▼              ▼
                    │ validation_   deactivate()
                    │ error()           │
                    │    │              ▼
                    │    │       ┌──────────────┐
                    └────┘       │  INACTIVE    │
                                 │              │
                                 │ • Disabled   │
                                 │ • Not eval   │
                                 └──────┬───────┘
                                        │ delete()
                                        ▼
                                 ┌──────────────┐
                                 │   DELETED    │
                                 │              │
                                 │ • Soft del   │
                                 │ • Auditable  │
                                 └──────────────┘
```

### 3.3 Route Verification Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     ROUTE VERIFICATION STATE MACHINE                            │
└─────────────────────────────────────────────────────────────────────────────────┘

                           route_selected()
                                 │
                                 ▼
                         ┌──────────────┐
                         │   PENDING    │
                         │              │
                         │ • Queued     │
                         │ • Awaiting   │
                         │   prover     │
                         └──────┬───────┘
                                │ start_verification()
                                ▼
                         ┌──────────────┐
                         │  VERIFYING   │
                         │              │
                         │ • SMT active │
                         │ • Proof gen  │
                         └──────┬───────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
              ▼                 ▼                 ▼
       ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
       │   PROVEN     │ │   TIMEOUT    │ │   FAILED     │
       │              │ │              │ │              │
       │ • Certificate│ │ • Unresolved │ │ • Counter-   │
       │   generated  │ │ • Manual     │ │   example    │
       │ • Confidence:│ │   review     │ │ • Route      │
       │   HIGH       │ │   needed     │ │   invalid    │
       └──────────────┘ └──────┬───────┘ └──────────────┘
                               │
                               │ manual_review()
                               ▼
                        ┌──────────────┐
                        │  MANUALLY    │
                        │  APPROVED    │
                        │              │
                        │ • Human sign │
                        │ • Lower conf │
                        └──────────────┘
```

---

## 4. Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          VEDS COMPONENT DIAGRAM                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              «subsystem»                                        │
│                              Presentation                                       │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                                                                           │  │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐       │  │
│  │  │  «component»    │    │  «component»    │    │  «component»    │       │  │
│  │  │  Phoenix        │    │  Phoenix        │    │  Julia          │       │  │
│  │  │  LiveView       │    │  Channels       │    │  Genie.jl       │       │  │
│  │  │  (Dashboard)    │    │  (WebSocket)    │    │  (Analytics)    │       │  │
│  │  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘       │  │
│  │           │                      │                      │                │  │
│  └───────────┼──────────────────────┼──────────────────────┼────────────────┘  │
│              │                      │                      │                   │
└──────────────┼──────────────────────┼──────────────────────┼───────────────────┘
               │                      │                      │
               └──────────────────────┼──────────────────────┘
                                      │
                              ┌───────▼───────┐
                              │ «interface»   │
                              │ VEDS API      │
                              │               │
                              │ • REST        │
                              │ • GraphQL     │
                              │ • WebSocket   │
                              │ • gRPC        │
                              └───────┬───────┘
                                      │
┌─────────────────────────────────────┼───────────────────────────────────────────┐
│                              «subsystem»                                        │
│                              Application                                        │
│                                      │                                          │
│  ┌───────────────────────────────────┼───────────────────────────────────────┐  │
│  │                                   │                                       │  │
│  │  ┌─────────────────┐    ┌─────────▼─────────┐    ┌─────────────────┐      │  │
│  │  │  «component»    │    │  «component»      │    │  «component»    │      │  │
│  │  │  API Gateway    │◄───│  Phoenix          │───►│  Tracking       │      │  │
│  │  │  (Elixir)       │    │  Router           │    │  Engine         │      │  │
│  │  │                 │    │  (Elixir)         │    │  (Elixir)       │      │  │
│  │  └─────────────────┘    └───────────────────┘    └─────────────────┘      │  │
│  │                                                                           │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                              ┌───────▼───────┐
                              │ «interface»   │
                              │ Service Bus   │
                              │               │
                              │ • HTTP/2      │
                              │ • MessagePack │
                              └───────┬───────┘
                                      │
┌─────────────────────────────────────┼───────────────────────────────────────────┐
│                              «subsystem»                                        │
│                              Domain                                             │
│                                      │                                          │
│  ┌───────────────────────────────────┼───────────────────────────────────────┐  │
│  │                                   │                                       │  │
│  │  ┌─────────────────┐    ┌─────────▼─────────┐    ┌─────────────────┐      │  │
│  │  │  «component»    │    │  «component»      │    │  «component»    │      │  │
│  │  │  Route          │◄───│  Constraint       │───►│  Formal         │      │  │
│  │  │  Optimizer      │    │  Engine           │    │  Verifier       │      │  │
│  │  │  (Rust)         │    │  (Clojure)        │    │  (Ada/SPARK)    │      │  │
│  │  │                 │    │                   │    │                 │      │  │
│  │  │ ┌─────────────┐ │    │ ┌───────────────┐ │    │ ┌─────────────┐ │      │  │
│  │  │ │ pathfinding │ │    │ │ XTDB Client   │ │    │ │ GNATprove   │ │      │  │
│  │  │ │ petgraph    │ │    │ │ Datalog       │ │    │ │ Why3        │ │      │  │
│  │  │ │ rayon       │ │    │ │ Compiler      │ │    │ │ Z3/CVC5     │ │      │  │
│  │  │ └─────────────┘ │    │ └───────────────┘ │    │ └─────────────┘ │      │  │
│  │  └─────────────────┘    └───────────────────┘    └─────────────────┘      │  │
│  │                                                                           │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
                                      │
                              ┌───────▼───────┐
                              │ «interface»   │
                              │ Data Access   │
                              │               │
                              │ • Ecto        │
                              │ • SurrealDB   │
                              │ • XTDB        │
                              └───────┬───────┘
                                      │
┌─────────────────────────────────────┼───────────────────────────────────────────┐
│                              «subsystem»                                        │
│                              Persistence                                        │
│                                      │                                          │
│  ┌───────────────────────────────────┼───────────────────────────────────────┐  │
│  │                                   │                                       │  │
│  │  ┌─────────────────┐    ┌─────────▼─────────┐    ┌─────────────────┐      │  │
│  │  │  «component»    │    │  «component»      │    │  «component»    │      │  │
│  │  │  XTDB           │    │  SurrealDB        │    │  Dragonfly      │      │  │
│  │  │                 │    │                   │    │                 │      │  │
│  │  │ • Bitemporal    │    │ • Graph           │    │ • Cache         │      │  │
│  │  │ • Datalog       │    │ • Documents       │    │ • Pub/Sub       │      │  │
│  │  │ • Audit         │    │ • Real-time       │    │ • Geo           │      │  │
│  │  └─────────────────┘    └───────────────────┘    └─────────────────┘      │  │
│  │                                                                           │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Activity Diagram: Route Optimization

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    ACTIVITY: OPTIMIZE ROUTE                                     │
└─────────────────────────────────────────────────────────────────────────────────┘

                                    ●
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Receive Optimization │
                         │ Request              │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Load Transport Graph │
                         │ from SurrealDB       │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Load Active          │
                         │ Constraints from     │
                         │ Dragonfly Cache      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ════════════════╪════════════════
                    ║   PARALLEL    ║
                    ════════════════╪════════════════
                    │               │               │
                    ▼               ▼               ▼
            ┌────────────┐  ┌────────────┐  ┌────────────┐
            │ Dijkstra   │  │ A* Search  │  │ K-Shortest │
            │ Paths      │  │ Paths      │  │ Paths      │
            └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
                  │               │               │
                  └───────────────┼───────────────┘
                                  │
                    ══════════════╪══════════════
                    ║   JOIN      ║
                    ══════════════╪══════════════
                                  │
                                  ▼
                         ┌──────────────────────┐
                         │ Deduplicate &        │
                         │ Merge Candidates     │
                         └──────────┬───────────┘
                                    │
                                    ▼
                    ════════════════╪════════════════
                    ║   FOR EACH CANDIDATE       ║
                    ════════════════╪════════════════
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Calculate Scores     │
                         │ (Cost, Time, Carbon, │
                         │  Labor)              │
                         └──────────┬───────────┘
                                    │
                                    ▼
                         ┌──────────────────────┐
                         │ Evaluate Hard        │
                         │ Constraints          │
                         └──────────┬───────────┘
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                    [PASS]                [FAIL]
                         │                     │
                         ▼                     ▼
                ┌────────────────┐    ┌────────────────┐
                │ Add to Valid   │    │ Discard        │
                │ Candidates     │    │                │
                └────────┬───────┘    └────────────────┘
                         │
                    ═════╪═════
                    ║ END FOR ║
                    ═════╪═════
                         │
                         ▼
                ┌──────────────────────┐
                │ Compute Pareto       │
                │ Frontier             │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Rank by User         │
                │ Preference Weights   │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Select Top Route     │
                │ for Verification     │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Generate Proof       │◄────── async
                │ Obligations          │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Submit to Formal     │
                │ Verifier (Ada/SPARK) │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Store Decision in    │
                │ XTDB + SurrealDB     │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │ Return Ranked Routes │
                │ to Client            │
                └──────────┬───────────┘
                           │
                           ▼
                           ◉
```
