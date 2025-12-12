# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2025 VEDS Contributors

"""
Property-Based Tests for Pareto Optimization
Verifies multi-objective optimization invariants
"""

module TestParetoProperties

using Test
using PropCheck

# =============================================================================
# Pareto Domain Model
# =============================================================================

"""A solution in multi-objective space."""
struct Solution
    id::String
    cost::Float64
    time::Float64
    carbon::Float64
    labor_score::Float64  # Higher is better (unlike others)
end

"""Check if this solution dominates another (minimizing cost/time/carbon, maximizing labor)."""
function dominates(a::Solution, b::Solution)::Bool
    at_least_as_good = (
        a.cost <= b.cost &&
        a.time <= b.time &&
        a.carbon <= b.carbon &&
        a.labor_score >= b.labor_score
    )
    strictly_better = (
        a.cost < b.cost ||
        a.time < b.time ||
        a.carbon < b.carbon ||
        a.labor_score > b.labor_score
    )
    at_least_as_good && strictly_better
end

"""Return objectives as tuple (for Pareto comparison)."""
function objectives_tuple(sol::Solution)
    # Negate labor_score since it's maximized
    (sol.cost, sol.time, sol.carbon, -sol.labor_score)
end

"""Find Pareto-optimal solutions."""
function find_pareto_frontier(solutions::Vector{Solution})::Vector{Solution}
    pareto_front = Solution[]

    for candidate in solutions
        is_dominated = false
        for other in solutions
            if other.id != candidate.id && dominates(other, candidate)
                is_dominated = true
                break
            end
        end

        if !is_dominated
            push!(pareto_front, candidate)
        end
    end

    pareto_front
end

"""Assign Pareto ranks (1 = frontier, 2 = second front, etc.)."""
function pareto_rank(solutions::Vector{Solution})::Vector{Tuple{Solution, Int}}
    isempty(solutions) && return Tuple{Solution, Int}[]

    remaining = copy(solutions)
    ranked = Tuple{Solution, Int}[]
    rank = 1

    while !isempty(remaining)
        frontier = find_pareto_frontier(remaining)
        for sol in frontier
            push!(ranked, (sol, rank))
        end
        filter!(s -> !(s in frontier), remaining)
        rank += 1
    end

    ranked
end

# =============================================================================
# PropCheck Generators
# =============================================================================

positive_float_gen() = itype(Float64; range=0.01:0.01:100000.0)
labor_score_gen() = itype(Float64; range=0.0:0.01:1.0)

function solution_gen(id_prefix::String="sol")
    map(PropCheck.tuple(
        itype(Int; range=0:10000),
        positive_float_gen(),
        positive_float_gen(),
        positive_float_gen(),
        labor_score_gen(),
    )) do args
        (n, cost, time, carbon, labor) = args
        Solution("$(id_prefix)_$n", cost, time, carbon, labor)
    end
end

function solution_list_gen(min_size::Int=2, max_size::Int=30)
    map(itype(Int; range=min_size:max_size)) do n
        [Solution("sol_$i", rand()*100000, rand()*100000, rand()*100000, rand()) for i in 1:n]
    end
end

# =============================================================================
# Property Tests: Pareto Dominance
# =============================================================================

@testset "Pareto Dominance Properties" begin
    @testset "solution_does_not_dominate_itself" begin
        @check function(sol=solution_gen())
            !dominates(sol, sol)
        end
    end

    @testset "dominance_is_asymmetric" begin
        @check function(sol_a=solution_gen(), sol_b=solution_gen())
            !dominates(sol_a, sol_b) || !dominates(sol_b, sol_a)
        end
    end

    @testset "dominance_is_transitive" begin
        @check function(sol_a=solution_gen(), sol_b=solution_gen(), sol_c=solution_gen())
            !(dominates(sol_a, sol_b) && dominates(sol_b, sol_c)) || dominates(sol_a, sol_c)
        end
    end

    @testset "strictly_better_dominates" begin
        @check function(sol=solution_gen())
            new_labor = sol.labor_score < 0.99 ? sol.labor_score + 0.01 : sol.labor_score
            new_cost = max(sol.cost - 0.01, 0.01)
            new_time = max(sol.time - 0.01, 0.01)
            new_carbon = max(sol.carbon - 0.01, 0.01)

            better = Solution("better", new_cost, new_time, new_carbon, new_labor)
            dominates(better, sol)
        end
    end
end

# =============================================================================
# Property Tests: Pareto Frontier
# =============================================================================

