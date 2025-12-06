# VEDS Data Flow Diagram - Level 0 (Context Diagram)

## Overview

The Context Diagram shows VEDS as a single process interacting with external entities.
This is the highest abstraction level - the "black box" view.

## Diagram

```
                                    ┌─────────────────────┐
                                    │   TRANSPORT APIs    │
                                    │  ─────────────────  │
                                    │  • Maersk (Maritime)│
                                    │  • DB Cargo (Rail)  │
                                    │  • Geodis (Road)    │
                                    │  • IATA (Air)       │
                                    └──────────┬──────────┘
                                               │
                              rates, schedules,│availability
                                    ┌──────────▼──────────┐
                                    │                     │
    ┌──────────────┐  shipment      │                     │  constraint     ┌──────────────┐
    │   SHIPPER    │  requests      │                     │  definitions    │   POLICY     │
    │  ──────────  │───────────────►│                     │◄────────────────│   ADMIN      │
    │  • DHL       │                │                     │                 │  ──────────  │
    │  • Kuehne+N  │  routes,       │       V E D S       │  labor rules,   │  • Mgmt      │
    │  • Flexport  │  tracking,     │                     │  carbon limits, │  • Compliance│
    │              │◄───────────────│   (Voyage Enterprise│  wage minimums  │  • Legal     │
    │              │  carbon reports│    Decision System) │                 │              │
    └──────────────┘                │                     │                 └──────────────┘
                                    │                     │
                                    │                     │
    ┌──────────────┐  GPS, status,  │                     │  audit queries  ┌──────────────┐
    │   CARRIER    │  ETAs          │                     │◄────────────────│   AUDITOR    │
    │  ──────────  │───────────────►│                     │                 │  ──────────  │
    │  • Ship ops  │                │                     │  historical     │  • Internal  │
    │  • Rail ops  │  dispatch      │                     │  decisions,     │  • External  │
    │  • Trucking  │  instructions  │                     │  proofs         │  • Regulatory│
    │  • Airlines  │◄───────────────│                     │────────────────►│              │
    └──────────────┘                │                     │                 └──────────────┘
                                    │                     │
                                    └──────────┬──────────┘
                                               │
                              viz requests,    │dashboards, reports
                              analysis queries │
                                    ┌──────────▼──────────┐
                                    │   ANALYST / EXEC    │
                                    │  ─────────────────  │
                                    │  • Supply Chain Mgr │
                                    │  • CFO              │
                                    │  • Sustainability   │
                                    └─────────────────────┘
```

## External Entities

| Entity | Description | Data Sent to VEDS | Data Received from VEDS |
|--------|-------------|-------------------|-------------------------|
| **Transport APIs** | Third-party logistics providers | Rates, schedules, vessel/train positions, availability | Booking requests, capacity reservations |
| **Shipper** | Companies sending goods | Shipment requests (origin, dest, constraints, cargo) | Optimized routes, tracking, carbon reports |
| **Carrier** | Companies operating vehicles | GPS positions, status updates, delays, ETAs | Dispatch instructions, route assignments |
| **Policy Admin** | Internal governance team | Labor rules, carbon budgets, wage minimums, constraints | Constraint validation results, compliance reports |
| **Auditor** | Internal/external reviewers | Audit queries (what happened when, why this route) | Bitemporal history, decision proofs, audit trails |
| **Analyst/Exec** | Business intelligence users | Visualization requests, KPI queries | Dashboards, reports, trend analysis |

## Data Flows Summary

### Inbound Flows
1. **Shipment Requests** - What needs to move, from where to where, with what constraints
2. **Transport Data** - Real-time rates, schedules, positions from external APIs
3. **Carrier Updates** - GPS, status, delays from vehicles in transit
4. **Policy Definitions** - Business rules, labor standards, environmental constraints
5. **Audit Queries** - Historical inquiries into past decisions

### Outbound Flows
1. **Optimized Routes** - Multi-modal paths satisfying all constraints
2. **Tracking Updates** - Real-time position and ETA for shipments
3. **Dispatch Instructions** - Orders to carriers for pickup/delivery
4. **Carbon Reports** - Environmental impact metrics per shipment
5. **Audit Responses** - Bitemporal history with decision proofs
6. **Visualizations** - Dashboards, maps, analytics

## VoID Vocabulary Alignment

This context diagram maps to VoID (Vocabulary of Interlinked Datasets):

- **VEDS** is a `void:Dataset`
- Each external entity provides/consumes `void:Linkset` connections
- Transport APIs are `void:externalLink` sources
- Audit trails are `void:dataDump` exports

See `/docs/vocab/VOID-MAPPING.md` for detailed vocabulary alignment.

## Notes

- VEDS is shown as a single process at Level 0
- Level 1 will decompose VEDS into major subsystems
- All data flows are bidirectional where indicated
- External entities may overlap (e.g., DHL is both shipper and carrier)
