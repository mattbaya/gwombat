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
**SQLite-Driven Architecture**:
- **User & Group Management** (20 options): Account lifecycle, scanning, management, groups, licenses
- **Data & File Operations** (11 options): File management, analysis, list operations
- **System & Monitoring** (9 options): Dashboard, reports, administration
- **Security & Compliance** (3 options): SCuBA compliance management
- **Configuration Management**: External tools (GAM, GYB, rclone) domain synchronization

**Menu Features**:
- **Dynamic Generation**: All menus generated from database tables
- **Intelligent Search**: Keyword search across 43+ options with contextual results
- **Alphabetical Index**: Complete menu catalog with navigation paths
- **Self-Maintaining**: Zero hardcoded structures - automatically current

### 2. Database Architecture (`shared-utilities/database_functions.sh`)
**Multi-Schema Design**:
- **Primary Schema**: Account lifecycle tracking, list management, verification, audit logging
- **Menu Schema**: Dynamic menu system with search optimization
- **Specialized Schemas**: SCuBA compliance, configuration management, security reports, backup tracking

**Core Functions**:
- `generate_main_menu()`, `generate_submenu()` - Dynamic menu generation
- `search_menu_database()`, `show_menu_database_index()` - Advanced search and indexing
- `get_menu_function()` - Dynamic function resolution from database

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
3. **Domain Security Verification**: Automatic verification GAM domain matches .env DOMAIN
4. **Environment Configuration**: No hardcoded paths or server-specific values
5. **Comprehensive Logging**: Multi-level logging for operations and deployments

### Dependencies
- **GAM (Google Apps Manager)**: Primary Google Workspace interface (GAM7 compatible)
- **SQLite**: Multi-schema database backend for all persistence and menu management
- **Python 3.12+**: Advanced compliance modules and dashboard capabilities
- **GYB (Got Your Back)**: Gmail backup integration
- **rclone**: Cloud storage synchronization
- **SSH/Git**: Secure deployment infrastructure
- **expect**: Password automation for interactive prompts

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
```
gwombat/
├── gwombat.sh                           # Main application (9000+ lines)
├── CLAUDE.md                            # AI development context
├── shared-utilities/
│   ├── database_functions.sh            # Database operations (1000+ lines)
│   ├── menu_data_loader.sh             # Menu database population
│   ├── config_manager.sh               # Configuration management
│   └── [30+ utility scripts]           # Specialized operations
├── local-config/
│   ├── gwombat.db            # Main SQLite database
│   ├── menu_schema.sql                 # Menu management schema
│   └── [multiple specialized schemas]   # Domain-specific schemas
├── python-modules/                     # Advanced Python integrations
└── docs/                              # Documentation
```

## Current Integration Status
✅ **SQLite Menu System**: Dynamic database-driven interfaces with intelligent search
✅ **External Tools Configuration**: Centralized GAM/GYB/rclone domain synchronization  
✅ **Database Architecture**: Multi-schema design with comprehensive functionality
✅ **Security Verification**: Domain mismatch protection and automated verification
✅ **Python Integration**: Advanced compliance modules and dashboard capabilities
✅ **Deployment Automation**: Secure SSH key-based deployment with environment configuration

**GWOMBAT** is a comprehensive, enterprise-ready Google Workspace management platform with cutting-edge database-driven interfaces, intelligent automation, and robust security features.