# GWOMBAT v4.0 Installation Guide

This guide provides comprehensive instructions for installing and configuring GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner) with its revolutionary SQLite-driven menu system.

## Prerequisites

### Required Dependencies
- **Linux/macOS** - Primary development and production platforms
- **Bash 4.0+** - Core scripting environment with advanced features
- **GAM (Google Apps Manager)** - Google Workspace interface (GAM7 compatible)
  - Download from: https://github.com/GAM-team/GAM
  - Requires Google Workspace admin privileges
  - Must be configured for your domain before using GWOMBAT
- **SQLite** - Multi-schema database backend (usually pre-installed)
- **Git** - Version control and automated deployment

### Optional Advanced Dependencies
- **Python 3.12+** - Advanced compliance modules and dashboard capabilities
  - Required for SCuBA compliance and dashboard features
- **GYB (Got Your Back)** - Gmail backup integration
  - Download from: https://github.com/GAM-team/got-your-back
- **rclone** - Cloud storage synchronization
  - Download from: https://rclone.org/
- **SSH/expect** - Automated deployment and interactive prompts
- **curl/wget** - Web-based integrations and API calls

## Installation Steps

### 1. Clone the Repository
```bash
git clone git@github.com:mattbaya/gwombat.git
cd gwombat
```

### 2. Initialize SQLite Menu System
```bash
# Initialize the revolutionary dynamic menu database
./shared-utilities/menu_data_loader.sh

# This will create the menu database with:
# - 9 menu sections with 43+ operations
# - Intelligent search capabilities
# - Alphabetical indexing system
# - Navigation options and hierarchies
```

### 3. Configure Environment
```bash
# Copy the environment template
cp .env.template .env

# Edit the configuration file
nano .env  # or use your preferred editor
```

### 4. Environment Configuration

#### Required Settings (.env)
```bash
# Domain and Organization Configuration
DOMAIN="your-domain.edu"
ADMIN_EMAIL="gwombat@your-domain.edu"
ADMIN_USER="your-actual-admin@your-domain.edu"

# GAM Configuration
GAM_PATH="/usr/local/bin/gam"  # Path to your GAM installation
GAM_CONFIG_PATH="/home/your-user/.gam"

# Organizational Unit Paths (customize for your Google Workspace)
SUSPENDED_OU="/Suspended Users"
PENDING_DELETION_OU="/Suspended Users/Pending Deletion"
TEMPORARY_HOLD_OU="/Suspended Users/Temporary Hold"
EXIT_ROW_OU="/Suspended Users/Exit Row"
```

#### Optional Deployment Settings
```bash
# Production Server Configuration (for deployment)
PRODUCTION_SERVER="your-server.edu"
PRODUCTION_USER="your-user"
GWOMBAT_PATH="/opt/your-path/gwombat"

# SSH Configuration (for deployment)
SSH_KEY_PATH="$HOME/.ssh/gwombatgit-key"
SSH_KEY_PASSWORD="your-secure-password"

# Google Drive Configuration
DRIVE_LABEL_ID="your-drive-label-id"
```

### 5. GAM Setup and Domain Verification

Ensure GAM is properly installed and authenticated:

```bash
# Test GAM installation (GAM7 compatible)
gam version

# Authenticate with Google Workspace (if not already done)
gam oauth create

# Test basic functionality and verify domain
gam info domain

# CRITICAL: Verify GAM domain matches your .env DOMAIN setting
# GWOMBAT will perform automatic domain verification on startup
```

### 6. External Tools Configuration (Optional)
Configure additional tools through GWOMBAT's centralized system:

```bash
# Launch GWOMBAT and navigate to Configuration Management
./gwombat.sh

# Select: Configuration Management → External Tools Configuration
# This provides centralized setup for:
# - GAM domain verification and OAuth management
# - GYB (Gmail backup) domain synchronization
# - rclone (cloud storage) configuration
# - Automated domain verification across all tools
```

### 7. Test Installation
```bash
# Run GWOMBAT with new menu system
./gwombat.sh

# Test new features:
# - Press 's' for intelligent search across 43+ operations
# - Press 'i' for alphabetical index of all options
# - Navigate to User & Group Management for integrated lifecycle
# - Try Configuration Management → External Tools Configuration

# The system will perform domain security verification on startup
```

## Advanced Configuration

### Production Server Setup

For deployment to production servers, create a `server.env` file:

```bash
# Copy template
cp server.env.template server.env

# Configure for your production environment
nano server.env
```

**server.env content:**
```bash
# Server-specific configuration
GWOMBAT_PATH="/opt/production/path/gwombat"
GAM_PATH="/usr/local/bin/gam"
DOMAIN="your-domain.edu"
ADMIN_USER="your-actual-admin@your-domain.edu"

# Server-specific paths
SCRIPT_TEMP_PATH="./tmp"
SCRIPT_LOGS_PATH="./logs"
```

### SSH Key Setup (for deployment)

