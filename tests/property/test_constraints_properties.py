"""
Property-Based Tests for Constraint Evaluation
Uses Hypothesis for generative testing
"""

import pytest
from hypothesis import given, assume, settings, HealthCheck
from hypothesis import strategies as st
from typing import List, Tuple
from dataclasses import dataclass
from enum import Enum


# =============================================================================
# Domain Models (mirroring Ada/Rust types)
# =============================================================================

class TransportMode(Enum):
    MARITIME = "maritime"
    RAIL = "rail"
    ROAD = "road"
    AIR = "air"


class RiskLevel(Enum):
    NONE = 0
    LOW = 1
    MEDIUM = 2
    HIGH = 3
    CRITICAL = 4


@dataclass
class ConstraintResult:
    passed: bool
    is_hard: bool
    severity: float  # 0.0 to 1.0
    risk: RiskLevel


@dataclass
class Segment:
    origin_lat: float
    origin_lon: float
    dest_lat: float
    dest_lon: float
    mode: TransportMode
    distance_km: int
    weight_kg: int
    cost_cents: int
    time_hours: int
    carbon_kg: int
    wage_cents: int
    safety_score: float


# =============================================================================
# Constraint Functions (Python reference implementation)
# =============================================================================

ILO_MINIMUMS = {
    "DE": 1260,
    "NL": 1355,
    "CN": 350,
    "SG": 0,
}

CARBON_FACTORS = {
    TransportMode.MARITIME: 15,
    TransportMode.RAIL: 28,
    TransportMode.ROAD: 62,
    TransportMode.AIR: 500,
}


def check_minimum_wage(actual_wage: int, country: str) -> ConstraintResult:
    """Check if wage meets ILO minimum for country."""
    minimum = ILO_MINIMUMS.get(country, 500)

    if actual_wage >= minimum:
        return ConstraintResult(True, False, 0.0, RiskLevel.NONE)

    shortfall = minimum - actual_wage
    if shortfall > minimum / 2:
        severity = 1.0
    elif shortfall > minimum / 4:
        severity = 0.7
    else:
        severity = 0.4

    return ConstraintResult(False, True, severity, RiskLevel.HIGH)


def check_working_time(weekly_hours: int) -> ConstraintResult:
    """Check EU Working Time Directive compliance."""
    if weekly_hours <= 48:
        return ConstraintResult(True, False, 0.0, RiskLevel.NONE)
    elif weekly_hours <= 60:
        return ConstraintResult(False, False, 0.5, RiskLevel.MEDIUM)
    else:
        return ConstraintResult(False, True, 0.9, RiskLevel.HIGH)


def check_carbon_budget(actual: int, budget: int) -> ConstraintResult:
    """Check if carbon is within budget."""
    if actual <= budget:
        return ConstraintResult(True, False, 0.0, RiskLevel.NONE)

    overage = actual - budget
    if budget > 0:
        if overage > budget / 2:
            severity = 0.9
        elif overage > budget / 4:
            severity = 0.6
        else:
            severity = 0.3
    else:
        severity = 1.0

    return ConstraintResult(False, False, severity, RiskLevel.MEDIUM)


def check_safety_score(score: float, threshold: float) -> ConstraintResult:
    """Check route safety score."""
    if score >= threshold:
        return ConstraintResult(True, False, 0.0, RiskLevel.NONE)

    severity = 1.0 - score
    if score < 0.5:
        risk = RiskLevel.CRITICAL
    elif score < 0.7:
        risk = RiskLevel.HIGH
    else:
        risk = RiskLevel.MEDIUM

    return ConstraintResult(False, True, severity, risk)


def calculate_segment_carbon(distance_km: int, weight_kg: int, mode: TransportMode) -> int:
    """Calculate carbon emissions for segment."""
    factor = CARBON_FACTORS[mode]
    # (distance * weight / 1000) * factor / 1000 = kg CO2
    tonne_km = distance_km * weight_kg // 1000
    carbon = tonne_km * factor // 1000
    return min(carbon, 100_000_000)  # Cap at 100k tonnes


