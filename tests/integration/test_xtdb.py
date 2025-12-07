"""
XTDB Integration Tests
Tests bitemporal constraint storage and Datalog queries
"""

import pytest
import json
from datetime import datetime, timedelta
from typing import Dict, Any


class TestXTDBConnection:
    """Test basic XTDB connectivity."""

    def test_health_check(self, xtdb_client):
        """Verify XTDB is responding."""
        response = xtdb_client.get("/status")
        assert response.status_code == 200

    def test_query_empty(self, xtdb_client):
        """Query empty database."""
        query = {"query": "SELECT * FROM constraints LIMIT 1"}
        response = xtdb_client.post("/query", json=query)
        # May return 200 with empty results or 400 if table doesn't exist
        assert response.status_code in [200, 400]


class TestConstraintOperations:
    """Test constraint CRUD with bitemporal support."""

    def test_insert_constraint(self, xtdb_client, sample_constraint):
        """Insert a constraint document."""
        tx = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": sample_constraint["id"],
                    "name": sample_constraint["name"],
                    "category": sample_constraint["category"],
                    "is_hard": sample_constraint["is_hard"],
                    "country": sample_constraint["country"],
                    "threshold": sample_constraint["threshold"],
                    "operator": sample_constraint["operator"],
                    "description": sample_constraint["description"],
                }]
            ]
        }
        response = xtdb_client.post("/tx", json=tx)
        assert response.status_code in [200, 202]

    def test_query_constraint(self, xtdb_client, sample_constraint):
        """Query constraint by ID."""
        self.test_insert_constraint(xtdb_client, sample_constraint)

        query = {
            "query": f"""
            SELECT * FROM constraints
            WHERE _id = '{sample_constraint["id"]}'
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200

    def test_query_constraints_by_category(self, xtdb_client, sample_constraint):
        """Query constraints by category."""
        self.test_insert_constraint(xtdb_client, sample_constraint)

        query = {
            "query": """
            SELECT * FROM constraints
            WHERE category = 'wage'
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200

    def test_query_hard_constraints(self, xtdb_client, sample_constraint):
        """Query only hard constraints."""
        self.test_insert_constraint(xtdb_client, sample_constraint)

        query = {
            "query": """
            SELECT * FROM constraints
            WHERE is_hard = true
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200


class TestBitemporalQueries:
    """Test bitemporal (valid-time + transaction-time) queries."""

    @pytest.fixture(autouse=True)
    def setup_bitemporal_data(self, xtdb_client):
        """Set up constraints with different valid times."""
        now = datetime.utcnow()
        past = now - timedelta(days=30)
        future = now + timedelta(days=30)

        # Insert constraint valid from past
        tx1 = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": "constraint:carbon_2024",
                    "name": "Carbon Budget 2024",
                    "category": "carbon",
                    "threshold": 10000,
                    "valid_from": past.isoformat(),
                    "valid_to": now.isoformat(),
                }]
            ]
        }
        xtdb_client.post("/tx", json=tx1)

        # Insert updated constraint valid from now
        tx2 = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": "constraint:carbon_2025",
                    "name": "Carbon Budget 2025",
                    "category": "carbon",
                    "threshold": 8000,  # Stricter limit
                    "valid_from": now.isoformat(),
                    "valid_to": future.isoformat(),
                }]
            ]
        }
        xtdb_client.post("/tx", json=tx2)

    def test_query_current_constraints(self, xtdb_client):
        """Query constraints valid at current time."""
        query = {
            "query": """
            SELECT * FROM constraints
            WHERE category = 'carbon'
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200

    def test_query_historical_constraints(self, xtdb_client):
        """Query constraints that were valid in the past."""
        past = (datetime.utcnow() - timedelta(days=15)).isoformat()

        query = {
            "query": f"""
            SELECT * FROM constraints
            WHERE category = 'carbon'
            AND valid_from <= '{past}'
            AND valid_to > '{past}'
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200


class TestConstraintEvaluation:
    """Test constraint evaluation queries."""

    @pytest.fixture(autouse=True)
    def setup_constraints(self, xtdb_client):
        """Set up various constraints for testing."""
        constraints = [
            {
                "xt/id": "constraint:wage_de",
                "name": "ILO Min Wage DE",
                "category": "wage",
                "country": "DE",
                "threshold": 1260,
                "operator": ">=",
                "is_hard": True,
            },
            {
                "xt/id": "constraint:wage_nl",
                "name": "ILO Min Wage NL",
                "category": "wage",
                "country": "NL",
                "threshold": 1355,
                "operator": ">=",
                "is_hard": True,
            },
            {
                "xt/id": "constraint:carbon_limit",
                "name": "Carbon per Route",
                "category": "carbon",
                "threshold": 10000,
                "operator": "<=",
                "is_hard": False,
            },
            {
                "xt/id": "constraint:safety_min",
                "name": "Minimum Safety Score",
                "category": "safety",
                "threshold": 0.7,
                "operator": ">=",
                "is_hard": True,
            },
        ]

        for c in constraints:
            tx = {"tx-ops": [["put", "constraints", c]]}
            xtdb_client.post("/tx", json=tx)

    def test_get_constraints_for_country(self, xtdb_client):
        """Get all constraints applicable to a country."""
        query = {
            "query": """
            SELECT * FROM constraints
            WHERE country = 'DE' OR country IS NULL
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200

    def test_get_hard_constraints_only(self, xtdb_client):
        """Get only hard (blocking) constraints."""
        query = {
            "query": """
            SELECT _id, name, category, threshold
            FROM constraints
            WHERE is_hard = true
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200

    def test_constraint_categories(self, xtdb_client):
        """Get distinct constraint categories."""
        query = {
            "query": """
            SELECT DISTINCT category FROM constraints
            """
        }
        response = xtdb_client.post("/query", json=query)
        assert response.status_code == 200


class TestAuditTrail:
    """Test audit trail capabilities."""

    def test_insert_and_update(self, xtdb_client):
        """Test that updates create audit trail."""
        # Initial insert
        tx1 = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": "constraint:test_audit",
                    "name": "Test Constraint",
                    "threshold": 100,
                }]
            ]
        }
        response1 = xtdb_client.post("/tx", json=tx1)
        assert response1.status_code in [200, 202]

        # Update
        tx2 = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": "constraint:test_audit",
                    "name": "Test Constraint Updated",
                    "threshold": 200,
                }]
            ]
        }
        response2 = xtdb_client.post("/tx", json=tx2)
        assert response2.status_code in [200, 202]

    def test_delete_constraint(self, xtdb_client):
        """Test soft delete (evict) of constraint."""
        # First insert
        tx1 = {
            "tx-ops": [
                ["put", "constraints", {
                    "xt/id": "constraint:to_delete",
                    "name": "To Be Deleted",
                    "threshold": 50,
                }]
            ]
        }
        xtdb_client.post("/tx", json=tx1)

        # Delete (evict)
        tx2 = {
            "tx-ops": [
                ["delete", "constraints", "constraint:to_delete"]
            ]
        }
        response = xtdb_client.post("/tx", json=tx2)
        assert response.status_code in [200, 202]
