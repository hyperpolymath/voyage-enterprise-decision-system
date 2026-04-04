# Voyage-Enterprise-Decision-System - Development Tasks
set shell := ["bash", "-uc"]
set dotenv-load := true

project := "Voyage-Enterprise-Decision-System"

# Show all recipes
default:
    @just --list --unsorted

# Build all MVP components
build: build-rust build-deno

# Build Rust optimizer
build-rust:
    cd src/rust-routing && cargo build --release

# Build Deno API (compile ReScript)
build-deno:
    cd src/deno-api && deno cache src/main.ts

# Build Julia packages
build-julia:
    cd src/julia-viz && julia --project=. -e 'using Pkg; Pkg.instantiate()'
    cd test && julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run all tests (property tests only by default)
test:
    julia --project=test test/runtests.jl

# Run integration tests (requires running containers)
test-integration:
    VEDS_TEST_INTEGRATION=true julia --project=test test/runtests.jl

# Run property-based tests
test-property:
    VEDS_TEST_PROPERTY=true julia --project=test test/runtests.jl

# Seed databases with synthetic data
seed:
    julia --project=src/julia-viz scripts/seed_data.jl

# Seed with custom URLs
seed-custom surrealdb_url dragonfly_url:
    julia --project=src/julia-viz scripts/seed_data.jl --surrealdb-url {{surrealdb_url}} --dragonfly-url {{dragonfly_url}}

# Start Docker containers for development
containers-up:
    docker-compose up -d

# Stop Docker containers
containers-down:
    docker-compose down

# Clean build artifacts
clean:
    find . -name "*.cov" -delete
    find . -name "*.mem" -delete
    rm -rf test/Manifest.toml
    rm -rf src/julia-viz/Manifest.toml

# Format Julia code
fmt:
    julia --project=src/julia-viz -e 'using JuliaFormatter; format("src"); format("test"); format("scripts")'

# Lint Julia code
lint:
    julia --project=src/julia-viz -e 'using StaticLint; lint("src/julia-viz/src")'

# Start visualization server
serve:
    julia --project=src/julia-viz -e 'using VEDSViz; app = VEDSApp(); start_server(app)'

# Start Deno API server
serve-api:
    cd src/deno-api && deno run --allow-net --allow-env --allow-read src/main.ts

# Start Deno API in watch mode
serve-api-dev:
    cd src/deno-api && deno run --allow-net --allow-env --allow-read --watch src/main.ts

# Start Rust optimizer
serve-optimizer:
    cd src/rust-routing && cargo run --release

# Initialize databases with schemas (requires SURREALDB_USER and SURREALDB_PASS)
db-init:
    @echo "Initializing SurrealDB schema..."
    curl -X POST -H "Accept: application/json" -H "NS: veds" -H "DB: production" \
        -u "${SURREALDB_USER:?SURREALDB_USER required}:${SURREALDB_PASS:?SURREALDB_PASS required}" \
        --data-binary @db/schemas/surrealdb.surql \
        http://localhost:8000/sql
    @echo "Database initialized."

# Seed databases with sample data (requires SURREALDB_USER and SURREALDB_PASS)
db-seed:
    @echo "Seeding SurrealDB with transport network..."
    curl -X POST -H "Accept: application/json" -H "NS: veds" -H "DB: production" \
        -u "${SURREALDB_USER:?SURREALDB_USER required}:${SURREALDB_PASS:?SURREALDB_PASS required}" \
        --data-binary @db/seeds/transport_network.surql \
        http://localhost:8000/sql
    @echo "Database seeded."

# Reset and reinitialize databases
db-reset: containers-down containers-up
    @sleep 5
    just db-init
    just db-seed

# Run all services (for development)
dev: containers-up
    @echo "Starting development services..."
    @echo "Waiting for databases..."
    @sleep 10
    just db-init
    just db-seed
    @echo "Starting API server..."
    just serve-api-dev