def safe_add(a: int, b: int, max_val: int) -> int:
    """Overflow-safe addition."""
    if max_val - a >= b:
        return a + b
    return max_val


# =============================================================================
# Hypothesis Strategies
# =============================================================================

wage_cents = st.integers(min_value=0, max_value=50000)
country_codes = st.sampled_from(["DE", "NL", "CN", "SG", "US", "GB", "FR"])
weekly_hours = st.integers(min_value=0, max_value=168)
carbon_kg = st.integers(min_value=0, max_value=100_000_000)
safety_scores = st.floats(min_value=0.0, max_value=1.0, allow_nan=False)
distance_km = st.integers(min_value=0, max_value=25000)
weight_kg = st.integers(min_value=0, max_value=30000)
transport_modes = st.sampled_from(list(TransportMode))
cost_cents = st.integers(min_value=0, max_value=10_000_000_000_00)


@st.composite
def segments(draw) -> Segment:
    """Generate random valid segments."""
    return Segment(
        origin_lat=draw(st.floats(min_value=-90, max_value=90)),
        origin_lon=draw(st.floats(min_value=-180, max_value=180)),
        dest_lat=draw(st.floats(min_value=-90, max_value=90)),
        dest_lon=draw(st.floats(min_value=-180, max_value=180)),
        mode=draw(transport_modes),
        distance_km=draw(distance_km),
        weight_kg=draw(weight_kg),
        cost_cents=draw(st.integers(min_value=0, max_value=1_000_000_00)),
        time_hours=draw(st.integers(min_value=0, max_value=2160)),
        carbon_kg=draw(st.integers(min_value=0, max_value=100_000_000)),
        wage_cents=draw(wage_cents),
        safety_score=draw(safety_scores),
    )


# =============================================================================
# Property Tests: Wage Constraints
# =============================================================================

class TestWageConstraintProperties:
    """Property-based tests for wage constraint checking."""

    @given(wage=wage_cents, country=country_codes)
    def test_wage_result_has_valid_severity(self, wage: int, country: str):
        """Severity is always between 0 and 1."""
        result = check_minimum_wage(wage, country)
        assert 0.0 <= result.severity <= 1.0

    @given(wage=wage_cents, country=country_codes)
    def test_wage_pass_implies_zero_severity(self, wage: int, country: str):
        """If constraint passes, severity should be 0."""
        result = check_minimum_wage(wage, country)
        if result.passed:
            assert result.severity == 0.0

    @given(wage=wage_cents, country=country_codes)
    def test_wage_fail_implies_positive_severity(self, wage: int, country: str):
        """If constraint fails, severity should be positive."""
        result = check_minimum_wage(wage, country)
        if not result.passed:
            assert result.severity > 0.0

    @given(country=country_codes)
    def test_wage_at_minimum_passes(self, country: str):
        """Wage exactly at minimum should pass."""
        minimum = ILO_MINIMUMS.get(country, 500)
        result = check_minimum_wage(minimum, country)
        assert result.passed

    @given(country=country_codes)
    def test_wage_above_minimum_passes(self, country: str):
        """Wage above minimum should always pass."""
        minimum = ILO_MINIMUMS.get(country, 500)
        result = check_minimum_wage(minimum + 1, country)
        assert result.passed

    @given(wage=st.integers(min_value=0, max_value=100))
    def test_very_low_wage_fails_for_germany(self, wage: int):
        """Very low wages should fail for Germany."""
        assume(wage < 1260)  # German minimum
        result = check_minimum_wage(wage, "DE")
        assert not result.passed
        assert result.is_hard  # Wage violations are hard constraints


# =============================================================================
# Property Tests: Working Time
# =============================================================================

