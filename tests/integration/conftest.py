"""
VEDS Integration Test Configuration
Uses Testcontainers for isolated database testing
"""

import pytest
import time
import json
from typing import Generator, Dict, Any

from testcontainers.core.container import DockerContainer
from testcontainers.core.waiting_utils import wait_for_logs
from testcontainers.redis import RedisContainer

import httpx


# =============================================================================
# Container Fixtures
# =============================================================================

@pytest.fixture(scope="session")
def dragonfly_container() -> Generator[RedisContainer, None, None]:
    """Spin up Dragonfly (Redis-compatible) container."""
    # Using Redis container since Dragonfly is Redis-compatible
    with RedisContainer("docker.dragonflydb.io/dragonflydb/dragonfly:latest") as dragonfly:
        dragonfly.with_exposed_ports(6379)
        yield dragonfly


@pytest.fixture(scope="session")
def surrealdb_container() -> Generator[DockerContainer, None, None]:
    """Spin up SurrealDB container."""
    container = DockerContainer("surrealdb/surrealdb:latest")
    container.with_exposed_ports(8000)
    container.with_command("start --user root --pass root memory")
    container.with_env("SURREAL_CAPS_ALLOW_NET", "true")

    container.start()

    # Wait for SurrealDB to be ready
    wait_for_logs(container, "Started web server", timeout=30)
    time.sleep(2)  # Extra buffer

    yield container

    container.stop()


@pytest.fixture(scope="session")
def xtdb_container() -> Generator[DockerContainer, None, None]:
    """Spin up XTDB container."""
    container = DockerContainer("ghcr.io/xtdb/xtdb:2.x")
    container.with_exposed_ports(3000)

    container.start()

    # Wait for XTDB to be ready
    wait_for_logs(container, "XTDB node started", timeout=60)
    time.sleep(3)  # Extra buffer for HTTP server

    yield container

    container.stop()


# =============================================================================
# Connection Fixtures
# =============================================================================

@pytest.fixture(scope="session")
def dragonfly_url(dragonfly_container: RedisContainer) -> str:
    """Get Dragonfly connection URL."""
    host = dragonfly_container.get_container_host_ip()
    port = dragonfly_container.get_exposed_port(6379)
    return f"redis://{host}:{port}"


@pytest.fixture(scope="session")
def surrealdb_url(surrealdb_container: DockerContainer) -> str:
    """Get SurrealDB connection URL."""
    host = surrealdb_container.get_container_host_ip()
    port = surrealdb_container.get_exposed_port(8000)
    return f"http://{host}:{port}"


@pytest.fixture(scope="session")
def xtdb_url(xtdb_container: DockerContainer) -> str:
    """Get XTDB connection URL."""
    host = xtdb_container.get_container_host_ip()
    port = xtdb_container.get_exposed_port(3000)
    return f"http://{host}:{port}"


# =============================================================================
# Client Fixtures
# =============================================================================

@pytest.fixture(scope="session")
def surrealdb_client(surrealdb_url: str):
    """Create SurrealDB HTTP client."""
    import httpx

    client = httpx.Client(
        base_url=surrealdb_url,
        headers={
            "Accept": "application/json",
            "NS": "veds",
            "DB": "transport",
        },
        auth=("root", "root"),
        timeout=30.0,
    )

    # Initialize namespace and database
    client.post("/sql", content="DEFINE NAMESPACE veds; USE NS veds; DEFINE DATABASE transport;")

    yield client

    client.close()


@pytest.fixture(scope="session")
def xtdb_client(xtdb_url: str):
    """Create XTDB HTTP client."""
    client = httpx.Client(
        base_url=xtdb_url,
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        timeout=30.0,
    )
    yield client
    client.close()


# =============================================================================
# Test Data Fixtures
# =============================================================================

@pytest.fixture
def sample_port() -> Dict[str, Any]:
    """Sample port data."""
    return {
        "id": "port:shanghai",
        "name": "Shanghai",
        "country": "CN",
        "lat": 31.2304,
        "lon": 121.4737,
        "capacity_teu": 47000000,
        "port_type": "hub",
    }


@pytest.fixture
def sample_carrier() -> Dict[str, Any]:
    """Sample carrier data."""
    return {
        "id": "carrier:cosco",
        "name": "COSCO Shipping",
        "country": "CN",
        "modes": ["maritime"],
        "fleet_size": 1300,
        "safety_score": 0.92,
    }


@pytest.fixture
def sample_edge() -> Dict[str, Any]:
    """Sample transport edge data."""
    return {
        "id": "edge:shanghai_hongkong_maritime",
        "origin": "port:shanghai",
        "destination": "port:hongkong",
        "mode": "maritime",
        "carrier": "carrier:cosco",
        "distance_km": 1200,
        "time_hours": 48,
        "cost_usd": 2500,
        "carbon_kg": 850,
        "min_wage_cents": 1500,
    }


@pytest.fixture
def sample_constraint() -> Dict[str, Any]:
    """Sample constraint data."""
    return {
        "id": "constraint:ilo_min_wage_de",
        "name": "ILO Minimum Wage (Germany)",
        "category": "wage",
        "is_hard": True,
        "country": "DE",
        "threshold": 1260,
        "operator": ">=",
        "description": "Minimum hourly wage in Germany per ILO standards",
    }


@pytest.fixture
def sample_route_request() -> Dict[str, Any]:
    """Sample route optimization request."""
    return {
        "origin": "port:shanghai",
        "destination": "port:rotterdam",
        "cargo_type": "container",
        "weight_kg": 20000,
        "volume_m3": 33,
        "departure_after": "2025-01-15T00:00:00Z",
        "arrival_before": "2025-02-15T00:00:00Z",
        "max_cost_usd": 15000,
        "carbon_budget_kg": 10000,
        "preferences": {
            "optimize_for": ["cost", "time", "carbon"],
            "weights": [0.4, 0.3, 0.3],
        },
    }
