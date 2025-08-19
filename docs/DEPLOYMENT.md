# GWOMBAT Deployment Guide

**GWOMBAT**: Google Workspace Optimization, Management, Backups And Taskrunner

## Overview
GWOMBAT uses git for deployment to maintain version control and enable easy rollbacks. This approach is superior to rsync because:

- **Version Control**: Track exactly what's deployed
- **Atomic Deployments**: All-or-nothing updates  
- **Easy Rollbacks**: `git checkout` previous versions
- **Audit Trail**: Complete history of deployments

## Setup (One-Time)

### 1. Configure Environment Variables
Configure your deployment settings using the setup wizard:
```bash
# Run the setup wizard to create local-config/.env with deployment settings
./shared-utilities/setup_wizard.sh
# The wizard will prompt for:
# DOMAIN, ADMIN_USER, PRODUCTION_SERVER, PRODUCTION_USER, GWOMBAT_PATH, etc.
```

The deployment script reads from your `local-config/.env` file - no need to edit `deploy.sh` directly.

### 2. Ensure SSH Access
Make sure you can SSH to your production server:
```bash
ssh your-username@your-production-server.edu
```

### 3. Run Initial Deployment
```bash
./deploy.sh
```

This will:
- Create a bare git repository on the server
- Clone the working directory  
- Add the production remote to your local repo
- Deploy the current commit

## Regular Deployment Workflow

### 1. Commit Your Changes
```bash
git add -A
git commit -m "Description of changes"
```

### 2. Deploy
```bash
./deploy.sh
```

The script will:
- Check for uncommitted changes (will abort if found)
- Show you the commit being deployed
- Ask for confirmation
- Push to production
- Update the working directory on the server

## Manual Deployment Commands

If you prefer not to use the deployment script:

### Initial Setup
```bash
# On production server
mkdir -p ${GWOMBAT_PATH}.git
cd ${GWOMBAT_PATH}.git  
git init --bare

git clone ${GWOMBAT_PATH}.git ${GWOMBAT_PATH}

# On your desktop
git remote add production username@server:${GWOMBAT_PATH}.git
```

### Deploy
```bash
# Push changes
git push production main

# Update working directory on server
ssh username@server 'cd ${GWOMBAT_PATH} && git pull origin main'
```

## Rollback to Previous Version

If you need to rollback:

```bash
# On production server, see available versions
cd ${GWOMBAT_PATH}
git log --oneline

# Rollback to specific commit
git checkout <commit-hash>

# Or rollback to previous commit
git checkout HEAD~1
```

## Directory Structure on Production

```
${GWOMBAT_PATH}/                # Working directory (configurable via local-config/.env)
├── gwombat.sh                    # Main script
├── database_functions.sh         # Database operations
├── database_schema.sql           # Database schema
├── logs/                         # Application logs
├── reports/                      # Generated reports  
├── tmp/                          # Temporary files
└── backups/                      # Backups

${GWOMBAT_PATH}.git/               # Bare repository (for git)
```

## Troubleshooting

### "Repository not found" error
The bare repository wasn't created. Run the deployment script again or manually create it.

### "Permission denied" error  
Check SSH access and file permissions on the production server.

### "Uncommitted changes" error
Commit your changes before deploying:
```bash
git add -A
git commit -m "Your commit message"
```

### Check deployment status
```bash
# On production server
cd ${GWOMBAT_PATH}
git log --oneline -5  # See recent deployments
git status            # Check working directory status
```