class TestWorkingTimeProperties:
    """Property-based tests for working time constraints."""

    @given(hours=weekly_hours)
    def test_working_time_valid_severity(self, hours: int):
        """Severity is always valid."""
        result = check_working_time(hours)
        assert 0.0 <= result.severity <= 1.0

    @given(hours=st.integers(min_value=0, max_value=48))
    def test_legal_hours_always_pass(self, hours: int):
        """Hours within EU limit always pass."""
        result = check_working_time(hours)
        assert result.passed

    @given(hours=st.integers(min_value=49, max_value=60))
    def test_overtime_is_soft_violation(self, hours: int):
        """Moderate overtime is soft violation."""
        result = check_working_time(hours)
        assert not result.passed
        assert not result.is_hard  # Soft violation

    @given(hours=st.integers(min_value=61, max_value=168))
    def test_excessive_overtime_is_hard_violation(self, hours: int):
        """Excessive overtime is hard violation."""
        result = check_working_time(hours)
        assert not result.passed
        assert result.is_hard


# =============================================================================
# Property Tests: Carbon Budget
# =============================================================================

class TestCarbonBudgetProperties:
    """Property-based tests for carbon budget constraints."""

    @given(actual=carbon_kg, budget=carbon_kg)
    def test_carbon_within_budget_passes(self, actual: int, budget: int):
        """Carbon at or below budget always passes."""
        assume(actual <= budget)
        result = check_carbon_budget(actual, budget)
        assert result.passed

    @given(actual=carbon_kg, budget=carbon_kg)
    def test_carbon_over_budget_fails(self, actual: int, budget: int):
        """Carbon over budget always fails."""
        assume(actual > budget)
        result = check_carbon_budget(actual, budget)
        assert not result.passed

    @given(actual=carbon_kg, budget=carbon_kg)
    def test_carbon_is_soft_constraint(self, actual: int, budget: int):
        """Carbon constraints are always soft."""
        result = check_carbon_budget(actual, budget)
        assert not result.is_hard


# =============================================================================
# Property Tests: Safety Score
# =============================================================================

class TestSafetyScoreProperties:
    """Property-based tests for safety constraints."""

    @given(score=safety_scores, threshold=safety_scores)
    def test_safety_above_threshold_passes(self, score: float, threshold: float):
        """Score at or above threshold passes."""
        assume(score >= threshold)
        result = check_safety_score(score, threshold)
        assert result.passed

    @given(score=safety_scores, threshold=safety_scores)
    def test_safety_below_threshold_fails(self, score: float, threshold: float):
        """Score below threshold fails."""
        assume(score < threshold)
        result = check_safety_score(score, threshold)
        assert not result.passed

    @given(score=safety_scores, threshold=safety_scores)
    def test_safety_failure_is_hard(self, score: float, threshold: float):
        """Safety violations are hard constraints."""
        result = check_safety_score(score, threshold)
        if not result.passed:
            assert result.is_hard

    @given(score=st.floats(min_value=0.0, max_value=0.49))
    def test_very_unsafe_is_critical(self, score: float):
        """Very low safety scores are critical risk."""
        result = check_safety_score(score, 0.7)
        assert result.risk == RiskLevel.CRITICAL


# =============================================================================
# Property Tests: Carbon Calculation
# =============================================================================