@testset "Pareto Frontier Properties" begin
    @testset "frontier_is_non_empty" begin
        @check function(sols=solution_list_gen(1, 20))
            !isempty(find_pareto_frontier(sols))
        end
    end

    @testset "frontier_solutions_are_not_dominated" begin
        @check function(sols=solution_list_gen(2, 20))
            frontier = find_pareto_frontier(sols)

            all(frontier) do front_sol
                !any(sols) do other
                    other.id != front_sol.id && dominates(other, front_sol)
                end
            end
        end
    end

    @testset "non_frontier_solutions_are_dominated" begin
        @check function(sols=solution_list_gen(2, 20))
            frontier = find_pareto_frontier(sols)
            frontier_ids = Set(s.id for s in frontier)

            all(sols) do sol
                sol.id in frontier_ids || any(other -> other.id != sol.id && dominates(other, sol), sols)
            end
        end
    end

    @testset "frontier_is_subset" begin
        @check function(sols=solution_list_gen(2, 20))
            frontier = find_pareto_frontier(sols)
            sol_ids = Set(s.id for s in sols)
            frontier_ids = Set(s.id for s in frontier)

            issubset(frontier_ids, sol_ids)
        end
    end

    @testset "frontier_is_maximal" begin
        @check function(sols=solution_list_gen(2, 20))
            frontier = find_pareto_frontier(sols)

            all(sols) do sol
                sol in frontier || any(other -> other.id != sol.id && dominates(other, sol), sols)
            end
        end
    end
end

# =============================================================================
# Property Tests: Pareto Ranking
# =============================================================================

@testset "Pareto Ranking Properties" begin
    @testset "all_solutions_are_ranked" begin
        @check function(sols=solution_list_gen(1, 20))
            ranked = pareto_rank(sols)
            ranked_ids = Set(sol.id for (sol, _) in ranked)
            input_ids = Set(s.id for s in sols)

            ranked_ids == input_ids
        end
    end

    @testset "ranks_are_positive" begin
        @check function(sols=solution_list_gen(1, 20))
            ranked = pareto_rank(sols)
            all(rank >= 1 for (_, rank) in ranked)
        end
    end

    @testset "frontier_has_rank_one" begin
        @check function(sols=solution_list_gen(1, 20))
            frontier = find_pareto_frontier(sols)
            ranked = pareto_rank(sols)

            frontier_ids = Set(s.id for s in frontier)
            all(ranked) do (sol, rank)
                !(sol.id in frontier_ids) || rank == 1
            end
        end
    end

    @testset "lower_rank_not_dominated_by_higher" begin
        @check function(sols=solution_list_gen(2, 20))
            ranked = pareto_rank(sols)
            sol_map = Dict(sol.id => sol for sol in sols)

            all(ranked) do (sol_a, rank_a)
                all(ranked) do (sol_b, rank_b)
                    rank_a >= rank_b || !dominates(sol_map[sol_b.id], sol_map[sol_a.id])
                end
            end
        end
    end
end

# =============================================================================
# Property Tests: Edge Cases
# =============================================================================

@testset "Pareto Edge Cases" begin
    @testset "single_solution_is_frontier" begin
        sol = Solution("only", 100.0, 100.0, 100.0, 0.5)
        frontier = find_pareto_frontier([sol])
        @test frontier == [sol]
    end

    @testset "identical_solutions_dont_dominate" begin
        sol_a = Solution("a", 100.0, 100.0, 100.0, 0.5)
        sol_b = Solution("b", 100.0, 100.0, 100.0, 0.5)

        @test !dominates(sol_a, sol_b)
        @test !dominates(sol_b, sol_a)

        frontier = find_pareto_frontier([sol_a, sol_b])
        @test length(frontier) == 2
    end

    @testset "all_identical_all_on_frontier" begin
        @check function(n=itype(Int; range=2:20))
            sols = [Solution("sol_$i", 100.0, 100.0, 100.0, 0.5) for i in 1:n]
            frontier = find_pareto_frontier(sols)
            length(frontier) == n
        end
    end

    @testset "linear_pareto_frontier" begin
        # Each solution trades off cost vs time
        sols = [
            Solution("cheap_slow", 100.0, 500.0, 100.0, 0.5),
            Solution("mid", 300.0, 300.0, 100.0, 0.5),
            Solution("expensive_fast", 500.0, 100.0, 100.0, 0.5),
        ]

        frontier = find_pareto_frontier(sols)
        # All three should be on frontier (trade-off between cost and time)
        @test length(frontier) == 3
    end
end

end # module
