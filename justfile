# Voyage-Enterprise-Decision-System - Development Tasks
set shell := ["bash", "-uc"]
set dotenv-load := true

project := "Voyage-Enterprise-Decision-System"

# Show all recipes
default:
    @just --list --unsorted

# Build Julia packages
build:
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

# Start containers for development (nerdctl preferred, podman fallback)
containers-up:
    nerdctl compose -f nerdctl-compose.yaml up -d || podman-compose up -d

# Stop containers
containers-down:
    nerdctl compose -f nerdctl-compose.yaml down || podman-compose down

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
