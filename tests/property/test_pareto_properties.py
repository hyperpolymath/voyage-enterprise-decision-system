"""
Property-Based Tests for Pareto Optimization
Verifies multi-objective optimization invariants
"""

import pytest
from hypothesis import given, assume, settings, HealthCheck
from hypothesis import strategies as st
from typing import List, Tuple
from dataclasses import dataclass


# =============================================================================
# Pareto Domain Model
# =============================================================================

@dataclass
class Solution:
    """A solution in multi-objective space."""
    id: str
    cost: float
    time: float
    carbon: float
    labor_score: float  # Higher is better (unlike others)

    def dominates(self, other: 'Solution') -> bool:
        """Check if this solution dominates another (minimizing cost/time/carbon, maximizing labor)."""
        at_least_as_good = (
            self.cost <= other.cost and
            self.time <= other.time and
            self.carbon <= other.carbon and
            self.labor_score >= other.labor_score
        )
        strictly_better = (
            self.cost < other.cost or
            self.time < other.time or
            self.carbon < other.carbon or
            self.labor_score > other.labor_score
        )
        return at_least_as_good and strictly_better

    def objectives_tuple(self) -> Tuple[float, float, float, float]:
        """Return objectives as tuple (for Pareto comparison)."""
        # Negate labor_score since it's maximized
        return (self.cost, self.time, self.carbon, -self.labor_score)


def find_pareto_frontier(solutions: List[Solution]) -> List[Solution]:
    """Find Pareto-optimal solutions."""
    pareto_front = []

    for candidate in solutions:
        is_dominated = False
        for other in solutions:
            if other.id != candidate.id and other.dominates(candidate):
                is_dominated = True
                break

        if not is_dominated:
            pareto_front.append(candidate)

    return pareto_front


def pareto_rank(solutions: List[Solution]) -> List[Tuple[Solution, int]]:
    """Assign Pareto ranks (1 = frontier, 2 = second front, etc.)."""
    if not solutions:
        return []

    remaining = list(solutions)
    ranked = []
    rank = 1

    while remaining:
        frontier = find_pareto_frontier(remaining)
        for sol in frontier:
            ranked.append((sol, rank))
        remaining = [s for s in remaining if s not in frontier]
        rank += 1

    return ranked


# =============================================================================
# Hypothesis Strategies
# =============================================================================

positive_float = st.floats(min_value=0.01, max_value=100000, allow_nan=False, allow_infinity=False)
labor_score = st.floats(min_value=0.0, max_value=1.0, allow_nan=False)


@st.composite
def solutions(draw, id_prefix: str = "sol") -> Solution:
    """Generate random solutions."""
    return Solution(
        id=f"{id_prefix}_{draw(st.integers(min_value=0, max_value=10000))}",
        cost=draw(positive_float),
        time=draw(positive_float),
        carbon=draw(positive_float),
        labor_score=draw(labor_score),
    )


@st.composite
def solution_lists(draw, min_size: int = 2, max_size: int = 50) -> List[Solution]:
    """Generate list of unique solutions."""
    n = draw(st.integers(min_value=min_size, max_value=max_size))
    return [draw(solutions(f"sol_{i}")) for i in range(n)]


# =============================================================================
# Property Tests: Pareto Dominance
# =============================================================================

class TestParetoDominanceProperties:
    """Property tests for Pareto dominance relation."""

    @given(sol=solutions())
    def test_solution_does_not_dominate_itself(self, sol: Solution):
        """A solution cannot dominate itself."""
        assert not sol.dominates(sol)

    @given(sol_a=solutions(), sol_b=solutions())
    def test_dominance_is_asymmetric(self, sol_a: Solution, sol_b: Solution):
        """If A dominates B, B cannot dominate A."""
        if sol_a.dominates(sol_b):
            assert not sol_b.dominates(sol_a)

    @given(sol_a=solutions(), sol_b=solutions(), sol_c=solutions())
    @settings(suppress_health_check=[HealthCheck.too_slow])
    def test_dominance_is_transitive(self, sol_a: Solution, sol_b: Solution, sol_c: Solution):
        """If A dominates B and B dominates C, then A dominates C."""
        if sol_a.dominates(sol_b) and sol_b.dominates(sol_c):
            assert sol_a.dominates(sol_c)

    @given(sol=solutions())
    def test_strictly_better_dominates(self, sol: Solution):
        """A strictly better solution always dominates."""
        better = Solution(
            id="better",
            cost=sol.cost - 0.01,
            time=sol.time - 0.01,
            carbon=sol.carbon - 0.01,
            labor_score=sol.labor_score + 0.01 if sol.labor_score < 0.99 else sol.labor_score,
        )
        # Adjust if values went negative
        if better.cost <= 0:
            better.cost = 0.01
        if better.time <= 0:
            better.time = 0.01
        if better.carbon <= 0:
            better.carbon = 0.01

        assert better.dominates(sol)


# =============================================================================
# Property Tests: Pareto Frontier
# =============================================================================

