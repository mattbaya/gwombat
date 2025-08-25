# CLAUDE.md - AI Development Context

## Project Overview
**GWOMBAT** (Google Workspace Optimization, Management, Backups And Taskrunner) is an enterprise-grade Google Workspace account lifecycle management system with SQLite-driven dynamic interfaces, automated workflows, and comprehensive security features.

## Current Architecture (August 2025)
- **Primary Script**: `gwombat.sh` (9000+ lines) - Main application with SQLite-driven dynamic menu system
- **Database System**: Multi-schema SQLite architecture with persistent state tracking and menu management
- **Menu System**: Revolutionary database-driven menus with intelligent search and zero maintenance overhead
- **Python Integration**: Advanced compliance modules with dashboard capabilities
- **Deployment**: Git-based secure deployment with SSH key automation and domain verification
- **Configuration**: Environment-configurable via .env files with external tools synchronization

## Key Components

### 1. Dynamic Menu System (`gwombat.sh`)
**SQLite-Driven Architecture (January 2025 Major Overhaul)**:
- **User & Group Management** (23 options): Account lifecycle, scanning, storage management, group operations, suspended account workflows
- **File & Drive Operations** (3 streamlined sections): File Operations, Shared Drive Management, Permission Management  
- **Backup & Recovery** (13 options): Remote storage, policies, scheduling, restore, verification, monitoring
- **Dashboard & Statistics** (18 options): System overview (12 options), statistics & metrics (8 options) - all functional features only
- **Analysis & Discovery**: Account analysis, diagnostics, system monitoring
- **Security & Compliance**: SCuBA compliance, permission auditing, security operations
- **System Administration**: Database operations, performance monitoring, log management

**Menu Architecture Details**:
- **Database Tables**: menu_sections, menu_items, menu_navigation, menu_hierarchy with 80+ items
- **Dynamic Generation**: All major menus generated from SQLite database queries
- **Intelligent Search**: Keyword search across all menu options with contextual results  
- **Breadcrumb Navigation**: Clear path display (e.g., "/ File & Drive Operations / File Operations")
- **Status Indicators**: Real-time system health checks in menu headers
- **Consistent Navigation**: Standardized 'p' (previous), 'm' (main), 's' (search), 'x' (exit)
- **Production-Ready Focus**: All "coming soon" placeholders removed - only functional features displayed

### 2. Database Architecture (`shared-utilities/database_functions.sh`)
**Multi-Schema Design**:
- **Primary Schema**: Account lifecycle tracking, list management, verification, audit logging (`local-config/gwombat.db`)
- **Menu Schema**: Dynamic menu system with search optimization (`shared-config/menu.db`)
- **Specialized Schemas**: SCuBA compliance, configuration management, security reports, backup tracking

**Database Organization**:
- **`local-config/`**: Instance-specific data (account data, configurations, logs)
- **`shared-config/`**: Application-level structure (menu definitions, schemas)

**⚠️ CRITICAL DATABASE LOCATIONS**:
- **`shared-config/menu.db`**: ALL menu system data (menu_sections, menu_items, menu_search)
- **`local-config/gwombat.db`**: User data, accounts, operations, audit logs (instance-specific)
- **NEVER store menus in local-config** - menus are shared application structure, not private data

**Configuration File Organization**:
- **`local-config/.env`**: Main environment configuration (gitignored, instance-specific)
- **`.env.template`**: Configuration template (version controlled, repo root)  
- **`local-config/test-domains.env`**: Test domain configurations
- **Backward Compatibility**: Legacy `.env` in root still supported

**Core Functions**:
- `generate_main_menu()`, `generate_submenu()` - Dynamic menu generation
- `search_menu_database()`, `show_menu_database_index()` - Advanced search and indexing
- `get_menu_function()` - Dynamic function resolution from database

**Menu Database Schema** (`shared-config/menu.db`):
- **menu_sections**: Main categories (id, name, display_name, section_order, icon, color_code, is_active)
- **menu_items**: Individual options (section_id, name, display_name, function_name, item_order, icon, keywords, is_active)
- **menu_navigation**: Special navigation options (key_char, display_name, function_name, is_global)
- **menu_hierarchy**: Submenu relationships (parent_item_id, child_section_id)
- **menu_search_cache**: Performance optimization for search functionality

