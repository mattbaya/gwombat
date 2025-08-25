![GWOMBAT Logo](assets/gwombat2.png)

# GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner

A comprehensive Google Workspace administration system with revolutionary SQLite-driven dynamic interfaces, enterprise-grade account lifecycle management, and advanced automation capabilities.

## 🚀 Revolutionary Features

- **🔄 Dynamic Menu System** - SQLite-driven interfaces with intelligent search across 43+ operations
- **👥 Comprehensive User Management** - Complete lifecycle from creation to deletion with database tracking
- **🔍 Intelligent Search** - Real-time keyword search across all menu options with contextual results
- **📋 Alphabetical Index** - Complete operation catalog with navigation paths
- **📊 CSV Export System** - Comprehensive data export for users, shared drives, account lists, and custom queries
- **🧪 Test Domain Management** - Safe production/test domain switching with automated backup/restore
- **⚙️ External Tools Integration** - Synchronized GAM, GYB, and rclone domain configuration
- **🔐 Advanced Security** - Domain verification, audit trails, and secure deployment
- **📊 Python Integration** - Compliance dashboards and API interfaces
- **🏗️ Multi-Schema Database** - Specialized schemas for different functional domains
- **🔧 GAM Command Transparency** - All GAM commands displayed and logged for complete visibility

## 🎯 Core Menu Categories

### 👥 User & Group Management (17 operations)
- **Account Discovery & Scanning** - Automated domain account scanning and categorization
- **Account Management** - Individual and bulk user operations
- **Group & License Management** - Comprehensive group membership and license administration
- **Suspended Account Lifecycle** - Configurable workflow with customizable stages
- **Workflow Configuration** - Design custom suspension stages and transitions
- **Reports & Analytics** - User statistics and lifecycle reporting

### 💾 Data & File Operations (12 operations)
- **File & Drive Operations** - Bulk operations, shared drive management, permissions
- **CSV Data Export** - Comprehensive export system for users, shared drives, account lists, and custom GAM queries
- **Analysis & Discovery** - File sharing analysis, account discovery, diagnostics
- **Account List Management** - Database-driven batch operations with progress tracking

### 📊 System & Monitoring (32 operations) 
- **System Overview** - 15 system monitoring, health checks, and maintenance tools (SQLite-driven)
- **Dashboard & Statistics** - 17 dashboard operations, security reports, backup tools, and database management (SQLite-driven)
- **Production-Ready Focus** - Only working features displayed, all placeholders removed
- **Reports & Monitoring** - Activity reports, log management, performance analysis
- **System Administration** - Configuration, maintenance, and backup operations

### 🔐 Security & Compliance (3 operations)
- **SCuBA Compliance Management** - CISA security baseline monitoring and reporting

### ⚙️ Configuration Management
- **External Tools Configuration** - GAM, GYB, rclone domain synchronization
- **Test Domain Management** - Production/test domain switching with backup/restore
- **System Setup & Settings** - Environment configuration and deployment management

## 🎯 Recent Feature Updates (August 2025)

### 🔄 SQLite Menu Conversions
- **System Overview Menu** - Converted from hardcoded to SQLite-driven with 15 monitoring options
- **Dashboard & Statistics Menu** - Converted with 17 organized dashboard operations  
- **Function Dispatchers** - Dynamic function resolution and execution
- **Configuration Cleanup** - Removed all server.env references, unified to local-config/.env

### 📊 CSV Export System
Export any GWOMBAT data to CSV format for external analysis:
- **User Data Export** - All users, suspended users, active users, or custom queries
- **Shared Drive Export** - Complete shared drive listings with metadata
- **Account List Export** - Export database-managed account lists
- **Custom GAM Queries** - Export results from any GAM command
- **Automated Metadata** - Export timestamps, descriptions, and record counts
- **File Management** - Organized exports directory with cleanup tools

