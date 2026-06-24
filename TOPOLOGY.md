<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
<!-- TOPOLOGY.md — Project architecture map and completion dashboard -->
<!-- Last updated: 2026-02-19 -->

# VEDS — Project Topology

## System Architecture

```
                        ┌─────────────────────────────────────────┐
                        │              OPERATOR / LOGISTICS       │
                        │        (LiveView / Julia Dashboard)     │
                        └───────────────────┬─────────────────────┘
                                            │ HTTP / WebSocket
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │           ELIXIR API GATEWAY            │
                        │    (Phoenix, Absinthe, Routing Hub)     │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
                                   ▼                   ▼
                        ┌───────────────────────┐  ┌────────────────────────────────┐
                        │ DOMAIN ENGINES        │  │ DATA & STORAGE                 │
                        │ - Rust (Path Opt)     │  │ - XTDB (Bitemporal Audit)      │
                        │ - Clojure (Datalog)   │  │ - SurrealDB (Graph/Doc)        │
                        │ - Ada/SPARK (Proofs)  │  │ - Dragonfly (Geo-Cache)        │
                        └──────────┬────────────┘  └──────────┬─────────────────────┘
                                   │                          │
                                   └────────────┬─────────────┘
                                                ▼
                        ┌─────────────────────────────────────────┐
                        │           EXTERNAL LOGISTICS            │
                        │  ┌───────────┐  ┌───────────┐  ┌───────┐│
                        │  │ Maritime  │  │ Rail/Road │  │ Air   ││
                        │  └───────────┘  └───────────┘  └───────┘│
                        └─────────────────────────────────────────┘

                        ┌─────────────────────────────────────────┐
                        │          REPO INFRASTRUCTURE            │
                        │  Justfile Automation  .machine_readable/  │
                        │  Nerdctl Compose      0-AI-MANIFEST.a2ml  │
                        └─────────────────────────────────────────┘
```

## Completion Dashboard

```
COMPONENT                          STATUS              NOTES
─────────────────────────────────  ──────────────────  ─────────────────────────────────
DOMAIN ENGINES
  Rust Routing Engine               ████░░░░░░  40%    Path optimization stubs
  Clojure Constraints               ████░░░░░░  40%    Datalog rules active
  Ada/SPARK Proofs                  ██░░░░░░░░  20%    Formal spec verified
  Elixir Tracking (Dragonfly)       ██████░░░░  60%    Real-time position active

PRESENTATION & API
  Phoenix LiveView (AL UI)          ██████░░░░  60%    Marking interface stable
  Julia Analytics (Makie.jl)        ████░░░░░░  40%    Viz dashboard prototyping
  API Skeleton (GraphQL)            ████████░░  80%    CRUD endpoints verified

REPO INFRASTRUCTURE
  Justfile Automation               ██████████ 100%    Standard build/run tasks
  .machine_readable/                ██████████ 100%    STATE tracking active
  Architecture (DFD Lv 0-3)         ██████████ 100%    System design stable

─────────────────────────────────────────────────────────────────────────────
OVERALL:                            ████░░░░░░  ~40%   Architecture stable, Core maturing
```

## Key Dependencies

```
Shipment Spec ───► Clojure Rules ─────► Rust Optimizer ─────► Route Map
     │                 │                   │                    │
     ▼                 ▼                   ▼                    ▼
Ada Proofs ─────► XTDB Audit ──────► SurrealDB Graph ───► Phoenix HUD
```

## Update Protocol

This file is maintained by both humans and AI agents. When updating:

1. **After completing a component**: Change its bar and percentage
2. **After adding a component**: Add a new row in the appropriate section
3. **After architectural changes**: Update the ASCII diagram
4. **Date**: Update the `Last updated` comment at the top of this file

Progress bars use: `█` (filled) and `░` (empty), 10 characters wide.
Percentages: 0%, 10%, 20%, ... 100% (in 10% increments).