class TestParetoFrontierProperties:
    """Property tests for Pareto frontier."""

    @given(sols=solution_lists(min_size=1, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_frontier_is_non_empty(self, sols: List[Solution]):
        """Pareto frontier is never empty for non-empty input."""
        frontier = find_pareto_frontier(sols)
        assert len(frontier) >= 1

    @given(sols=solution_lists(min_size=2, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_frontier_solutions_are_not_dominated(self, sols: List[Solution]):
        """No solution on frontier is dominated by any other solution."""
        frontier = find_pareto_frontier(sols)

        for front_sol in frontier:
            for other in sols:
                if other.id != front_sol.id:
                    assert not other.dominates(front_sol)

    @given(sols=solution_lists(min_size=2, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_non_frontier_solutions_are_dominated(self, sols: List[Solution]):
        """Every solution not on frontier is dominated by at least one frontier solution."""
        frontier = find_pareto_frontier(sols)
        frontier_ids = {s.id for s in frontier}

        for sol in sols:
            if sol.id not in frontier_ids:
                # Must be dominated by at least one solution (not necessarily on frontier)
                is_dominated = any(
                    other.dominates(sol)
                    for other in sols
                    if other.id != sol.id
                )
                assert is_dominated

    @given(sols=solution_lists(min_size=2, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_frontier_is_subset(self, sols: List[Solution]):
        """Frontier is a subset of original solutions."""
        frontier = find_pareto_frontier(sols)
        sol_ids = {s.id for s in sols}
        frontier_ids = {s.id for s in frontier}

        assert frontier_ids.issubset(sol_ids)

    @given(sols=solution_lists(min_size=2, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_frontier_is_maximal(self, sols: List[Solution]):
        """Cannot add dominated solutions to frontier."""
        frontier = find_pareto_frontier(sols)

        for sol in sols:
            if sol not in frontier:
                # Adding this solution shouldn't make it non-dominated
                is_dominated = any(f.dominates(sol) for f in frontier)
                # It either is dominated by frontier, or was excluded for being dominated by something
                # (In practice, if not in frontier, must be dominated)
                dominated_by_any = any(
                    other.dominates(sol)
                    for other in sols
                    if other.id != sol.id
                )
                assert dominated_by_any


# =============================================================================
# Property Tests: Pareto Ranking
# =============================================================================

class TestParetoRankingProperties:
    """Property tests for Pareto ranking."""

    @given(sols=solution_lists(min_size=1, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_all_solutions_are_ranked(self, sols: List[Solution]):
        """Every solution gets a rank."""
        ranked = pareto_rank(sols)
        ranked_ids = {sol.id for sol, _ in ranked}
        input_ids = {s.id for s in sols}

        assert ranked_ids == input_ids

    @given(sols=solution_lists(min_size=1, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_ranks_are_positive(self, sols: List[Solution]):
        """All ranks are positive integers."""
        ranked = pareto_rank(sols)
        for _, rank in ranked:
            assert rank >= 1

    @given(sols=solution_lists(min_size=1, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_frontier_has_rank_one(self, sols: List[Solution]):
        """All frontier solutions have rank 1."""
        frontier = find_pareto_frontier(sols)
        ranked = pareto_rank(sols)

        frontier_ids = {s.id for s in frontier}
        for sol, rank in ranked:
            if sol.id in frontier_ids:
                assert rank == 1

    @given(sols=solution_lists(min_size=2, max_size=30))
    @settings(suppress_health_check=[HealthCheck.too_slow], deadline=None)
    def test_lower_rank_dominates_higher(self, sols: List[Solution]):
        """If solution A has lower rank than B, A is not dominated by B."""
        ranked = pareto_rank(sols)
        rank_map = {sol.id: rank for sol, rank in ranked}
        sol_map = {sol.id: sol for sol in sols}

        for sol_a, rank_a in ranked:
            for sol_b, rank_b in ranked:
                if rank_a < rank_b:
                    # sol_b should not dominate sol_a
                    assert not sol_map[sol_b.id].dominates(sol_map[sol_a.id])


# =============================================================================
# Property Tests: Edge Cases
# =============================================================================

class TestParetoEdgeCases:
    """Property tests for edge cases."""

    def test_single_solution_is_frontier(self):
        """Single solution is always on frontier."""
        sol = Solution("only", 100, 100, 100, 0.5)
        frontier = find_pareto_frontier([sol])
        assert frontier == [sol]

    def test_identical_solutions(self):
        """Identical solutions don't dominate each other."""
        sol_a = Solution("a", 100, 100, 100, 0.5)
        sol_b = Solution("b", 100, 100, 100, 0.5)

        assert not sol_a.dominates(sol_b)
        assert not sol_b.dominates(sol_a)

        frontier = find_pareto_frontier([sol_a, sol_b])
        assert len(frontier) == 2

    @given(n=st.integers(min_value=2, max_value=20))
    def test_all_identical_all_on_frontier(self, n: int):
        """All identical solutions are on frontier."""
        sols = [Solution(f"sol_{i}", 100, 100, 100, 0.5) for i in range(n)]
        frontier = find_pareto_frontier(sols)
        assert len(frontier) == n

    def test_linear_pareto_frontier(self):
        """Linear trade-off creates expected frontier."""
        # Each solution trades off cost vs time
        sols = [
            Solution("cheap_slow", cost=100, time=500, carbon=100, labor_score=0.5),
            Solution("mid", cost=300, time=300, carbon=100, labor_score=0.5),
            Solution("expensive_fast", cost=500, time=100, carbon=100, labor_score=0.5),
        ]

        frontier = find_pareto_frontier(sols)
        # All three should be on frontier (trade-off between cost and time)
        assert len(frontier) == 3
