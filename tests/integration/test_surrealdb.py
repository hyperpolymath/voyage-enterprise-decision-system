"""
SurrealDB Integration Tests
Tests graph operations and transport network queries
"""

import pytest
from typing import Dict, Any


class TestSurrealDBConnection:
    """Test basic SurrealDB connectivity."""

    def test_health_check(self, surrealdb_client):
        """Verify SurrealDB is responding."""
        response = surrealdb_client.get("/health")
        assert response.status_code == 200

    def test_namespace_exists(self, surrealdb_client):
        """Verify namespace was created."""
        response = surrealdb_client.post("/sql", content="INFO FOR NS;")
        assert response.status_code == 200


class TestPortOperations:
    """Test port CRUD operations."""

    def test_create_port(self, surrealdb_client, sample_port):
        """Create a port record."""
        query = f"""
        CREATE port:{sample_port['id'].split(':')[1]} CONTENT {{
            name: '{sample_port['name']}',
            country: '{sample_port['country']}',
            location: {{
                lat: {sample_port['lat']},
                lon: {sample_port['lon']}
            }},
            capacity_teu: {sample_port['capacity_teu']},
            port_type: '{sample_port['port_type']}'
        }};
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

        result = response.json()
        assert len(result) > 0

    def test_query_port(self, surrealdb_client, sample_port):
        """Query port by ID."""
        # First create it
        self.test_create_port(surrealdb_client, sample_port)

        query = f"SELECT * FROM port:{sample_port['id'].split(':')[1]};"
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

        result = response.json()
        assert len(result) > 0

    def test_query_ports_by_country(self, surrealdb_client, sample_port):
        """Query ports filtered by country."""
        self.test_create_port(surrealdb_client, sample_port)

        query = f"SELECT * FROM port WHERE country = '{sample_port['country']}';"
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200


class TestEdgeOperations:
    """Test transport edge (graph) operations."""

    def test_create_edge(self, surrealdb_client, sample_edge):
        """Create a transport edge between ports."""
        # First create origin and destination ports
        surrealdb_client.post("/sql", content="""
        CREATE port:shanghai CONTENT { name: 'Shanghai', country: 'CN' };
        CREATE port:hongkong CONTENT { name: 'Hong Kong', country: 'HK' };
        """)

        # Create edge using RELATE
        query = f"""
        RELATE port:shanghai->transport_edge->port:hongkong CONTENT {{
            mode: '{sample_edge['mode']}',
            carrier: '{sample_edge['carrier']}',
            distance_km: {sample_edge['distance_km']},
            time_hours: {sample_edge['time_hours']},
            cost_usd: {sample_edge['cost_usd']},
            carbon_kg: {sample_edge['carbon_kg']},
            min_wage_cents: {sample_edge['min_wage_cents']}
        }};
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

    def test_query_outgoing_edges(self, surrealdb_client, sample_edge):
        """Query all edges from a port."""
        self.test_create_edge(surrealdb_client, sample_edge)

        query = "SELECT ->transport_edge->port AS destinations FROM port:shanghai;"
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200


class TestGraphTraversal:
    """Test graph traversal queries."""

    @pytest.fixture(autouse=True)
    def setup_graph(self, surrealdb_client):
        """Set up a small test graph."""
        setup_query = """
        -- Clear existing data
        DELETE port;
        DELETE transport_edge;

        -- Create ports
        CREATE port:shanghai CONTENT { name: 'Shanghai', country: 'CN', lat: 31.23, lon: 121.47 };
        CREATE port:singapore CONTENT { name: 'Singapore', country: 'SG', lat: 1.35, lon: 103.82 };
        CREATE port:dubai CONTENT { name: 'Dubai', country: 'AE', lat: 25.20, lon: 55.27 };
        CREATE port:rotterdam CONTENT { name: 'Rotterdam', country: 'NL', lat: 51.92, lon: 4.48 };

        -- Create edges
        RELATE port:shanghai->transport_edge->port:singapore CONTENT {
            mode: 'maritime', distance_km: 3800, time_hours: 96, cost_usd: 1500, carbon_kg: 2000
        };
        RELATE port:singapore->transport_edge->port:dubai CONTENT {
            mode: 'maritime', distance_km: 5800, time_hours: 144, cost_usd: 2500, carbon_kg: 3500
        };
        RELATE port:dubai->transport_edge->port:rotterdam CONTENT {
            mode: 'maritime', distance_km: 6200, time_hours: 168, cost_usd: 3000, carbon_kg: 4000
        };
        RELATE port:shanghai->transport_edge->port:rotterdam CONTENT {
            mode: 'maritime', distance_km: 19000, time_hours: 480, cost_usd: 4500, carbon_kg: 8000
        };
        """
        surrealdb_client.post("/sql", content=setup_query)

    def test_direct_path(self, surrealdb_client):
        """Test direct path query."""
        query = """
        SELECT
            in.name AS origin,
            out.name AS destination,
            mode,
            distance_km,
            cost_usd
        FROM transport_edge
        WHERE in = port:shanghai AND out = port:rotterdam;
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

    def test_two_hop_paths(self, surrealdb_client):
        """Test 2-hop path traversal."""
        query = """
        SELECT
            port:shanghai AS start,
            ->transport_edge->port->transport_edge->port AS two_hops
        FROM ONLY port:shanghai;
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

    def test_aggregate_path_cost(self, surrealdb_client):
        """Test aggregating costs along path."""
        query = """
        SELECT
            math::sum(cost_usd) AS total_cost,
            math::sum(carbon_kg) AS total_carbon,
            math::sum(time_hours) AS total_time
        FROM transport_edge
        WHERE in IN [port:shanghai, port:singapore, port:dubai];
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200


class TestCarrierOperations:
    """Test carrier record operations."""

    def test_create_carrier(self, surrealdb_client, sample_carrier):
        """Create a carrier record."""
        query = f"""
        CREATE carrier:{sample_carrier['id'].split(':')[1]} CONTENT {{
            name: '{sample_carrier['name']}',
            country: '{sample_carrier['country']}',
            modes: {sample_carrier['modes']},
            fleet_size: {sample_carrier['fleet_size']},
            safety_score: {sample_carrier['safety_score']}
        }};
        """
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

    def test_query_carriers_by_mode(self, surrealdb_client, sample_carrier):
        """Query carriers by transport mode."""
        self.test_create_carrier(surrealdb_client, sample_carrier)

        query = "SELECT * FROM carrier WHERE modes CONTAINS 'maritime';"
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200

    def test_query_safe_carriers(self, surrealdb_client, sample_carrier):
        """Query carriers above safety threshold."""
        self.test_create_carrier(surrealdb_client, sample_carrier)

        query = "SELECT * FROM carrier WHERE safety_score >= 0.8;"
        response = surrealdb_client.post("/sql", content=query)
        assert response.status_code == 200