**Menu Population & Management**:
- **Data Loading**: `shared-utilities/menu_data_loader.sh` populates initial menu structure
- **Dynamic Updates**: Menu items can be added/modified via SQL without code changes
- **Search Integration**: Full-text search across display names, descriptions, and keywords

**Navigation Standards (Fully Implemented)**:
- **'p'** = Previous menu (back) - replaces old 'b' for consistency
- **'m'** = Main menu - direct return to top level
- **'s'** = Search all menu options - database-driven search
- **'i'** = Index of all menus (where available)
- **'x'** = Exit application

**SQLite-Driven Menu Implementation Status**:
- ✅ **system_overview_menu** (15 system monitoring & health check options) - **NEWLY CONVERTED**
- ✅ **dashboard_menu** (17 dashboard, security, backup & database management options) - **NEWLY CONVERTED**
- ✅ **file_operations_menu** (3 streamlined options with 3-step workflow)
- ✅ **shared_drive_menu** (19 comprehensive shared drive operations)  
- ✅ **permission_management_menu** (20 security-focused permission tools)
- ✅ **backup_operations_main_menu** (13 enterprise backup & recovery options)
- ✅ **user_group_management_menu** (23 user lifecycle & group management tools)
- ⏳ **Remaining High Priority**: statistics_menu, show_main_menu
- ⏳ **Remaining Medium Priority**: file_operations_menu, permission_management_menu, shared_drive_menu, backup_operations_main_menu

**Menu Database Sections Created**:
- **system_overview**: System dashboard, health checks, performance metrics, maintenance tools
- **dashboard_menu**: Dashboard operations, security reports, backup tools, configuration & database management
- **file_operations**: Streamlined file management with Google Drive integration
- **shared_drives**: Complete shared drive lifecycle management  
- **permission_management**: Security-focused access control and auditing
- **backup_operations_main**: Enterprise backup system with remote storage
- **user_group_management**: Comprehensive account lifecycle management

**Enhanced Menu Features**:
- **Breadcrumb Navigation**: Path display shows current location in menu hierarchy
- **Status Indicators**: Real-time health checks (GAM, database, domain, storage)
- **Error Handling**: 3-attempt input validation with progressive feedback
- **Category Organization**: Visual grouping with color-coded section headers
- **Function Resolution**: Dynamic function calling based on database function_name field
- **Function Dispatchers**: system_overview_function_dispatcher(), dashboard_function_dispatcher()
- **Export Integration**: CSV and Google Sheets export capabilities built into workflows

### 3. Configuration & External Tools (`shared-utilities/config_manager.sh`)
**External Tools Integration**:
- **GAM Configuration**: OAuth setup, domain verification, GAM7 compatibility
- **GYB Integration**: Gmail backup with domain synchronization
- **rclone Configuration**: Cloud storage with multi-provider support
- **Domain Synchronization**: Ensures all tools point to same Google Workspace domain

## Development Context

### ⚠️ CRITICAL NAMING CONVENTION ⚠️
**ALWAYS use "GWOMBAT" (Google Workspace Optimization, Management, Backups And Taskrunner)**
- ✅ Correct: GWOMBAT, gwombat, gwombatgit-key
- ❌ Wrong: GAMladmin, gamladmin, gamladmingit-key

### Key Technical Patterns
1. **Database-First Architecture**: All interfaces and state driven by SQLite
2. **Dynamic Menu Generation**: No hardcoded menu structures
3. **Configurable Workflows**: User-customizable suspension lifecycle stages with database-driven workflow management
4. **Domain Security Verification**: Automatic verification GAM domain matches .env DOMAIN
5. **Environment Configuration**: No hardcoded paths or server-specific values
6. **Comprehensive Logging**: Multi-level logging for operations and deployments

### Dependencies
- **GAM (Google Apps Manager)**: Primary Google Workspace interface (GAM7 compatible)
- **SQLite**: Multi-schema database backend for all persistence and menu management
- **Python 3.12+**: Advanced compliance modules and dashboard capabilities

### ⚠️ CRITICAL GAM7 Command Syntax
**ALWAYS use official GAM7 wiki syntax. Never guess commands.**
**Reference: https://github.com/GAM-team/GAM/wiki**