### 🧪 Test Domain Management
Safely switch between production and test Google Workspace domains:
- **Multi-Domain Configuration** - Configure up to 3 test domains plus production
- **Safe Domain Switching** - Automatic configuration backup before changes
- **GAM Connectivity Testing** - Verify domain connectivity before switching
- **Test Mode Safety** - Enhanced confirmations and dry-run options in test domains
- **Configuration Backup/Restore** - Full configuration history and rollback capability
- **Production Protection** - Clear indicators and safety checks when in test mode

## 🏗️ Revolutionary Architecture

### SQLite-Driven Dynamic Interfaces
- **8 Converted Menus** - system_overview_menu, dashboard_menu, account_analysis_menu, and 5 others now SQLite-driven
- **Dynamic Function Resolution** - Menu choices resolved via database with function dispatchers  
- **Self-Maintaining** - Menus automatically reflect database changes
- **Intelligent Search** - Advanced keyword matching with relevance scoring
- **Category Organization** - Automatic section headers and visual grouping
- **Performance Optimized** - Cached search results and indexed lookups

### Multi-Schema Database Design
- **Primary Schema** - Account lifecycle, lists, verification, audit logging
- **Menu Schema** - Dynamic menu system with search optimization  
- **Specialized Schemas** - SCuBA compliance, configuration, security, backups
- **View-Based Search** - Optimized search interface across all data

### Enterprise Security Features
- **Domain Verification** - Automatic verification GAM domain matches configuration
- **Environment Isolation** - All secrets in .env files, nothing hardcoded
- **Complete Audit Trail** - Every operation logged with session correlation
- **SSH Key Deployment** - Secure automated deployment with key management
- **Clean Git History** - No sensitive data in version control

## 📋 Requirements

