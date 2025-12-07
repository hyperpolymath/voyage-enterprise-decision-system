"""
Property Test Configuration
"""

import pytest
from hypothesis import settings, Verbosity

# Configure Hypothesis for CI environments
settings.register_profile("ci", max_examples=100, deadline=None)
settings.register_profile("dev", max_examples=20, deadline=None)
settings.register_profile("debug", max_examples=10, verbosity=Verbosity.verbose, deadline=None)

# Load profile from environment or use dev as default
settings.load_profile("dev")