**Correct User Creation Syntax (two steps required):**
```bash
# Step 1: Create the user
gam create user <email> firstname "First" lastname "Last" password "password" changepassword false

# Step 2: Grant super admin privileges  
gam create admin <email> _SEED_ADMIN_ROLE customer
```

**Available Admin Roles (use `gam show adminroles` to verify):**
- `_SEED_ADMIN_ROLE` - Super admin (isSuperAdminRole: True)
- `_USER_MANAGEMENT_ADMIN_ROLE` - User management only
- `_GROUPS_ADMIN_ROLE` - Groups management only
- Other limited roles available

**❌ WRONG (invalid syntax):**
- `admin on` / `isadmin true` / `isdelegatedadmin true` → Use two-step process above
- `changepassword off` → Use `changepassword false`
- `_SUPER_ADMIN_ROLE` → Use `_SEED_ADMIN_ROLE`
  - **Core Python packages** (see `python-modules/requirements.txt`):
    - `google-api-python-client>=2.100.0` - Google Workspace API client
    - `google-auth>=2.22.0` - Google authentication libraries
    - `pandas>=2.0.3` - Data processing and analysis
    - `matplotlib>=3.7.2` - Visualization for compliance reports
    - `pyyaml>=6.0` - Configuration management
    - `structlog>=23.1.0` - Structured logging
  - **Installation**: `cd python-modules && pip install -r requirements.txt`
- **GYB (Got Your Back)**: Gmail backup integration
- **rclone**: Cloud storage synchronization
- **SSH/Git**: Secure deployment infrastructure
- **expect**: Password automation for interactive prompts

### Setup Wizard (`shared-utilities/setup_wizard.sh`)
**Fully Automated Configuration System**:
- **Personal Admin First**: Asks for your personal Google Workspace admin account
- **GAM OAuth Setup**: Runs `gam create project` then `gam oauth create` to prevent client restriction errors
- **Service Account Creation**: Two-step process with proper admin privileges using `_SEED_ADMIN_ROLE`
- **OU Configuration**: Queries existing OUs after GAM is configured, offers to create best-practice structure
- **Python Environment**: Creates virtual environment and installs all packages (jinja2, pandas, matplotlib, etc.)
- **Menu Database**: Initializes SQLite menu system automatically
- **External Tools**: Configures GYB, rclone with domain synchronization
- **Error Handling**: Comprehensive retry logic and manual fallback options

**Setup Wizard Features**:
- ✅ **GAM Project Creation**: Handles Google Cloud project setup before OAuth
- ✅ **Two-Step Admin Creation**: Proper `gam create user` + `gam create admin _SEED_ADMIN_ROLE`
- ✅ **Python Venv Fix**: Uses venv's Python directly for package verification
- ✅ **OU Intelligence**: Queries existing structure before configuration
- ✅ **Retry Logic**: Handles timing issues with admin privilege grants
- ✅ **Clean Error Messages**: Clear feedback and recovery instructions

### Testing Commands
```bash
# Test SQLite menu system
./gwombat.sh # Use 's' for search, 'i' for index

# Test menu database population
./shared-utilities/menu_data_loader.sh

# Test search functionality
source shared-utilities/database_functions.sh && search_menu_database "user"

# Verify syntax
bash -n gwombat.sh && bash -n shared-utilities/database_functions.sh
```

### Environment Configuration
**Configuration File Location**: `local-config/.env` (created by setup wizard)
**Configuration Cleanup**: All server.env references removed - unified configuration in local-config/.env
**Required .env variables**:
```bash
DOMAIN="your-domain.edu"                    # Google Workspace domain
ADMIN_USER="admin@your-domain.edu"          # Actual admin user
GAM_PATH="/usr/local/bin/gam"               # GAM executable path
SUSPENDED_OU="/Suspended Users"             # Suspended accounts OU
PENDING_DELETION_OU="/Suspended Users/Pending Deletion"
PRODUCTION_SERVER="your-server.edu"        # Deployment target
SSH_KEY_PATH="$HOME/.ssh/gwombatgit-key"    # Deployment SSH key
```

## File Organization

