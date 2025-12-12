# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
VEDS Test Suite Runner

Run all tests with:
    julia --project=test test/runtests.jl

Run specific test modules:
    VEDS_TEST_INTEGRATION=true julia --project=test test/runtests.jl
    VEDS_TEST_PROPERTY=true julia --project=test test/runtests.jl
"""

using Test

# =============================================================================
# Test Configuration
# =============================================================================

const RUN_INTEGRATION = get(ENV, "VEDS_TEST_INTEGRATION", "false") == "true"
const RUN_PROPERTY = get(ENV, "VEDS_TEST_PROPERTY", "true") == "true"

# =============================================================================
# Property Tests (can run without external dependencies)
# =============================================================================

@testset "VEDS Property Tests" begin
    if RUN_PROPERTY
        @testset "Constraint Properties" begin
            include("property/test_constraints_properties.jl")
        end

        @testset "Pareto Properties" begin
            include("property/test_pareto_properties.jl")
        end
    else
        @info "Skipping property tests (set VEDS_TEST_PROPERTY=true to run)"
    end
end

# =============================================================================
# Integration Tests (require running containers)
# =============================================================================

@testset "VEDS Integration Tests" begin
    if RUN_INTEGRATION
        @testset "Dragonfly" begin
            include("integration/test_dragonfly.jl")
        end

        @testset "SurrealDB" begin
            include("integration/test_surrealdb.jl")
        end

        @testset "XTDB" begin
            include("integration/test_xtdb.jl")
        end
    else
        @info "Skipping integration tests (set VEDS_TEST_INTEGRATION=true to run)"
    end
end

@info "All tests completed!"
