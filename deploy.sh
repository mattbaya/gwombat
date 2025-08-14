#!/bin/bash

# GWOMBAT Deployment Script
# Deploys GWOMBAT (Google Workspace Optimization, Management, Backups And Taskrunner) to production server using git

set -e  # Exit on any error

# Load environment variables
if [[ -f ".env" ]]; then
    source .env
else
    echo -e "${RED}Error: .env file not found. Please create it from .env.template${NC}"
    exit 1
fi

# Validate required environment variables
if [[ -z "$PRODUCTION_SERVER" || -z "$PRODUCTION_USER" || -z "$GWOMBAT_PATH" ]]; then
    echo -e "${RED}Error: Missing required .env variables (PRODUCTION_SERVER, PRODUCTION_USER, GWOMBAT_PATH)${NC}"
    exit 1
fi

# Set derived paths
PRODUCTION_PATH="${PRODUCTION_PATH:-$GWOMBAT_PATH}"
BARE_REPO_PATH="${BARE_REPO_PATH:-${GWOMBAT_PATH}.git}"

# Create deployment log
DEPLOY_LOG="deploy-$(date +%Y%m%d_%H%M%S).log"
echo "=== GWOMBAT Deployment Log - $(date) ===" > "$DEPLOY_LOG"
echo "Production Server: $PRODUCTION_SERVER" >> "$DEPLOY_LOG"
echo "Production User: $PRODUCTION_USER" >> "$DEPLOY_LOG"
echo "GWOMBAT Path: $GWOMBAT_PATH" >> "$DEPLOY_LOG"
echo "Bare Repo Path: $BARE_REPO_PATH" >> "$DEPLOY_LOG"
echo "Current Commit: $(git log --oneline -1)" >> "$DEPLOY_LOG"
echo "" >> "$DEPLOY_LOG"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== GWOMBAT Deployment Script ===${NC}"
echo -e "${BLUE}Deployment log: $DEPLOY_LOG${NC}"
echo ""

# Check if we're in the right directory
if [[ ! -f "gwombat.sh" ]]; then
    echo -e "${RED}Error: gwombat.sh not found. Please run this script from the GWOMBAT directory.${NC}"
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

# Start ssh-agent and load deployment key once
echo -e "${BLUE}Starting SSH agent and loading deployment key...${NC}"
eval "$(ssh-agent -s)" >/dev/null

# Load deployment key with password automation
echo -e "${BLUE}Loading deployment key (one-time password entry)...${NC}"
expect -c "
    spawn ssh-add \"$SSH_KEY_PATH\"
    expect \"Enter passphrase\"
    send \"$SSH_KEY_PASSWORD\\r\"
    expect eof
" >/dev/null 2>&1

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Deployment key loaded successfully${NC}"
else
    echo -e "${RED}❌ Failed to load deployment key${NC}"
    kill $SSH_AGENT_PID >/dev/null 2>&1 || true
    exit 1
fi

# Configure git to use SSH with our specific key only
SSH_CONFIG_HOST="gamadmin-deploy"
SSH_REMOTE_URL="$SSH_CONFIG_HOST:$BARE_REPO_PATH"

# Create temporary SSH config entry
echo -e "${BLUE}Configuring SSH for deployment...${NC}"
mkdir -p ~/.ssh
if ! grep -q "Host $SSH_CONFIG_HOST" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << EOF

Host $SSH_CONFIG_HOST
    HostName $PRODUCTION_SERVER
    User $PRODUCTION_USER
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
    PreferredAuthentications publickey
EOF
    echo "Added SSH config entry for deployment"
else
    echo "SSH config entry already exists"
fi

# Add production remote (if not already added)
if ! git remote get-url production >/dev/null 2>&1; then
    echo -e "${BLUE}Adding production remote...${NC}"
    git remote add production "$SSH_REMOTE_URL"
else
    echo -e "${BLUE}Updating production remote URL...${NC}"
    git remote set-url production "$SSH_REMOTE_URL"
fi

# Push to production (using loaded key)
echo -e "${BLUE}Pushing to production server...${NC}"
export SSH_AUTH_SOCK=$SSH_AUTH_SOCK
export SSH_AGENT_PID=$SSH_AGENT_PID
git push production main

# Update working directory on production server (using same ssh-agent session)
echo -e "${BLUE}Updating production working directory...${NC}"
export SSH_AUTH_SOCK=$SSH_AUTH_SOCK
export SSH_AGENT_PID=$SSH_AGENT_PID
ssh "$SSH_CONFIG_HOST" "
    cd '$PRODUCTION_PATH'
    git pull origin main
    
    # Make scripts executable
    chmod +x gamadmin.sh database_functions.sh 2>/dev/null || true
    
    # Create necessary directories if they don't exist
    mkdir -p logs reports tmp backups
    
    # Copy server configuration template if server.env doesn't exist
    if [[ ! -f server.env ]]; then
        cp server.env.template server.env
        echo 'Created server.env from template - please customize paths as needed'
    fi
    
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
echo -e "${BLUE}  ssh $SSH_CONFIG_HOST${NC}"
echo -e "${BLUE}  cd $PRODUCTION_PATH${NC}"
echo -e "${BLUE}  ./gamadmin.sh${NC}"

# Log deployment completion
echo "=== Deployment completed successfully at $(date) ===" >> "$DEPLOY_LOG"
echo -e "${GREEN}Deployment logged to: $DEPLOY_LOG${NC}"

# Clean up ssh-agent
kill $SSH_AGENT_PID >/dev/null 2>&1 || true
