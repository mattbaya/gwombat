# GWOMBAT Python Modules
## Hybrid Architecture: Python Enhancement for Bash-Based GWOMBAT

This directory contains Python-based enhancements for GWOMBAT that extend the core bash functionality with advanced capabilities for compliance checking, API integration, and sophisticated reporting.

## Architecture Overview

GWOMBAT v3.0 implements a **hybrid architecture** that combines:
- **Core bash infrastructure** for Google Workspace management and account lifecycle operations
- **Python modules** for advanced compliance checking, API integration, and data analysis
- **Seamless integration** through bash bridge scripts that call Python modules when needed

## Key Components

### 1. SCuBA Compliance Module (`scuba_compliance.py`)
Implements CISA Secure Cloud Business Applications (SCuBA) security baselines for Google Workspace:

- **Comprehensive baseline checking** for 9 Google Workspace services
- **Automated compliance assessment** using GAM commands and Google APIs
- **Gap analysis and risk scoring** with detailed remediation guidance
- **Database integration** for persistent compliance tracking and history

**Supported Services:**
- Gmail (email security settings and policies)
- Calendar (sharing and access controls)
- Drive & Docs (file sharing and collaboration)
- Google Meet (meeting security and recording)
- Google Chat (messaging security)
- Groups for Business (group membership and access)
- Google Classroom (educational environment security)
- Google Sites (website publishing controls)
- Common Controls (cross-service security settings)

### 2. Google Workspace API Integration (`gws_api.py`)
Enhanced Google Workspace API capabilities that complement GAM operations:

- **Direct API access** for advanced compliance checking
- **2-Step Verification enforcement monitoring**
- **Admin activity analysis** with detailed audit logs
- **Domain and organizational unit structure analysis**
- **Gmail, Drive, and Calendar security settings inspection**

### 3. Compliance Dashboard (`compliance_dashboard.py`)
Advanced reporting and visualization for compliance management:

- **Interactive compliance dashboard** with real-time statistics
- **Executive summary reporting** for stakeholder communication
- **Trend analysis** showing compliance improvements over time
- **Remediation tracking** with priority management and assignment
- **Export capabilities** for external reporting and documentation

## Installation and Setup

### Prerequisites
- Python 3.7+ (Python 3.8+ recommended)
- pip (Python package installer)
- GWOMBAT v3.0 bash infrastructure

### 1. Install Python Dependencies
```bash
# From GWOMBAT root directory
pip3 install -r python-modules/requirements.txt
```

### 2. Optional: Configure Google Workspace API Access
For enhanced functionality beyond GAM capabilities:

1. **Create Google Cloud Project** (if not exists)
2. **Enable Google Workspace Admin SDK APIs**
3. **Create OAuth2 credentials** for desktop application
4. **Download credentials JSON** and save as `./config/gws_credentials.json`

### 3. Initialize SCuBA Compliance
```bash
# Through GWOMBAT main menu: Option 9 → SCuBA Compliance Management
# Or directly:
./shared-utilities/scuba_compliance_bridge.sh setup-python
```

## Usage Examples

### Command Line Interface
Each Python module can be used independently:

```bash
# SCuBA compliance assessment
python3 -m python-modules.scuba_compliance --services gmail drive --output table

# Google Workspace API test
python3 -m python-modules.gws_api --action security-snapshot --output json

# Compliance dashboard
python3 -m python-modules.compliance_dashboard --action dashboard
```

### Integration with GWOMBAT
Python modules are seamlessly integrated through bash bridge scripts:

```bash
# Through main GWOMBAT menu
./gwombat.sh
# Select: 9. SCuBA Compliance Management

# Direct bridge access
./shared-utilities/scuba_compliance_bridge.sh menu
```

### Configuration Management
SCuBA compliance settings are managed through GWOMBAT's configuration system:

```bash
# Enable/disable SCuBA compliance
./shared-utilities/config_manager.sh set scuba compliance_enabled true

# Check Python environment
./shared-utilities/scuba_compliance_bridge.sh check-python
```

