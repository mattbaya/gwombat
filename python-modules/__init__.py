"""
GWOMBAT Python Modules
Hybrid Architecture: Python Enhancement for Bash-Based GWOMBAT

This package provides Python-based enhancements for GWOMBAT while maintaining
the core bash architecture. Primary focus on SCuBA compliance implementation
and advanced Google Workspace API integration.

Modules:
- scuba_compliance: CISA SCuBA baseline compliance checking
- gws_api: Enhanced Google Workspace API integration
- compliance_dashboard: Advanced compliance reporting and visualization
- config_manager: Python-based configuration validation and management
"""

__version__ = "3.0.0-hybrid"
__author__ = "GWOMBAT Development Team"
__email__ = "gwombat@your-domain.edu"

# Package-level imports for convenience
from .scuba_compliance import ScubaCompliance
from .gws_api import GoogleWorkspaceAPI
from .compliance_dashboard import ComplianceDashboard

__all__ = [
    'ScubaCompliance',
    'GoogleWorkspaceAPI', 
    'ComplianceDashboard'
]