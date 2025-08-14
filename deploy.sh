#!/bin/bash

# GAMadmin Deployment Script
# Deploys GAMadmin to production server using git

set -e  # Exit on any error

# Load environment variables
if [[ -f ".env" ]]; then
    source .env
else
    echo -e "${RED}Error: .env file not found. Please create it with SSH_KEY_PASSWORD and SSH_KEY_PATH${NC}"
    exit 1
fi

# Configuration - UPDATE THESE VALUES
PRODUCTION_SERVER="gamera2.your-domain.edu"
PRODUCTION_USER="gamadmin" 
PRODUCTION_PATH="/opt/gamera/mjb9/gamadmin"
BARE_REPO_PATH="/opt/gamera/mjb9/gamadmin.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GAMadmin Deployment Script ===${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -f "gamadmin.sh" ]]; then
    echo -e "${RED}Error: gamadmin.sh not found. Please run this script from the GAMadmin directory.${NC}"
    exit 1
fi

# Check if git repo is clean
if ! git diff-index --quiet HEAD --; then
    echo -e "${YELLOW}Warning: You have uncommitted changes.${NC}"
    echo -e "${YELLOW}Please commit your changes before deploying.${NC}"
    git status --short
    exit 1
fi

echo -e "${BLUE}Current commit to deploy:${NC}"
git log --oneline -1
echo ""

# Confirm deployment
read -p "Deploy this commit to production? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo -e "${BLUE}Setting up production server (one-time setup)...${NC}"

# Create the bare repository on production server (if it doesn't exist)
ssh "$PRODUCTION_USER@$PRODUCTION_SERVER" "
    if [[ ! -d '$BARE_REPO_PATH' ]]; then
        echo 'Creating bare repository...'
        mkdir -p '$BARE_REPO_PATH'
        cd '$BARE_REPO_PATH'
        git init --bare
        echo 'Bare repository created at $BARE_REPO_PATH'
    else
        echo 'Bare repository already exists'
    fi
"

# Clone working directory on production server (if it doesn't exist)
ssh "$PRODUCTION_USER@$PRODUCTION_SERVER" "
    if [[ ! -d '$PRODUCTION_PATH' ]]; then
        echo 'Creating working directory...'
        git clone '$BARE_REPO_PATH' '$PRODUCTION_PATH'
        echo 'Working directory created at $PRODUCTION_PATH'
    else
        echo 'Working directory already exists'
    fi
"

# Add production remote (if not already added)
if ! git remote get-url production >/dev/null 2>&1; then
    echo -e "${BLUE}Adding production remote...${NC}"
    git remote add production "$PRODUCTION_USER@$PRODUCTION_SERVER:$BARE_REPO_PATH"
else
    echo -e "${BLUE}Production remote already exists${NC}"
fi

# Push to production using ssh-agent for password automation
echo -e "${BLUE}Pushing to production server...${NC}"

# Start ssh-agent and add key with password
eval "$(ssh-agent -s)" >/dev/null
expect -c "
    spawn ssh-add \"$SSH_KEY_PATH\"
    expect \"Enter passphrase\"
    send \"$SSH_KEY_PASSWORD\\r\"
    expect eof
" >/dev/null 2>&1

git push production main

# Kill ssh-agent
kill $SSH_AGENT_PID >/dev/null 2>&1 || true

# Update working directory on production server
echo -e "${BLUE}Updating production working directory...${NC}"

# Use the same ssh-agent session
eval "$(ssh-agent -s)" >/dev/null
expect -c "
    spawn ssh-add \"$SSH_KEY_PATH\"
    expect \"Enter passphrase\"
    send \"$SSH_KEY_PASSWORD\\r\"
    expect eof
" >/dev/null 2>&1

ssh "$PRODUCTION_USER@$PRODUCTION_SERVER" "
    cd '$PRODUCTION_PATH'
    git pull origin main
    
    # Make scripts executable
    chmod +x gamadmin.sh database_functions.sh 2>/dev/null || true
    
    # Create necessary directories if they don't exist
    mkdir -p logs reports tmp backups
    
    # Set proper permissions
    chmod 755 logs reports tmp backups 2>/dev/null || true
    
    echo 'Production deployment complete!'
    echo 'Location: $PRODUCTION_PATH'
    echo 'Main script: $PRODUCTION_PATH/gamadmin.sh'
"

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo -e "${GREEN}GAMadmin has been successfully deployed to:${NC}"
echo -e "${GREEN}  Server: $PRODUCTION_SERVER${NC}"
echo -e "${GREEN}  Path: $PRODUCTION_PATH${NC}"
echo -e "${GREEN}  Script: $PRODUCTION_PATH/gamadmin.sh${NC}"
echo ""
echo -e "${BLUE}To run on production server:${NC}"
echo -e "${BLUE}  ssh $PRODUCTION_USER@$PRODUCTION_SERVER${NC}"
echo -e "${BLUE}  cd $PRODUCTION_PATH${NC}"
echo -e "${BLUE}  ./gamadmin.sh${NC}"

# Kill ssh-agent
kill $SSH_AGENT_PID >/dev/null 2>&1 || true