## Database Schema Integration

The Python modules integrate with GWOMBAT's SQLite database using dedicated schemas:

- **`scuba_compliance_schema.sql`** - Compliance baselines, results, and remediation tracking
- **`gws_api_data` table** - Google Workspace API data storage
- **Configuration integration** through existing `gwombat_config` table

## Module Architecture

### Modular Design
Each Python module is designed for:
- **Independence** - Can be used standalone or integrated
- **Error resilience** - Graceful degradation when dependencies unavailable
- **Logging integration** - Full integration with GWOMBAT's logging system
- **Configuration management** - Uses GWOMBAT's centralized configuration

### Data Flow
```
GAM Commands ←→ Python Modules ←→ Google Workspace APIs
        ↓              ↓                    ↓
    GWOMBAT Database ←→ Compliance Engine ←→ Dashboard
        ↓              ↓                    ↓
    Bash Scripts ←→ Bridge Scripts ←→ User Interface
```

## Development and Extension

### Adding New Compliance Baselines
1. **Update database schema** in `scuba_compliance_schema.sql`
2. **Add baseline definitions** to `scuba_baselines` table
3. **Implement check logic** in `scuba_compliance.py`
4. **Test with specific services** using command line interface

### Creating Custom Reports
1. **Extend `compliance_dashboard.py`** with new report types
2. **Add database queries** for required data
3. **Implement visualization** using rich library or export to JSON
4. **Integrate with bridge script** for bash access

### API Integration
1. **Extend `gws_api.py`** with new Google Workspace APIs
2. **Add authentication scopes** as needed
3. **Implement data collection methods**
4. **Store results** in database for compliance analysis

## Security Considerations

### Data Protection
- **OAuth2 tokens** stored in `./config/` directory with restricted permissions
- **Sensitive data** marked in database schema for appropriate handling
- **API rate limiting** implemented to prevent abuse
- **Error handling** prevents credential exposure in logs

### Access Control
- **Feature enablement** through configuration management
- **User opt-out capabilities** for all automated features
- **Audit logging** for all compliance operations
- **Role-based access** through GWOMBAT's user management

## Troubleshooting

### Common Issues

**Python Import Errors:**
```bash
# Install missing dependencies
pip3 install -r python-modules/requirements.txt

# Check Python path
python3 -c "import sys; print(sys.path)"
```

**Google API Authentication:**
```bash
# Test API authentication
python3 -m python-modules.gws_api --action test-auth

# Reset OAuth tokens
rm ./config/gws_token.json
```

**Database Issues:**
```bash
# Initialize schemas
sqlite3 ./config/gwombat.db < scuba_compliance_schema.sql

# Check table structure
sqlite3 ./config/gwombat.db ".schema scuba_baselines"
```

### Debug Mode
Enable verbose logging for troubleshooting:
```bash
python3 -m python-modules.scuba_compliance --verbose
```

## Contributing

When contributing to the Python modules:

1. **Maintain compatibility** with existing bash infrastructure
2. **Follow GWOMBAT's configuration patterns**
3. **Include comprehensive error handling**
4. **Update documentation** for new features
5. **Test integration** through bridge scripts
6. **Consider opt-out mechanisms** for new features

## Future Enhancements

Planned improvements for the hybrid architecture:

- **Enhanced visualization** with matplotlib integration
- **Advanced compliance analytics** with trend prediction
- **Custom baseline definitions** through web interface
- **Integration with external SIEM systems**
- **Automated remediation** for low-risk compliance gaps
- **Multi-tenant support** for managing multiple domains

## Version Compatibility

- **GWOMBAT v3.0+** - Full hybrid architecture support
- **Python 3.7+** - Minimum required Python version
- **GAM/GAMADV-XS3** - Compatible with all GAM versions
- **Google Workspace APIs** - Admin SDK v1, Reports API v1, Drive API v3

This hybrid architecture ensures that GWOMBAT users can benefit from advanced Python-based functionality while maintaining the reliability and simplicity of the core bash infrastructure.