class TestCarbonCalculationProperties:
    """Property-based tests for carbon calculation."""

    @given(distance=distance_km, weight=weight_kg, mode=transport_modes)
    def test_carbon_is_non_negative(self, distance: int, weight: int, mode: TransportMode):
        """Carbon emissions are always non-negative."""
        carbon = calculate_segment_carbon(distance, weight, mode)
        assert carbon >= 0

    @given(distance=distance_km, weight=weight_kg, mode=transport_modes)
    def test_carbon_is_bounded(self, distance: int, weight: int, mode: TransportMode):
        """Carbon emissions are bounded by max value."""
        carbon = calculate_segment_carbon(distance, weight, mode)
        assert carbon <= 100_000_000

    @given(distance=distance_km, weight=weight_kg)
    def test_air_has_highest_carbon(self, distance: int, weight: int):
        """Air transport produces most carbon."""
        assume(distance > 0 and weight > 0)

        air_carbon = calculate_segment_carbon(distance, weight, TransportMode.AIR)
        maritime_carbon = calculate_segment_carbon(distance, weight, TransportMode.MARITIME)
        rail_carbon = calculate_segment_carbon(distance, weight, TransportMode.RAIL)
        road_carbon = calculate_segment_carbon(distance, weight, TransportMode.ROAD)

        assert air_carbon >= maritime_carbon
        assert air_carbon >= rail_carbon
        assert air_carbon >= road_carbon

    @given(distance=distance_km, weight=weight_kg)
    def test_maritime_has_lowest_carbon(self, distance: int, weight: int):
        """Maritime transport produces least carbon."""
        assume(distance > 0 and weight > 0)

        maritime_carbon = calculate_segment_carbon(distance, weight, TransportMode.MARITIME)
        rail_carbon = calculate_segment_carbon(distance, weight, TransportMode.RAIL)
        road_carbon = calculate_segment_carbon(distance, weight, TransportMode.ROAD)

        assert maritime_carbon <= rail_carbon
        assert maritime_carbon <= road_carbon

    @given(distance=distance_km, weight=weight_kg, mode=transport_modes)
    def test_zero_distance_zero_carbon(self, distance: int, weight: int, mode: TransportMode):
        """Zero distance means zero carbon."""
        assume(distance == 0 or weight == 0)
        carbon = calculate_segment_carbon(distance, weight, mode)
        assert carbon == 0


# =============================================================================
# Property Tests: Safe Arithmetic
# =============================================================================

class TestSafeArithmeticProperties:
    """Property-based tests for overflow-safe operations."""

    @given(a=cost_cents, b=cost_cents)
    def test_safe_add_never_overflows(self, a: int, b: int):
        """Safe add never produces overflow."""
        max_val = 10_000_000_000_00
        result = safe_add(a, b, max_val)
        assert result <= max_val

    @given(a=cost_cents, b=cost_cents)
    def test_safe_add_correct_when_no_overflow(self, a: int, b: int):
        """Safe add returns correct sum when no overflow."""
        max_val = 10_000_000_000_00
        assume(a + b <= max_val)
        result = safe_add(a, b, max_val)
        assert result == a + b

    @given(a=cost_cents, b=cost_cents)
    def test_safe_add_returns_max_on_overflow(self, a: int, b: int):
        """Safe add returns max value on overflow."""
        max_val = 10_000_000_000_00
        assume(a + b > max_val)
        result = safe_add(a, b, max_val)
        assert result == max_val


# =============================================================================
# Property Tests: Route Segments
# =============================================================================

class TestRouteSegmentProperties:
    """Property-based tests for route segment operations."""

    @given(seg=segments())
    def test_segment_coordinates_valid(self, seg: Segment):
        """Segment coordinates are within valid ranges."""
        assert -90 <= seg.origin_lat <= 90
        assert -90 <= seg.dest_lat <= 90
        assert -180 <= seg.origin_lon <= 180
        assert -180 <= seg.dest_lon <= 180

    @given(seg=segments())
    def test_segment_safety_valid(self, seg: Segment):
        """Segment safety score is valid."""
        assert 0.0 <= seg.safety_score <= 1.0

    @given(segs=st.lists(segments(), min_size=1, max_size=20))
    @settings(suppress_health_check=[HealthCheck.too_slow])
    def test_total_cost_non_negative(self, segs: List[Segment]):
        """Total route cost is non-negative."""
        total = 0
        max_val = 10_000_000_000_00
        for seg in segs:
            total = safe_add(total, seg.cost_cents, max_val)
        assert total >= 0

    @given(segs=st.lists(segments(), min_size=1, max_size=20))
    @settings(suppress_health_check=[HealthCheck.too_slow])
    def test_total_time_bounded(self, segs: List[Segment]):
        """Total route time is bounded."""
        total = sum(seg.time_hours for seg in segs)
        assert total <= 20 * 2160  # 20 segments * max per segment
