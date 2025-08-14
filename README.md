![GWOMBAT Logo](assets/gwombat2.png)
# GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner

A comprehensive suspended account lifecycle management system with database tracking, verification, and automated workflows. GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner) manages Google Workspace accounts through their complete lifecycle from suspension to deletion with persistent state tracking and verification capabilities.

## 🚀 Major Update (August 2025)

### ✅ Application Renamed: GWOMBAT
- Complete rename from "GAMadmin" to "GWOMBAT" (Google Workspace Optimization, Management, Backups And Taskrunner) 
- Updated branding and version (v3.0)
- Reflects expanded scope beyond temporary hold operations

### ✅ Database Integration
- **SQLite backend** for persistent account state tracking
- **List management** system for batch operations with tags
- **Verification engine** to check account states vs expected stages
- **Complete audit trail** with session tracking and operation history

### ✅ Account Discovery & Scanning
- **Automated scanning** of all suspended accounts in Google Workspace
- **Stage detection** based on organizational unit placement
- **Auto-list creation** from discovered accounts by stage
- **Bulk verification** of account states across lists

### ✅ Secure Deployment System
- **Git-based deployment** with version control and rollbacks
- **SSH key automation** with password-protected deployment keys
- **Environment configuration** via .env files (no hardcoded paths)
- **Deployment logging** with complete audit trail

## 📋 System Overview

### Main Menu Structure (Reorganized by Function)
```
GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner

=== ACCOUNT MANAGEMENT ===
1. 🔄 Suspended Account Lifecycle Management (8 options)
2. 👥 User & Group Management (2 options)

=== DATA & FILE OPERATIONS ===
3. 💾 File & Drive Operations (13 options)
4. 🔍 Analysis & Discovery (11 options)
5. 📋 Account List Management (11 options)

=== MONITORING & SYSTEM ===
6. 📈 Reports & Monitoring (11 options)
7. ⚙️ System Administration (6 options)

8. ❌ Exit
```

### Account Lifecycle Stages
The system tracks accounts through these lifecycle stages with persistent database storage:

1. **recently_suspended** - Newly suspended accounts
2. **pending_deletion** - Accounts marked for deletion with file markers
3. **temporary_hold** - Accounts given additional time before deletion
4. **exit_row** - Accounts prepared for final deletion
5. **deleted** - Completed deletion operations

### Database-Driven Operations
- **Account Lists/Tags**: Group accounts for batch processing
- **State Verification**: Automated checking of account states vs GAM reality
- **Progress Tracking**: Monitor completion status of batch operations  
- **Operation History**: Complete audit trail with session correlation
- **Import/Export**: CSV import with automatic list creation

## 🛠️ Installation & Deployment

### Local Development Setup

1. **Clone and configure**:
```bash
git clone <your-repo>
cd gwombat
cp .env.template .env
# Edit .env with your configuration
```

2. **Create SSH deployment key**:
```bash
ssh-keygen -t ed25519 -C "gwombatgit-key" -f ~/.ssh/gwombatgit-key
ssh-copy-id -i ~/.ssh/gwombatgit-key.pub user@server
```

3. **Install dependencies**:
```bash
brew install expect  # For SSH key automation
```

### Production Deployment

**Using the automated deployment script**:
```bash
./deploy.sh
```

The deployment script handles:
- ✅ SSH key authentication with password automation
- ✅ Git-based atomic deployments
- ✅ Server configuration setup
- ✅ Permission and directory management
- ✅ Complete deployment logging

### Environment Configuration

**Local (.env)**:
```bash
# SSH Key Configuration
SSH_KEY_PASSWORD="your-secure-password"
SSH_KEY_PATH="$HOME/.ssh/gwombatgit-key"

# Production Server Configuration  
PRODUCTION_SERVER="gamera2.your-domain.edu"
PRODUCTION_USER="gwombat"
GWOMBAT_PATH="/opt/gamera/mjb9/gwombat"
```

