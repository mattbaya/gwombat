# GWOMBAT Installation Guide

This guide provides detailed instructions for installing and configuring GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner).

## Prerequisites

### Required Dependencies
- **Linux/macOS** - Primary development and production platforms
- **Bash 4.0+** - Core scripting environment 
- **GAM (Google Apps Manager)** - Google Workspace interface
  - Download from: https://github.com/GAM-team/GAM
  - Requires Google Workspace admin privileges
- **SQLite** - Database backend (usually pre-installed on most systems)
- **Git** - Version control and deployment

### Optional Dependencies
- **SSH** - Required for deployment features
- **expect** - Automated SSH key password entry for deployment
- **Google Drive API** - For automated backup uploads
- **curl/wget** - Additional web-based integrations

## Installation Steps

### 1. Clone the Repository
```bash
git clone git@github.com:mattbaya/gwombat.git
cd gwombat
```

### 2. Configure Environment
```bash
# Copy the environment template
cp .env.template .env

# Edit the configuration file
nano .env  # or use your preferred editor
```

### 3. Environment Configuration

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

### 4. GAM Setup

Ensure GAM is properly installed and authenticated:

```bash
# Test GAM installation
gam version

# Authenticate with Google Workspace (if not already done)
gam oauth create

# Test basic functionality
gam info domain
```

### 5. Create Directories
GWOMBAT will create necessary directories automatically, but you can pre-create them:

```bash
mkdir -p logs reports tmp backups config
```

### 6. Test Installation
```bash
# Run GWOMBAT
./gwombat.sh

# The system will initialize the database and configuration on first run
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

### Database Configuration

GWOMBAT uses SQLite with automatic initialization. The database will be created in the `config/` directory on first run.

To manually initialize:
```bash
# Run database setup
sqlite3 config/gwombat.db < database_schema.sql
```

## Verification Steps

### 1. Test Basic Functionality
```bash
./gwombat.sh
# Navigate to: System Administration → Check dependencies
```

### 2. Test GAM Integration
```bash
# From within GWOMBAT:
# Navigate to: Analysis & Discovery → License management
# Try listing licenses to verify GAM connectivity
```

### 3. Test Database
```bash
# From within GWOMBAT:
# Navigate to: Account List Management → Database maintenance
# Run database health check
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