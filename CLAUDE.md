# CLAUDE.md - AI Development Context

## Project Overview
**GAMadmin** (Google Apps Manager Administration) is a comprehensive suspended account lifecycle management system with database tracking, verification, and automated workflows. This system manages Google Workspace accounts through their complete lifecycle from suspension to deletion, with persistent state tracking and verification capabilities.

## Current State (August 2025)
- **Primary Script**: `gamadmin.sh` - Master lifecycle management script (6500+ lines)
- **Architecture**: Menu-driven interactive system with database integration and automated workflows
- **Database System**: SQLite-based persistent state tracking with verification
- **Deployment**: Git-based with secure SSH key deployment to production servers
- **Configuration**: Fully environment-configurable via .env files

## Key Components

### 1. Core Lifecycle Management (`gamadmin.sh`)
**Main Menu Structure** (reorganized for logical grouping):
- **Account Management**:
  - Suspended Account Lifecycle Management (6 options)
  - User & Group Management (2 options)
- **Data & File Operations**:
  - File & Drive Operations (13 options)
  - Analysis & Discovery (11 options)  
  - Account List Management (11 options)
- **Monitoring & System**:
  - Reports & Monitoring (11 options)
  - System Administration (6 options)

**Recent Major Enhancements**:
- Complete application rename to GAMadmin
- Database-driven account lifecycle tracking
- Account scanning and stage discovery
- List-based batch operations with verification
- Secure deployment system with SSH key automation

### 2. Database System (`database_functions.sh`, `database_schema.sql`)
**Core Features**:
- **Account Tracking**: Persistent state management across lifecycle stages
- **List Management**: Tag-based grouping for batch operations
- **Verification System**: Automated checking of account states vs expected stages
- **Audit Logging**: Complete operation history with session tracking
- **Progress Tracking**: List-based completion monitoring

**Database Schema** (7 main tables):
- `accounts` - Core account information and current stage
- `account_lists` - List/tag definitions for grouping accounts
- `account_list_memberships` - Many-to-many account-list relationships
- `stage_history` - Complete lifecycle change history
- `verification_status` - Stage-specific verification results
- `operation_log` - Audit trail for all operations
- `config` - System configuration storage

### 3. Deployment System (`deploy.sh`, `.env`, `server.env`)
**Secure Git-Based Deployment**:
- Password-protected SSH key with automated entry
- Environment-specific configuration via .env files
- Server-specific paths via server.env configuration
- Deployment logging with complete audit trail
- Atomic deployments with easy rollback capability

### 4. Account Discovery & Scanning
**Automated Discovery**:
- Scan all suspended accounts in Google Workspace
- Determine current lifecycle stage based on OU placement
- Auto-create lists based on discovered account stages
- Database integration for persistent tracking
- Bulk verification of account states

## Technical Architecture

### Menu System Evolution
- **Logical Grouping**: Reorganized from 9 to 8 main categories by function type
- **Enhanced Navigation**: Universal 'm' (main menu) and 'x' (exit) options
- **Option Counts**: All menu entries show submenu option counts
- **Database Integration**: List management seamlessly integrated
- **Context-Aware**: Menus adapt based on available data and operations

### Database Integration
- **SQLite Backend**: Lightweight, serverless database for persistence
- **Verification Engine**: Automated checking of account states vs GAM reality
- **Batch Operations**: List-based processing with progress tracking
- **Session Management**: Complete audit trail with session correlation
- **Import/Export**: CSV import with automatic list creation

### Configuration Management
**Multi-Level Configuration**:
- **Local (.env)**: Deployment credentials and server details
- **Server (server.env)**: Production paths and GAM configuration  
- **Application**: Dynamic configuration with environment variable overrides
- **Database**: Runtime configuration storage

### Deployment Architecture
**Git-Based Workflow**:
- **Bare Repository**: Production server hosts bare git repository
- **Working Directory**: Separate directory for running application
- **SSH Config**: Dedicated deployment key with automatic authentication
- **Environment Separation**: Configurable paths for different servers

## Development Context for Claude