```bash
# Generate deployment key
ssh-keygen -t ed25519 -C "gwombatgit-key" -f ~/.ssh/gwombatgit-key

# Add to your production server's authorized_keys
ssh-copy-id -i ~/.ssh/gwombatgit-key.pub user@your-server.edu
```

### SQLite Menu Database Configuration

GWOMBAT v4.0 uses a revolutionary multi-schema SQLite architecture:

**Automatic Initialization:**
- Primary database created in `local-config/account_lifecycle.db`
- Menu database populated automatically via `menu_data_loader.sh`
- Multiple specialized schemas for different functional domains

**Manual Database Operations:**
```bash
# Initialize menu database manually
./shared-utilities/menu_data_loader.sh

# Check database schemas
sqlite3 local-config/account_lifecycle.db ".tables"

# Test search functionality
source shared-utilities/database_functions.sh && search_menu_database "user"

# View menu statistics
sqlite3 local-config/account_lifecycle.db "
SELECT 'Sections: ' || COUNT(*) FROM menu_sections WHERE is_active = 1;
SELECT 'Menu Items: ' || COUNT(*) FROM menu_items WHERE is_active = 1;
SELECT 'Navigation Options: ' || COUNT(*) FROM menu_navigation WHERE is_active = 1;
"
```

### Python Modules Setup (Optional)
For advanced compliance and dashboard features:

```bash
# Navigate to Python modules directory
cd python-modules

# Install Python dependencies
pip install -r requirements.txt

# Test compliance dashboard
python compliance_dashboard.py

# Test Google Workspace API integration
python gws_api.py
```

## Verification Steps

### 1. Test Revolutionary Menu System
```bash
./gwombat.sh

# Test intelligent search
# - Press 's' and search for "user"
# - Press 's' and search for "lifecycle" 
# - Press 's' and search for "backup"

# Test alphabetical index
# - Press 'i' to see complete operation catalog

# Test integrated lifecycle management
# - Navigate to User & Group Management (option 1)
# - Verify 20 options including lifecycle stages 10-17
```

### 2. Test GAM Integration and Domain Security
```bash
# From within GWOMBAT:
# The system will automatically verify GAM domain matches .env DOMAIN

# Test external tools configuration:
# - Navigate to Configuration Management → External Tools Configuration
# - Verify GAM domain status and OAuth configuration
```

### 3. Test Database and Search Functionality
```bash
# Test database-driven search
source shared-utilities/database_functions.sh && search_menu_database "security"

# From within GWOMBAT:
# - Press 's' and try various search terms
# - Verify search results show navigation paths
# - Test that index ('i') shows all 43+ operations
```

## Troubleshooting

### Common Issues

**GAM not found:**
```bash
# Check GAM installation
which gam
# Update GAM_PATH in .env file
```

**Permission errors:**
```bash
# Ensure execute permissions
chmod +x gwombat.sh
chmod +x shared-utilities/*.sh
```

**Database errors:**
```bash
# Check SQLite installation
sqlite3 --version
# Ensure write permissions in config directory
chmod 755 config/
```

**Google Workspace API errors:**
```bash
# Re-authenticate GAM
gam oauth create
# Check admin privileges
gam info domain
```

### Log Files

GWOMBAT creates detailed logs in the `logs/` directory:
- `logs/session_YYYYMMDD_HHMMSS.log` - Session logs
- `logs/operations.log` - Operation history
- `logs/errors.log` - Error logs

## Security Considerations

### File Permissions
```bash
# Secure the .env file
chmod 600 .env
chmod 600 server.env

# Secure SSH keys
chmod 600 ~/.ssh/gwombatgit-key
chmod 644 ~/.ssh/gwombatgit-key.pub
```

### Access Control
- Ensure only authorized users have access to the GWOMBAT directory
- Use dedicated service accounts for production deployments
- Regularly rotate SSH keys and passwords

### Backup Configuration
```bash
# Backup your configuration
cp .env .env.backup
cp server.env server.env.backup

# Store backups securely (outside the git repository)
```

## Production Deployment

For production deployment, see [DEPLOYMENT.md](DEPLOYMENT.md) for detailed instructions on:
- Automated deployment scripts
- Server configuration
- Backup strategies
- Monitoring setup

## Getting Help

- Check the [main README](README.md) for feature overview
- Review [DEPLOYMENT.md](DEPLOYMENT.md) for production setup
- Check log files in `logs/` directory for detailed error information
- Ensure all prerequisites are properly installed and configured

## Quick Reference

### Essential Commands
```bash
# Start GWOMBAT
./gwombat.sh

# Check system status
# Navigate to: System Administration → Check dependencies

# View logs
tail -f logs/session_*.log

# Database maintenance
# Navigate to: Account List Management → Database maintenance
```

### Key Files
- `.env` - Main configuration
- `config/gwombat.db` - SQLite database
- `logs/` - Application logs
- `shared-utilities/database_functions.sh` - Database operations
- `database_schema.sql` - Database schema