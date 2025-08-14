# GAMadmin Deployment Guide

## Overview
GAMadmin uses git for deployment to maintain version control and enable easy rollbacks. This approach is superior to rsync because:

- **Version Control**: Track exactly what's deployed
- **Atomic Deployments**: All-or-nothing updates  
- **Easy Rollbacks**: `git checkout` previous versions
- **Audit Trail**: Complete history of deployments

## Setup (One-Time)

### 1. Configure Deployment Script
Edit `deploy.sh` and update these variables:
```bash
PRODUCTION_SERVER="gamera.your-domain.edu"  # Your server name
PRODUCTION_USER="your-username"          # Your username
PRODUCTION_PATH="/opt/your-path/gamadmin" # Where app runs
BARE_REPO_PATH="/opt/your-path/gamadmin.git"  # Git repository
```

### 2. Ensure SSH Access
Make sure you can SSH to your production server:
```bash
ssh your-username@gamera.your-domain.edu
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
mkdir -p /opt/your-path/gamadmin.git
cd /opt/your-path/gamadmin.git  
git init --bare

git clone /opt/your-path/gamadmin.git /opt/your-path/gamadmin

# On your desktop
git remote add production username@server:/opt/your-path/gamadmin.git
```

### Deploy
```bash
# Push changes
git push production main

# Update working directory on server
ssh username@server 'cd /opt/your-path/gamadmin && git pull origin main'
```

## Rollback to Previous Version

If you need to rollback:

```bash
# On production server, see available versions
cd /opt/your-path/gamadmin
git log --oneline

# Rollback to specific commit
git checkout <commit-hash>

# Or rollback to previous commit
git checkout HEAD~1
```

## Directory Structure on Production

```
/opt/your-path/gamadmin/          # Working directory (where app runs)
├── gamadmin.sh                   # Main script
├── database_functions.sh         # Database operations
├── database_schema.sql           # Database schema
├── logs/                         # Application logs
├── reports/                      # Generated reports  
├── tmp/                          # Temporary files
└── backups/                      # Backups

/opt/your-path/gamadmin.git/        # Bare repository (for git)
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
cd /opt/your-path/gamadmin
git log --oneline -5  # See recent deployments
git status            # Check working directory status
```