### Required
- **Linux/macOS** - Primary platforms
- **Bash 4.0+** - Shell environment  
- **GAM** - Google Apps Manager ([GAM7 compatible](https://github.com/GAM-team/GAM))
- **SQLite** - Multi-schema database backend
- **Git** - Version control and deployment

### Optional Advanced Features
- **Python 3.12+** - Compliance modules and dashboard capabilities
  - Required Python packages (install via `pip install -r python-modules/requirements.txt`):
    - `google-api-python-client>=2.100.0` - Google Workspace API integration
    - `google-auth>=2.22.0` - Authentication for Google APIs
    - `pandas>=2.0.3` - Data analysis and reporting
    - `matplotlib>=3.7.2` - Compliance charts and visualizations
    - See `python-modules/requirements.txt` for complete list
- **GYB** - Gmail backup with domain synchronization
- **rclone** - Cloud storage synchronization
- **SSH/expect** - Automated deployment and interactive prompts

## 🚀 Quick Start

```bash
# Clone and setup
git clone git@github.com:mattbaya/gwombat.git
cd gwombat

# Run the interactive setup wizard (handles everything automatically)
./shared-utilities/setup_wizard.sh

# The setup wizard will:
# 1. Ask for your personal Google Workspace admin account
# 2. Configure GAM with proper OAuth setup (gam create project + gam oauth create)
# 3. Optionally create a GWOMBAT service account with proper admin privileges
# 4. Query existing OUs and configure organizational structure
# 5. Set up Python virtual environment with all required packages (including jinja2)
# 6. Initialize the menu database
# 7. Configure optional tools (GYB, rclone)

# Launch GWOMBAT
./gwombat.sh

# Try the new features:
# - Press 's' for intelligent search
# - Press 'i' for alphabetical index
# - Navigate to User & Group Management for integrated lifecycle
# - File & Drive Operations → CSV Data Export for data export
# - Configuration → Test Domain Management for safe testing
```

## 🗂️ Perfect Security-Conscious Organization

GWOMBAT follows strict organizational principles for security, maintainability, and deployment:

### 🔐 Organizational Principles
- **🔒 Complete Data Separation**: All private data isolated in `local-config/` (excluded from version control)
- **📦 Centralized Scripts**: All 48+ utility scripts organized in `shared-utilities/`
- **⚙️ Application Configuration**: Database schemas and application config in `shared-config/`
- **🧹 Clean Root Directory**: Only main application and documentation in root
- **🚫 Zero Leakage**: No private data, logs, exports, or temporary files outside `local-config/`

### 📁 Directory Structure
```
gwombat/
├── gwombat.sh                    # Main application (only script in root)
├── .env-template                 # Configuration template (version controlled)
├── README.md                     # Project documentation
├── CLAUDE.md                     # AI development context
├── TO-DO.md                      # Development task tracking
│
├── shared-utilities/             # ALL utility scripts (48+ scripts)
│   ├── setup_wizard.sh          # Interactive configuration setup
│   ├── deploy.sh                # Production deployment script
│   ├── database_functions.sh    # Database operations
│   ├── config_manager.sh        # Configuration management
│   ├── test_domain_manager.sh   # Test domain switching
│   ├── standalone-file-analysis-tools.sh  # File system analysis
│   ├── test_*.sh               # Testing and QA scripts
│   └── [40+ specialized utilities] # All other operational scripts
│
├── shared-config/                # Application-level configuration (version controlled)
│   ├── menu.db                  # Dynamic menu database
│   ├── menu_schema.sql          # Menu system structure
│   └── *.sql                    # ALL database schemas (11 schema files)
│
├── local-config/                 # Instance-specific private data (git-ignored)
│   ├── .env                      # Main configuration (created by setup wizard)
│   ├── gwombat.db               # Instance database
│   ├── logs/                    # Session and operation logs
│   ├── reports/                 # Generated reports and analytics
│   ├── exports/                 # CSV export outputs
│   ├── backups/                 # Database backups
│   └── tmp/                     # Temporary files
│
├── python-modules/               # Python integrations
│   ├── compliance_dashboard.py  # SCuBA compliance dashboard
│   ├── scuba_compliance.py     # Security baseline monitoring
│   └── venv/                    # Python virtual environment
│
└── docs/                        # Technical documentation
    ├── INSTALLATION.md          # Setup instructions
    ├── DEPLOYMENT.md            # Production deployment guide
    ├── CSV_EXPORT_SYSTEM.md     # Export system documentation
    ├── TEST_DOMAIN_MANAGEMENT.md # Test domain switching guide
    └── [specialized guides]      # Additional technical documentation
```

### 🎯 Benefits of This Organization
- **🔒 Security**: Complete separation prevents accidental commit of sensitive data
- **📦 Deployment**: Clean version control with only code and schemas
- **🔧 Maintenance**: Centralized scripts make updates and debugging easier  
- **🚀 Scalability**: Clear separation supports multi-instance deployments
- **📋 Compliance**: Audit trails and data classification built into structure

## 🔍 Advanced Menu Features

### Intelligent Search System
```bash
# Search examples
s → "user"      # Find all user-related operations
s → "lifecycle" # Find suspended account workflow options
s → "backup"    # Find backup and archival operations
s → "security"  # Find compliance and security features
```

### Menu Database Integration
- **43+ Operations** - Searchable with contextual descriptions
- **Navigation Paths** - Shows exactly how to reach each operation
- **Keyword Optimization** - Smart matching across titles, descriptions, and tags
- **Real-time Results** - Instant search with highlighted matches

## 📚 Documentation

### Setup & Configuration
- **[INSTALLATION.md](docs/INSTALLATION.md)** - Comprehensive setup and configuration
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Production deployment procedures
- **[REQUIREMENTS.md](docs/REQUIREMENTS.md)** - System requirements and dependencies
- **[OAUTH_TROUBLESHOOTING.md](docs/OAUTH_TROUBLESHOOTING.md)** - Google Workspace OAuth authentication issues

### Feature Documentation
- **[CSV_EXPORT_SYSTEM.md](docs/CSV_EXPORT_SYSTEM.md)** - Complete CSV export functionality guide
- **[TEST_DOMAIN_MANAGEMENT.md](docs/TEST_DOMAIN_MANAGEMENT.md)** - Test domain configuration and safety procedures

### Development & Testing
- **[TESTING_PLAN.md](docs/TESTING_PLAN.md)** - Testing procedures and validation
- **[TO-DO.md](TO-DO.md)** - Development task tracking and project status
- **[CLAUDE.md](CLAUDE.md)** - AI development context and architecture

## 🌟 Latest Enhancements (v4.1 - August 2025)

### 🎯 High Priority Features Completed
- **📊 CSV Export System** - Comprehensive data export with automated integration
- **🧪 Test Domain Management** - Safe production/test domain switching with backup/restore
- **🗂️ Database Architecture Enhancement** - Proper shared-config/local-config separation
- **🔧 GAM Command Transparency** - Complete GAM command logging and display system
- **📚 Enhanced Documentation** - Complete feature documentation and user guides

### 🔄 Previous Enhancements (v4.0 - August 2025)

### SQLite Menu Revolution
- **Dynamic Menu Generation** - Complete replacement of hardcoded interfaces
- **Intelligent Search** - Advanced keyword matching across all operations
- **Alphabetical Index** - Complete operation catalog with descriptions
- **Self-Maintaining** - Zero maintenance overhead for menu changes

### Production-Ready Interface (January 2025)
- **"Coming Soon" Removal** - All placeholder options removed from active menus
- **Focused Functionality** - Dashboard & Statistics streamlined to 18 working features
- **Clean User Experience** - No confusing placeholders, only functional options
- **Comprehensive Future Roadmap** - All removed features tracked for future implementation

### Enhanced User Management
- **Integrated Lifecycle** - Suspended account management in User & Group Management
- **20 User Operations** - Comprehensive account, group, and license management
- **Advanced Scanning** - Automated account discovery and categorization

### External Tools Integration
- **Domain Synchronization** - GAM, GYB, rclone all point to same domain
- **Configuration Management** - Centralized external tool setup
- **Verification System** - Automated domain verification and tool status

### GAM Command Transparency & Logging
- **Complete Visibility** - All GAM commands displayed as `🔧 GAM: gam print users fields email`
- **Comprehensive Logging** - Every GAM command logged to `local-config/logs/gwombat.log`
- **Performance Tracking** - Command execution timing and exit codes logged
- **Error Capture** - GAM errors displayed and logged with full context
- **Configurable Display** - `SHOW_GAM_COMMANDS="true/false"` setting in configuration
- **Audit Trail** - Complete command history for debugging and compliance

### Advanced Security
- **Domain Security Verification** - Prevents operations on wrong domains
- **Multi-Schema Architecture** - Specialized databases for different functions
- **Python Integration** - Compliance dashboards and API interfaces
- **OAuth Troubleshooting** - Comprehensive guide for Google Workspace authentication issues

## 📊 Project Statistics

- **9000+ lines** - Main application with dynamic menu system
- **1000+ lines** - Database functions with menu management
- **30+ utility scripts** - Specialized operations and integrations
- **Multi-schema database** - 4+ specialized schemas with 15+ tables
- **43+ operations** - Across 8 functional categories with intelligent search

## 🎯 Why GWOMBAT v4.0?

1. **Revolutionary Interface** - SQLite-driven menus with zero maintenance overhead
2. **Enterprise Scale** - Handles large Google Workspace environments with database persistence
3. **Intelligent Discovery** - Advanced search finds operations instantly
4. **Security First** - Domain verification and comprehensive audit trails
5. **Self-Maintaining** - Database-driven architecture stays current automatically
6. **Integration Ready** - External tools synchronization and Python module support

## 🚀 Future Roadmap

- **Web Dashboard** - Browser interface leveraging Python modules
- **API Integration** - RESTful endpoints for external system integration
- **Workflow Automation** - Scheduled batch operations with cron integration
- **Mobile Interface** - Responsive design for mobile device management
- **AI-Powered Insights** - Machine learning for account lifecycle optimization

---

**GWOMBAT** represents a revolutionary evolution in Google Workspace administration - from simple script collections to enterprise-grade platform with cutting-edge database-driven interfaces, intelligent automation, and robust security features.

The SQLite menu system sets a new standard for admin tool interfaces, providing intelligent search, self-maintaining menus, and zero maintenance overhead.

*For detailed installation instructions, see [docs/INSTALLATION.md](docs/INSTALLATION.md)*