### ⚠️ CRITICAL NAMING CONVENTION ⚠️
**ALWAYS use "GAMadmin" (with 'd') - NEVER "GAMladmin" (with 'ld')**
- ✅ Correct: GAMadmin, gamadmin, gamadmingit-key
- ❌ Wrong: GAMladmin, gamladmin, gamladmingit-key
- This is a persistent typo issue - always double-check spelling
- Search and replace any instances of "gamladmin" with "gamadmin"

### Current Integration Status
✅ **Application Renamed**: Complete rename to GAMadmin with updated branding
✅ **Database System**: Full SQLite integration with comprehensive schema
✅ **Account Discovery**: Automated scanning and stage detection
✅ **Deployment System**: Secure, automated deployment with SSH key management
✅ **Configuration Management**: Fully environment-configurable system
✅ **List Management**: Complete batch operation system with verification

### Key Development Patterns
1. **Database-First Architecture**: Persistent state drives all operations
2. **Environment Configuration**: No hardcoded paths or server-specific values
3. **Verification-Driven Operations**: Automated checking of account states
4. **Git-Based Deployment**: Version-controlled, auditable deployments
5. **Menu-Driven UX**: Consistent interactive experience
6. **Comprehensive Logging**: Multi-level logging for operations and deployments

### Recent Major Changes (August 2025)
- **Complete Rename**: temphold-master → GAMadmin
- **Database Integration**: Added SQLite for persistent state management
- **Account Scanning**: Automated discovery of account stages via OU placement
- **List Management**: Tag-based batch operations with verification
- **Deployment Automation**: SSH key-based secure deployment system
- **Configuration Externalization**: All paths and settings moved to .env files

### Dependencies
- **GAM (Google Apps Manager)**: Primary interface to Google Workspace  
- **SQLite**: Database backend for persistent state
- **SSH/Git**: Secure deployment infrastructure
- **expect**: Password automation for SSH keys
- **Standard Unix Tools**: bash, grep, sed, awk for text processing

### Testing Commands
```bash
# Test database initialization
./gamadmin.sh # Select Account List Management → Database maintenance

# Test account scanning  
./gamadmin.sh # Select Account List Management → Scan suspended accounts

# Test deployment
./deploy.sh

# Verify script syntax
bash -n gamadmin.sh
bash -n database_functions.sh
```

### Environment Configuration
**Local Development (.env)**:
```bash
PRODUCTION_SERVER="gamera2.your-domain.edu"
PRODUCTION_USER="gamadmin"  
GAMADMIN_PATH="/opt/gamera/mjb9/gamadmin"
SSH_KEY_PATH="$HOME/.ssh/gamadmingit-key"
SSH_KEY_PASSWORD="secure-password"
```

**Production Server (server.env)**:
```bash
GAMADMIN_PATH="/opt/gamera/mjb9/gamadmin"
GAM_PATH="/usr/local/bin/gam"
DOMAIN="your-domain.edu"
SUSPENDED_OU="/Suspended Users"
```

## File Organization
```
gamadmin/
├── gamadmin.sh                    # Main application (6500+ lines)
├── database_functions.sh          # Database operations (688 lines)
├── database_schema.sql            # SQLite schema definition
├── deploy.sh                      # Secure deployment script
├── .env.template                  # Local configuration template
├── server.env.template            # Server configuration template
├── DEPLOYMENT.md                  # Deployment documentation
├── shared-utilities/              # Essential standalone utilities
├── old-scripts-replaced-by-master/# Archived script collections  
├── config/                       # Runtime configuration files
├── logs/                         # Session and operation logs
├── reports/                      # Generated reports and summaries
├── backups/                      # Configuration and data backups
└── tmp/                         # Temporary processing files
```

## Future Development Considerations
- **Enhanced Verification**: More sophisticated account state checking
- **Workflow Automation**: Scheduled batch operations
- **Reporting Dashboard**: Web-based status monitoring
- **Integration APIs**: Hooks for external systems
- **Multi-Server Management**: Deploy to multiple environments

This project represents a comprehensive evolution from simple script collection to enterprise-grade account lifecycle management system with database persistence, automated verification, and secure deployment capabilities.