### ⚠️ CRITICAL ORGANIZATIONAL PRINCIPLES ⚠️
**Perfect Security-Conscious File Organization**:
- **`shared-utilities/`**: ALL 48+ utility scripts belong here - zero scripts in root directory
- **`shared-config/`**: Application-level configuration (menu database, ALL 11 SQL schemas) - version controlled
- **`local-config/`**: ALL private data (logs, exports, backups, tmp, instance configs) - git ignored  
- **Root directory**: Only main application (gwombat.sh), documentation, and templates

**Zero Data Leakage Policy**:
- ✅ **Code & Schemas**: Version controlled (shared-utilities/, shared-config/, docs/)
- ✅ **Private Data**: Completely isolated (local-config/ - excluded from git)
- ✅ **Clean Separation**: No private files outside local-config, no schemas in local-config
- ✅ **Deployment Ready**: Only application code and configuration in version control
```
gwombat/
├── gwombat.sh                           # Main application (9000+ lines)
├── .env-template                        # Configuration template (version controlled)
├── CLAUDE.md                            # AI development context  
├── TO-DO.md                             # Development task tracking
├── README.md                            # Project overview and documentation
│
├── shared-utilities/                    # All utility scripts (48+ scripts total)
│   ├── database_functions.sh            # Database operations (1000+ lines)
│   ├── export_functions.sh             # CSV export system
│   ├── test_domain_manager.sh          # Test domain management
│   ├── menu_data_loader.sh             # Menu database population
│   ├── config_manager.sh               # Configuration management
│   ├── setup_wizard.sh                 # Interactive setup wizard - fully automated configuration
│   ├── deploy.sh                       # Production deployment script
│   ├── standalone-file-analysis-tools.sh # File system analysis tools
│   ├── test_*.sh                       # Testing and QA scripts (15+ scripts)
│   └── [30+ specialized utilities]      # All other operational scripts
│
├── shared-config/                       # Application-level configuration (13 files)
│   ├── menu.db                         # Dynamic menu database
│   ├── menu_schema.sql                 # Menu management schema
│   └── *.sql                           # ALL database schemas (11 schema files)
│
├── local-config/                       # Instance-specific private data
│   ├── .env                            # Main configuration file (instance-specific)
│   ├── gwombat.db                      # Instance-specific database
│   ├── test-domains.env                # Test domain configurations
│   ├── logs/                           # Session and operation logs
│   ├── reports/                        # Generated reports and analytics
│   ├── exports/                        # CSV export output directory
│   ├── backups/                        # Database backups
│   └── tmp/                            # Temporary files
│
├── python-modules/                      # Advanced Python integrations
│   ├── compliance_dashboard.py          # SCuBA compliance dashboard
│   ├── scuba_compliance.py             # Security baseline monitoring
│   └── venv/                           # Python virtual environment
│
└── docs/                               # Documentation
    ├── INSTALLATION.md                  # Setup instructions
    ├── DEPLOYMENT.md                    # Production deployment guide
    ├── CSV_EXPORT_SYSTEM.md             # Export system documentation
    └── [additional technical guides]    # Specialized documentation
```

## Current Integration Status
✅ **SQLite Menu System**: Dynamic database-driven interfaces with intelligent search
✅ **CSV Export System**: Comprehensive data export functionality integrated throughout application
✅ **Test Domain Management**: Production/test domain switching with automated backup/restore  
✅ **External Tools Configuration**: Centralized GAM/GYB/rclone domain synchronization  
✅ **Database Architecture**: Multi-schema design with shared-config/local-config separation
✅ **Configuration Organization**: .env files properly organized in local-config/ with template support
✅ **Security Verification**: Domain mismatch protection and automated verification
✅ **Python Integration**: Advanced compliance modules and dashboard capabilities
✅ **Deployment Automation**: Secure SSH key-based deployment with environment configuration
✅ **Production-Ready Menus**: All "coming soon" placeholders removed - system shows only working features
✅ **Menu Consolidation**: Dashboard & Statistics reduced from 20 options to 18 focused, functional options

**GWOMBAT** is a comprehensive, enterprise-ready Google Workspace management platform with cutting-edge database-driven interfaces, intelligent automation, and robust security features.