# Check service health (requires env vars)
health:
    @echo "=== Service Health ==="
    @echo "SurrealDB:" && curl -s http://localhost:8000/health || echo "DOWN"
    @echo "XTDB:" && curl -s http://localhost:3000/status || echo "DOWN"
    @echo "Dragonfly:" && redis-cli -a "${DRAGONFLY_PASS:?DRAGONFLY_PASS required}" ping 2>/dev/null || echo "DOWN"
    @echo "API:" && curl -s http://localhost:4000/health || echo "DOWN"
    @echo "Optimizer:" && curl -s http://localhost:8090/health || echo "DOWN"

# Run Rust tests
test-rust:
    cd src/rust-routing && cargo test

# Run all component tests
test-all: test test-rust

# Generate API client from protobuf
proto-gen:
    cd src/rust-routing && cargo build

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# Self-diagnostic — checks dependencies, permissions, paths
doctor:
    @echo "Running diagnostics for voyage-enterprise-decision-system..."
    @echo "Checking required tools..."
    @command -v just >/dev/null 2>&1 && echo "  [OK] just" || echo "  [FAIL] just not found"
    @command -v git >/dev/null 2>&1 && echo "  [OK] git" || echo "  [FAIL] git not found"
    @echo "Checking for hardcoded paths..."
    @grep -rn '$HOME\|$ECLIPSE_DIR' --include='*.rs' --include='*.ex' --include='*.res' --include='*.gleam' --include='*.sh' . 2>/dev/null | head -5 || echo "  [OK] No hardcoded paths"
    @echo "Diagnostics complete."

# Guided tour of key features
tour:
    @echo "=== voyage-enterprise-decision-system Tour ==="
    @echo ""
    @echo "1. Project structure:"
    @ls -la
    @echo ""
    @echo "2. Available commands: just --list"
    @echo ""
    @echo "3. Read README.adoc for full overview"
    @echo "4. Read EXPLAINME.adoc for architecture decisions"
    @echo "5. Run 'just doctor' to check your setup"
    @echo ""
    @echo "Tour complete! Try 'just --list' to see all available commands."

# Open feedback channel with diagnostic context
help-me:
    @echo "=== voyage-enterprise-decision-system Help ==="
    @echo "Platform: $(uname -s) $(uname -m)"
    @echo "Shell: $SHELL"
    @echo ""
    @echo "To report an issue:"
    @echo "  https://github.com/hyperpolymath/voyage-enterprise-decision-system/issues/new"
    @echo ""
    @echo "Include the output of 'just doctor' in your report."

# Attempt to automatically install missing tools
heal:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Voyage Enterprise Decision System Heal — Automatic Tool Installation"
    echo "═══════════════════════════════════════════════════"
    echo ""
if ! command -v just >/dev/null 2>&1; then
    echo "Installing just..."
    cargo install just 2>/dev/null || echo "Install just from https://just.systems"
fi
    echo ""
    echo "Heal complete. Run 'just doctor' to verify."


# Print the current CRG grade (reads from READINESS.md '**Current Grade:** X' line)
crg-grade:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    echo "$$grade"

# Generate a shields.io badge markdown for the current CRG grade
# Looks for '**Current Grade:** X' in READINESS.md; falls back to X
crg-badge:
    @grade=$$(grep -oP '(?<=\*\*Current Grade:\*\* )[A-FX]' READINESS.md 2>/dev/null | head -1); \
    [ -z "$$grade" ] && grade="X"; \
    case "$$grade" in \
      A) color="brightgreen" ;; B) color="green" ;; C) color="yellow" ;; \
      D) color="orange" ;; E) color="red" ;; F) color="critical" ;; \
      *) color="lightgrey" ;; esac; \
    echo "[![CRG $$grade](https://img.shields.io/badge/CRG-$$grade-$$color?style=flat-square)](https://github.com/hyperpolymath/standards/tree/main/component-readiness-grades)"
