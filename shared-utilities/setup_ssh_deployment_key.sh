#!/bin/bash

# GWOMBAT SSH Deployment Key Setup Script
# Creates and configures SSH key for automated git deployment

# Source common functions and environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [[ -f "$PROJECT_ROOT/local-config/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/local-config/.env"
    set +a
else
    echo "Error: Environment file not found at $PROJECT_ROOT/local-config/.env"
    echo "Please run setup_wizard.sh first"
    exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== GWOMBAT SSH Deployment Key Setup ===${NC}"
echo ""

# Define SSH key path in local-config
LOCAL_SSH_KEY_PATH="$PROJECT_ROOT/local-config/ssh/gwombatgit-key"
LOCAL_SSH_DIR="$PROJECT_ROOT/local-config/ssh"

echo -e "${CYAN}SSH Key Storage:${NC}"
echo "Keys will be stored in: $LOCAL_SSH_DIR"
echo "This keeps private keys within the project's secure local-config directory"
echo ""

# Check if key already exists
if [[ -f "$LOCAL_SSH_KEY_PATH" ]]; then
    echo -e "${YELLOW}SSH key already exists at: $LOCAL_SSH_KEY_PATH${NC}"
    echo ""
    read -p "Do you want to regenerate the key? (y/N): " regenerate
    if [[ ! "$regenerate" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Using existing SSH key${NC}"
        exit 0
    fi
    echo ""
    echo -e "${YELLOW}Backing up existing key...${NC}"
    mv "$LOCAL_SSH_KEY_PATH" "${LOCAL_SSH_KEY_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f "${LOCAL_SSH_KEY_PATH}.pub" ]]; then
        mv "${LOCAL_SSH_KEY_PATH}.pub" "${LOCAL_SSH_KEY_PATH}.pub.backup.$(date +%Y%m%d_%H%M%S)"
    fi
fi

# Create SSH directory if it doesn't exist
if [[ ! -d "$LOCAL_SSH_DIR" ]]; then
    echo -e "${YELLOW}Creating SSH directory: $LOCAL_SSH_DIR${NC}"
    mkdir -p "$LOCAL_SSH_DIR"
    chmod 700 "$LOCAL_SSH_DIR"
fi

# Generate SSH key
echo -e "${CYAN}Generating new SSH key pair...${NC}"
echo ""

# Determine if we should use a passphrase
read -p "Do you want to set a passphrase for the SSH key? (recommended for security) (Y/n): " use_passphrase
echo ""

if [[ "$use_passphrase" =~ ^[Nn]$ ]]; then
    # Generate without passphrase
    ssh-keygen -t ed25519 -f "$LOCAL_SSH_KEY_PATH" -C "gwombat-deployment@$DOMAIN" -N ""
else
    # Generate with passphrase
    echo -e "${YELLOW}Enter a passphrase for the SSH key:${NC}"
    ssh-keygen -t ed25519 -f "$LOCAL_SSH_KEY_PATH" -C "gwombat-deployment@$DOMAIN"
fi

# Check if key was created successfully
if [[ ! -f "$LOCAL_SSH_KEY_PATH" ]]; then
    echo -e "${RED}Error: SSH key generation failed${NC}"
    exit 1
fi

# Set proper permissions
chmod 600 "$LOCAL_SSH_KEY_PATH"
if [[ -f "${LOCAL_SSH_KEY_PATH}.pub" ]]; then
    chmod 644 "${LOCAL_SSH_KEY_PATH}.pub"
fi

echo ""
echo -e "${GREEN}✓ SSH key generated successfully${NC}"
echo ""
echo -e "${CYAN}Key Details:${NC}"
echo "Private key: $LOCAL_SSH_KEY_PATH"
echo "Public key: ${LOCAL_SSH_KEY_PATH}.pub"
echo ""

# Display public key
echo -e "${CYAN}Public key content (add this to your Git server):${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat "${LOCAL_SSH_KEY_PATH}.pub"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Instructions for GitHub/GitLab
echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "${BLUE}For GitHub:${NC}"
echo "1. Go to https://github.com/settings/keys"
echo "2. Click 'New SSH key'"
echo "3. Title: GWOMBAT Deployment Key - $HOSTNAME"
echo "4. Paste the public key content shown above"
echo "5. Click 'Add SSH key'"
echo ""
echo -e "${BLUE}For GitLab:${NC}"
echo "1. Go to your GitLab profile settings"
echo "2. Navigate to 'SSH Keys'"
echo "3. Paste the public key content shown above"
echo "4. Title: GWOMBAT Deployment Key - $HOSTNAME"
echo "5. Click 'Add key'"
echo ""

# Test SSH connection
echo -e "${CYAN}Testing SSH connection...${NC}"
echo ""

# Determine Git host
if [[ -d "$PROJECT_ROOT/.git" ]]; then
    git_remote=$(cd "$PROJECT_ROOT" && git remote get-url origin 2>/dev/null)
    if [[ "$git_remote" =~ github\.com ]]; then
        echo "Testing connection to GitHub..."
        ssh -T -o StrictHostKeyChecking=no -i "$LOCAL_SSH_KEY_PATH" git@github.com 2>&1 | grep -v "Warning: Permanently added"
    elif [[ "$git_remote" =~ gitlab ]]; then
        echo "Testing connection to GitLab..."
        ssh -T -o StrictHostKeyChecking=no -i "$LOCAL_SSH_KEY_PATH" git@gitlab.com 2>&1 | grep -v "Warning: Permanently added"
    else
        echo -e "${YELLOW}Could not determine Git host from remote: $git_remote${NC}"
    fi
fi

echo ""
echo -e "${GREEN}SSH deployment key setup complete!${NC}"
echo ""

# Update .env file if needed
if grep -q "SSH_KEY_PASSWORD=\"\"" "$PROJECT_ROOT/local-config/.env"; then
    if [[ ! "$use_passphrase" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Note: If you set a passphrase, you may want to update SSH_KEY_PASSWORD in local-config/.env${NC}"
        echo -e "${YELLOW}This is only needed if using automated deployment scripts${NC}"
    fi
fi

# Add to SSH agent if requested
echo ""
read -p "Add the key to SSH agent for this session? (Y/n): " add_to_agent
if [[ ! "$add_to_agent" =~ ^[Nn]$ ]]; then
    eval "$(ssh-agent -s)" > /dev/null 2>&1
    ssh-add "$LOCAL_SSH_KEY_PATH"
    echo -e "${GREEN}✓ Key added to SSH agent${NC}"
fi

# Update .env file with new SSH key path
echo ""
echo -e "${CYAN}Updating configuration...${NC}"

# Update SSH_KEY_PATH in .env to use local-config path
if grep -q "^SSH_KEY_PATH=" "$PROJECT_ROOT/local-config/.env"; then
    # Use sed to update the path
    sed -i.bak "s|^SSH_KEY_PATH=.*|SSH_KEY_PATH=\"$LOCAL_SSH_KEY_PATH\"|" "$PROJECT_ROOT/local-config/.env"
    echo -e "${GREEN}✓ Updated SSH_KEY_PATH in local-config/.env${NC}"
else
    # Add SSH_KEY_PATH if it doesn't exist
    echo "SSH_KEY_PATH=\"$LOCAL_SSH_KEY_PATH\"" >> "$PROJECT_ROOT/local-config/.env"
    echo -e "${GREEN}✓ Added SSH_KEY_PATH to local-config/.env${NC}"
fi

echo ""
echo -e "${CYAN}Setup complete! The deployment system can now use this SSH key.${NC}"
echo -e "${CYAN}SSH key stored securely in: $LOCAL_SSH_DIR${NC}"