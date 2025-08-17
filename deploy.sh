#!/bin/bash

# GWOMBAT Deployment Script
# Deploys GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner) to production server
# Uses git for version-controlled deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment configuration
if [[ -f ".env" ]]; then
    source .env
    echo -e "${GREEN}✓ Loaded environment configuration from .env${NC}"
else
    echo -e "${RED}✗ Error: .env file not found${NC}"
    echo "Please copy .env.template to .env and configure your deployment settings"
    exit 1
fi

# Required variables check
REQUIRED_VARS=("PRODUCTION_SERVER" "PRODUCTION_USER" "GWOMBAT_PATH")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}✗ Error: Required variable $var not set in .env${NC}"
        exit 1
    fi
done

# Set defaults
DEPLOYMENT_BRANCH="${DEPLOYMENT_BRANCH:-main}"
BACKUP_BEFORE_DEPLOY="${BACKUP_BEFORE_DEPLOY:-false}"
BARE_REPO_PATH="${BARE_REPO_PATH:-${GWOMBAT_PATH}.git}"

echo -e "${BLUE}=== GWOMBAT Deployment ===${NC}"
echo "Target: ${PRODUCTION_USER}@${PRODUCTION_SERVER}:${GWOMBAT_PATH}"
echo "Branch: ${DEPLOYMENT_BRANCH}"
echo ""

# Check if we have uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}⚠ Warning: You have uncommitted changes${NC}"
    echo "Commit them first with: git add -A && git commit -m 'Your message'"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check SSH connectivity
echo -e "${YELLOW}Testing SSH connectivity...${NC}"
if ! ssh -o ConnectTimeout=10 "${PRODUCTION_USER}@${PRODUCTION_SERVER}" echo "SSH OK" >/dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to ${PRODUCTION_USER}@${PRODUCTION_SERVER}${NC}"
    echo "Please ensure SSH access is configured"
    exit 1
fi
echo -e "${GREEN}✓ SSH connectivity verified${NC}"

# Setup function for initial deployment
setup_deployment() {
    echo -e "${YELLOW}Setting up initial deployment...${NC}"
    
    # Create bare repository on server
    echo "Creating bare repository..."
    ssh "${PRODUCTION_USER}@${PRODUCTION_SERVER}" "
        mkdir -p '${BARE_REPO_PATH}' &&
        cd '${BARE_REPO_PATH}' &&
        git init --bare
    "
    
    # Create working directory and clone
    echo "Setting up working directory..."
    ssh "${PRODUCTION_USER}@${PRODUCTION_SERVER}" "
        if [[ ! -d '${GWOMBAT_PATH}' ]]; then
            git clone '${BARE_REPO_PATH}' '${GWOMBAT_PATH}'
        fi
        cd '${GWOMBAT_PATH}' &&
        mkdir -p logs reports tmp backups config
    "
    
    # Add production remote locally
    if ! git remote get-url production >/dev/null 2>&1; then
        echo "Adding production remote..."
        git remote add production "${PRODUCTION_USER}@${PRODUCTION_SERVER}:${BARE_REPO_PATH}"
    fi
    
    echo -e "${GREEN}✓ Initial deployment setup complete${NC}"
}

# Deploy function
deploy() {
    echo -e "${YELLOW}Deploying to production...${NC}"
    
    # Create backup if requested
    if [[ "$BACKUP_BEFORE_DEPLOY" == "true" ]]; then
        echo "Creating backup..."
        BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
        ssh "${PRODUCTION_USER}@${PRODUCTION_SERVER}" "
            cd '$(dirname "${GWOMBAT_PATH}")' &&
            cp -r '$(basename "${GWOMBAT_PATH}")' '${BACKUP_NAME}'
        "
        echo -e "${GREEN}✓ Backup created: ${BACKUP_NAME}${NC}"
    fi
    
    # Push to production
    echo "Pushing changes to production..."
    git push production "${DEPLOYMENT_BRANCH}"
    
    # Update working directory
    echo "Updating working directory..."
    ssh "${PRODUCTION_USER}@${PRODUCTION_SERVER}" "
        cd '${GWOMBAT_PATH}' &&
        git fetch origin &&
        git reset --hard origin/${DEPLOYMENT_BRANCH} &&
        chmod +x *.sh shared-utilities/*.sh 2>/dev/null || true
    "
    
    # Copy server.env if it exists
    if [[ -f "local-config/server.env" ]]; then
        echo "Deploying server.env..."
        scp local-config/server.env "${PRODUCTION_USER}@${PRODUCTION_SERVER}:${GWOMBAT_PATH}/local-config/"
    fi
    
    echo -e "${GREEN}✓ Deployment complete${NC}"
}

# Check if this is first deployment
if ssh "${PRODUCTION_USER}@${PRODUCTION_SERVER}" "[[ ! -d '${BARE_REPO_PATH}' ]]"; then
    setup_deployment
fi

# Perform deployment
deploy

# Show deployment status
echo ""
echo -e "${BLUE}=== Deployment Summary ===${NC}"
COMMIT_HASH=$(git rev-parse HEAD | cut -c1-8)
COMMIT_MSG=$(git log -1 --pretty=format:"%s")
echo "Deployed commit: ${COMMIT_HASH} - ${COMMIT_MSG}"
echo "Server: ${PRODUCTION_USER}@${PRODUCTION_SERVER}"
echo "Path: ${GWOMBAT_PATH}"
echo ""
echo -e "${GREEN}Deployment successful!${NC}"
echo ""
echo "To verify deployment:"
echo "  ssh ${PRODUCTION_USER}@${PRODUCTION_SERVER} 'cd ${GWOMBAT_PATH} && ./gwombat.sh'"
echo ""
echo "To rollback if needed:"
echo "  ssh ${PRODUCTION_USER}@${PRODUCTION_SERVER} 'cd ${GWOMBAT_PATH} && git checkout HEAD~1'"