**Production (server.env)**:
```bash
# Server paths
GWOMBAT_PATH="/opt/gamera/mjb9/gwombat"
GAM_PATH="/usr/local/bin/gam"
DOMAIN="your-domain.edu"

# Organizational Units
SUSPENDED_OU="/Suspended Users"
PENDING_DELETION_OU="/Suspended Users/Pending Deletion"
TEMPORARY_HOLD_OU="/Suspended Users/Temporary Hold"
```

## 🔧 Key Features

### Database System
- **Persistent State**: SQLite database tracks all account states
- **List Management**: Tag-based grouping for batch operations
- **Verification**: Automated checking of account vs expected states
- **Audit Trail**: Complete operation history with session tracking

### Account Management  
- **Lifecycle Tracking**: Database-driven state management
- **Batch Operations**: Process multiple accounts with progress tracking
- **Verification System**: Confirm account states match expectations
- **Automated Discovery**: Scan and categorize all suspended accounts

### Deployment & Configuration
- **Environment Agnostic**: No hardcoded paths or server details
- **Secure Deployment**: SSH key-based authentication with automation
- **Version Control**: Git-based deployments with rollback capability
- **Configuration Management**: Multi-level configuration via .env files

## 📊 Database Schema

The system uses a comprehensive SQLite schema with 7 main tables:

- **accounts** - Core account information and current lifecycle stage
- **account_lists** - List/tag definitions for grouping accounts
- **account_list_memberships** - Many-to-many account-list relationships
- **stage_history** - Complete lifecycle change tracking
- **verification_status** - Stage-specific verification results
- **operation_log** - Audit trail for all operations
- **config** - System configuration storage

## 🔍 Usage Examples

### Account List Management
```bash
# Run GWOMBAT
./gwombat.sh

# Select: 5. Account List Management
# Options include:
# - View all account lists with progress
# - Create new account lists
# - Import accounts from CSV files
# - Scan all suspended accounts
# - Auto-create lists from account scan
# - Verify account states in bulk
```

### Account Discovery
```bash
# Scan all suspended accounts and discover their stages
# Select: Account List Management → Scan all suspended accounts
# This will categorize accounts by their current OU placement
```

### Deployment
```bash
# Deploy to production with one command
./deploy.sh
# Enter deployment key password once - handles everything else automatically
```

## 📁 File Organization

```
gwombat/
├── gwombat.sh                     # Main application (6500+ lines)
├── database_functions.sh          # Database operations (688 lines)
├── database_schema.sql            # SQLite schema definition
├── deploy.sh                      # Secure deployment script
├── .env.template                  # Local configuration template
├── server.env.template            # Server configuration template
├── DEPLOYMENT.md                  # Deployment documentation
├── CLAUDE.md                      # Development context for AI
├── shared-utilities/              # Essential standalone utilities
├── old-scripts-replaced-by-master/# Archived script collections
├── config/                        # Runtime configuration
├── logs/                          # Session and operation logs
├── reports/                       # Generated reports
├── backups/                       # Data backups
└── tmp/                          # Temporary files
```

## 🔐 Security Features

- **SSH Key Authentication**: Dedicated deployment keys with password protection
- **Environment Isolation**: No secrets in code, all configuration in .env files  
- **Audit Logging**: Complete operation tracking with session correlation
- **Version Control**: All changes tracked via git with rollback capability
- **Permission Management**: Proper file and directory permissions on deployment

## 📋 Dependencies

- **GAM (Google Apps Manager)** - Primary Google Workspace interface
- **SQLite** - Database backend for persistent state
- **Git/SSH** - Secure deployment infrastructure  
- **expect** - SSH key password automation
- **Bash 4+** - Shell scripting environment

## 🚀 Future Enhancements

- Enhanced verification with more sophisticated state checking
- Scheduled workflow automation for batch operations
- Web-based dashboard for status monitoring  
- API integrations for external system hooks
- Multi-server deployment management

---

GWOMBAT represents a comprehensive evolution from simple script collection to enterprise-grade account lifecycle management system with database persistence, automated verification, and secure deployment capabilities.
