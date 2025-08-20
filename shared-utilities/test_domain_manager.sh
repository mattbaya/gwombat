#!/bin/bash

# GWOMBAT Test Domain Manager
# Provides safe test domain switching and configuration management

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration
if [[ -f "$GWOMBAT_ROOT/local-config/.env" ]]; then
    source "$GWOMBAT_ROOT/local-config/.env"
fi

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Test domain configuration file
TEST_CONFIG_FILE="$GWOMBAT_ROOT/local-config/test-domains.env"

# Initialize test domain configuration
init_test_domain_config() {
    if [[ ! -f "$TEST_CONFIG_FILE" ]]; then
        echo -e "${CYAN}Creating test domain configuration file...${NC}"
        cat > "$TEST_CONFIG_FILE" << 'EOF'
# GWOMBAT Test Domain Configuration
# Configure multiple test domains for safe development and testing

# Production domain (current active domain)
PRODUCTION_DOMAIN=""
PRODUCTION_ADMIN_USER=""
PRODUCTION_GAM_PATH=""

# Test Domain 1
TEST_DOMAIN_1=""
TEST_DOMAIN_1_ADMIN_USER=""
TEST_DOMAIN_1_GAM_PATH=""
TEST_DOMAIN_1_DESCRIPTION="Development Test Domain"

# Test Domain 2  
TEST_DOMAIN_2=""
TEST_DOMAIN_2_ADMIN_USER=""
TEST_DOMAIN_2_GAM_PATH=""
TEST_DOMAIN_2_DESCRIPTION="Staging Test Domain"

# Test Domain 3
TEST_DOMAIN_3=""
TEST_DOMAIN_3_ADMIN_USER=""
TEST_DOMAIN_3_GAM_PATH=""
TEST_DOMAIN_3_DESCRIPTION="Sandbox Test Domain"

# Current active domain mode (production, test1, test2, test3)
ACTIVE_DOMAIN_MODE="production"

# Test mode safety settings
TEST_MODE_ENABLED="false"
TEST_MODE_DRY_RUN="true"
TEST_MODE_CONFIRMATION_REQUIRED="true"
EOF
        echo -e "${GREEN}✓ Created: $TEST_CONFIG_FILE${NC}"
        echo -e "${YELLOW}Please edit this file to configure your test domains${NC}"
    fi
}

# Load test domain configuration
load_test_config() {
    if [[ -f "$TEST_CONFIG_FILE" ]]; then
        source "$TEST_CONFIG_FILE"
    else
        echo -e "${YELLOW}Test domain configuration not found. Initializing...${NC}"
        init_test_domain_config
        source "$TEST_CONFIG_FILE"
    fi
}

# Get current domain info
get_current_domain_info() {
    load_test_config
    
    case "${ACTIVE_DOMAIN_MODE:-production}" in
        "production")
            echo "Mode: Production"
            echo "Domain: ${PRODUCTION_DOMAIN:-${DOMAIN:-not set}}"
            echo "Admin: ${PRODUCTION_ADMIN_USER:-${ADMIN_USER:-not set}}"
            echo "GAM: ${PRODUCTION_GAM_PATH:-${GAM_PATH:-not set}}"
            ;;
        "test1")
            echo "Mode: Test Domain 1"
            echo "Domain: ${TEST_DOMAIN_1:-not configured}"
            echo "Admin: ${TEST_DOMAIN_1_ADMIN_USER:-not configured}"
            echo "GAM: ${TEST_DOMAIN_1_GAM_PATH:-not configured}"
            echo "Description: ${TEST_DOMAIN_1_DESCRIPTION:-Test Domain 1}"
            ;;
        "test2")
            echo "Mode: Test Domain 2"
            echo "Domain: ${TEST_DOMAIN_2:-not configured}"
            echo "Admin: ${TEST_DOMAIN_2_ADMIN_USER:-not configured}"
            echo "GAM: ${TEST_DOMAIN_2_GAM_PATH:-not configured}"
            echo "Description: ${TEST_DOMAIN_2_DESCRIPTION:-Test Domain 2}"
            ;;
        "test3")
            echo "Mode: Test Domain 3"
            echo "Domain: ${TEST_DOMAIN_3:-not configured}"
            echo "Admin: ${TEST_DOMAIN_3_ADMIN_USER:-not configured}"
            echo "GAM: ${TEST_DOMAIN_3_GAM_PATH:-not configured}"
            echo "Description: ${TEST_DOMAIN_3_DESCRIPTION:-Test Domain 3}"
            ;;
        *)
            echo "Mode: Unknown (${ACTIVE_DOMAIN_MODE})"
            echo "Domain: ${DOMAIN:-not set}"
            echo "Admin: ${ADMIN_USER:-not set}"
            ;;
    esac
}

# Switch to specified domain
switch_to_domain() {
    local target_mode="$1"
    
    if [[ -z "$target_mode" ]]; then
        echo -e "${RED}Error: Target domain mode not specified${NC}"
        return 1
    fi
    
    load_test_config
    
    echo -e "${CYAN}Switching to domain mode: $target_mode${NC}"
    
    # Save current production settings if not already saved
    if [[ -z "$PRODUCTION_DOMAIN" && -n "$DOMAIN" ]]; then
        echo -e "${YELLOW}Saving current production settings...${NC}"
        sed -i.bak "s/PRODUCTION_DOMAIN=\"\"/PRODUCTION_DOMAIN=\"$DOMAIN\"/" "$TEST_CONFIG_FILE"
        sed -i.bak "s/PRODUCTION_ADMIN_USER=\"\"/PRODUCTION_ADMIN_USER=\"$ADMIN_USER\"/" "$TEST_CONFIG_FILE"
        sed -i.bak "s|PRODUCTION_GAM_PATH=\"\"|PRODUCTION_GAM_PATH=\"$GAM_PATH\"|" "$TEST_CONFIG_FILE"
    fi
    
    # Backup current configuration
    local backup_file="$GWOMBAT_ROOT/local-config/.env.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f "$GWOMBAT_ROOT/local-config/.env" ]]; then
        cp "$GWOMBAT_ROOT/local-config/.env" "$backup_file"
        echo -e "${GREEN}✓ Backed up current config to: $(basename "$backup_file")${NC}"
    fi
    
    # Apply domain configuration
    case "$target_mode" in
        "production")
            if [[ -n "$PRODUCTION_DOMAIN" ]]; then
                update_env_file "DOMAIN" "$PRODUCTION_DOMAIN"
                update_env_file "ADMIN_USER" "$PRODUCTION_ADMIN_USER"
                update_env_file "GAM_PATH" "$PRODUCTION_GAM_PATH"
                update_test_config "ACTIVE_DOMAIN_MODE" "production"
                update_test_config "TEST_MODE_ENABLED" "false"
                echo -e "${GREEN}✓ Switched to production domain: $PRODUCTION_DOMAIN${NC}"
            else
                echo -e "${RED}Production domain not configured${NC}"
                return 1
            fi
            ;;
        "test1")
            if [[ -n "$TEST_DOMAIN_1" ]]; then
                update_env_file "DOMAIN" "$TEST_DOMAIN_1"
                update_env_file "ADMIN_USER" "$TEST_DOMAIN_1_ADMIN_USER"
                update_env_file "GAM_PATH" "$TEST_DOMAIN_1_GAM_PATH"
                update_test_config "ACTIVE_DOMAIN_MODE" "test1"
                update_test_config "TEST_MODE_ENABLED" "true"
                echo -e "${GREEN}✓ Switched to test domain 1: $TEST_DOMAIN_1${NC}"
                echo -e "${YELLOW}⚠️ TEST MODE ENABLED - Operations will be logged and confirmed${NC}"
            else
                echo -e "${RED}Test domain 1 not configured${NC}"
                return 1
            fi
            ;;
        "test2")
            if [[ -n "$TEST_DOMAIN_2" ]]; then
                update_env_file "DOMAIN" "$TEST_DOMAIN_2"
                update_env_file "ADMIN_USER" "$TEST_DOMAIN_2_ADMIN_USER"
                update_env_file "GAM_PATH" "$TEST_DOMAIN_2_GAM_PATH"
                update_test_config "ACTIVE_DOMAIN_MODE" "test2"
                update_test_config "TEST_MODE_ENABLED" "true"
                echo -e "${GREEN}✓ Switched to test domain 2: $TEST_DOMAIN_2${NC}"
                echo -e "${YELLOW}⚠️ TEST MODE ENABLED - Operations will be logged and confirmed${NC}"
            else
                echo -e "${RED}Test domain 2 not configured${NC}"
                return 1
            fi
            ;;
        "test3")
            if [[ -n "$TEST_DOMAIN_3" ]]; then
                update_env_file "DOMAIN" "$TEST_DOMAIN_3"
                update_env_file "ADMIN_USER" "$TEST_DOMAIN_3_ADMIN_USER"
                update_env_file "GAM_PATH" "$TEST_DOMAIN_3_GAM_PATH"
                update_test_config "ACTIVE_DOMAIN_MODE" "test3"
                update_test_config "TEST_MODE_ENABLED" "true"
                echo -e "${GREEN}✓ Switched to test domain 3: $TEST_DOMAIN_3${NC}"
                echo -e "${YELLOW}⚠️ TEST MODE ENABLED - Operations will be logged and confirmed${NC}"
            else
                echo -e "${RED}Test domain 3 not configured${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}Invalid domain mode: $target_mode${NC}"
            echo "Valid modes: production, test1, test2, test3"
            return 1
            ;;
    esac
    
    # Verify GAM connectivity
    echo -e "${CYAN}Verifying GAM connectivity...${NC}"
    if verify_gam_connection; then
        echo -e "${GREEN}✓ GAM connection verified${NC}"
    else
        echo -e "${RED}❌ GAM connection failed - please check configuration${NC}"
        return 1
    fi
    
    return 0
}

# Update environment file
update_env_file() {
    local key="$1"
    local value="$2"
    local env_file="$GWOMBAT_ROOT/local-config/.env"
    
    if [[ -f "$env_file" ]]; then
        if grep -q "^${key}=" "$env_file"; then
            sed -i.bak "s|^${key}=.*|${key}=\"${value}\"|" "$env_file"
        else
            echo "${key}=\"${value}\"" >> "$env_file"
        fi
    else
        mkdir -p "$(dirname "$env_file")"
        echo "${key}=\"${value}\"" > "$env_file"
    fi
}

# Update test configuration file
update_test_config() {
    local key="$1"
    local value="$2"
    
    if [[ -f "$TEST_CONFIG_FILE" ]]; then
        if grep -q "^${key}=" "$TEST_CONFIG_FILE"; then
            sed -i.bak "s|^${key}=.*|${key}=\"${value}\"|" "$TEST_CONFIG_FILE"
        else
            echo "${key}=\"${value}\"" >> "$TEST_CONFIG_FILE"
        fi
    fi
}

# Verify GAM connection
verify_gam_connection() {
    load_test_config
    
    # Get current GAM path based on active mode
    local gam_path=""
    case "${ACTIVE_DOMAIN_MODE:-production}" in
        "production") gam_path="$PRODUCTION_GAM_PATH" ;;
        "test1") gam_path="$TEST_DOMAIN_1_GAM_PATH" ;;
        "test2") gam_path="$TEST_DOMAIN_2_GAM_PATH" ;;
        "test3") gam_path="$TEST_DOMAIN_3_GAM_PATH" ;;
    esac
    
    if [[ -z "$gam_path" ]]; then
        gam_path="$GAM_PATH"
    fi
    
    if [[ ! -x "$gam_path" ]]; then
        echo -e "${RED}GAM executable not found or not executable: $gam_path${NC}"
        return 1
    fi
    
    # Test GAM connection
    if timeout 10 "$gam_path" info domain >/dev/null 2>&1; then
        return 0
    else
        echo -e "${RED}GAM connection test failed${NC}"
        return 1
    fi
}

# Configure test domain
configure_test_domain() {
    local domain_num="$1"
    
    if [[ -z "$domain_num" ]] || [[ ! "$domain_num" =~ ^[1-3]$ ]]; then
        echo -e "${RED}Invalid domain number. Use 1, 2, or 3${NC}"
        return 1
    fi
    
    load_test_config
    
    echo -e "${CYAN}Configuring Test Domain $domain_num${NC}"
    echo ""
    
    # Get current values
    local current_domain=""
    local current_admin=""
    local current_gam=""
    local current_desc=""
    
    case "$domain_num" in
        "1")
            current_domain="$TEST_DOMAIN_1"
            current_admin="$TEST_DOMAIN_1_ADMIN_USER"
            current_gam="$TEST_DOMAIN_1_GAM_PATH"
            current_desc="$TEST_DOMAIN_1_DESCRIPTION"
            ;;
        "2")
            current_domain="$TEST_DOMAIN_2"
            current_admin="$TEST_DOMAIN_2_ADMIN_USER"
            current_gam="$TEST_DOMAIN_2_GAM_PATH"
            current_desc="$TEST_DOMAIN_2_DESCRIPTION"
            ;;
        "3")
            current_domain="$TEST_DOMAIN_3"
            current_admin="$TEST_DOMAIN_3_ADMIN_USER"
            current_gam="$TEST_DOMAIN_3_GAM_PATH"
            current_desc="$TEST_DOMAIN_3_DESCRIPTION"
            ;;
    esac
    
    # Prompt for domain
    echo -e "${WHITE}Google Workspace Domain:${NC}"
    echo "Current: ${current_domain:-not set}"
    read -p "Enter domain (leave blank to keep current): " new_domain
    if [[ -n "$new_domain" ]]; then
        update_test_config "TEST_DOMAIN_${domain_num}" "$new_domain"
    fi
    
    # Prompt for admin user
    echo ""
    echo -e "${WHITE}Admin User:${NC}"
    echo "Current: ${current_admin:-not set}"
    read -p "Enter admin user (leave blank to keep current): " new_admin
    if [[ -n "$new_admin" ]]; then
        update_test_config "TEST_DOMAIN_${domain_num}_ADMIN_USER" "$new_admin"
    fi
    
    # Prompt for GAM path
    echo ""
    echo -e "${WHITE}GAM Executable Path:${NC}"
    echo "Current: ${current_gam:-not set}"
    read -p "Enter GAM path (leave blank to keep current): " new_gam
    if [[ -n "$new_gam" ]]; then
        update_test_config "TEST_DOMAIN_${domain_num}_GAM_PATH" "$new_gam"
    fi
    
    # Prompt for description
    echo ""
    echo -e "${WHITE}Description:${NC}"
    echo "Current: ${current_desc:-Test Domain $domain_num}"
    read -p "Enter description (leave blank to keep current): " new_desc
    if [[ -n "$new_desc" ]]; then
        update_test_config "TEST_DOMAIN_${domain_num}_DESCRIPTION" "$new_desc"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Test Domain $domain_num configuration updated${NC}"
    
    # Offer to test connection
    read -p "Test GAM connection for this domain? (y/N): " test_conn
    if [[ "$test_conn" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Testing GAM connection...${NC}"
        
        # Temporarily switch to test domain for verification
        local original_mode="$ACTIVE_DOMAIN_MODE"
        ACTIVE_DOMAIN_MODE="test$domain_num"
        
        if verify_gam_connection; then
            echo -e "${GREEN}✓ GAM connection successful${NC}"
        else
            echo -e "${RED}❌ GAM connection failed${NC}"
        fi
        
        # Restore original mode
        ACTIVE_DOMAIN_MODE="$original_mode"
    fi
}

# Test domain menu
test_domain_menu() {
    while true; do
        clear
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                         GWOMBAT - Test Domain Management                       ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        echo -e "${CYAN}🔧 Current Domain Configuration:${NC}"
        get_current_domain_info | sed 's/^/  /'
        echo ""
        
        # Show test mode status
        load_test_config
        if [[ "${TEST_MODE_ENABLED:-false}" == "true" ]]; then
            echo -e "${YELLOW}⚠️ TEST MODE ACTIVE - Enhanced safety checks enabled${NC}"
            echo ""
        fi
        
        echo -e "${YELLOW}Domain Management:${NC}"
        echo "  1. 🏢 Switch to Production Domain"
        echo "  2. 🧪 Switch to Test Domain 1"
        echo "  3. 🧪 Switch to Test Domain 2"
        echo "  4. 🧪 Switch to Test Domain 3"
        echo ""
        echo -e "${YELLOW}Configuration:${NC}"
        echo "  5. ⚙️ Configure Test Domain 1"
        echo "  6. ⚙️ Configure Test Domain 2"
        echo "  7. ⚙️ Configure Test Domain 3"
        echo "  8. 📋 View All Domain Configurations"
        echo "  9. 🔍 Test GAM Connectivity"
        echo ""
        echo -e "${YELLOW}Safety & Settings:${NC}"
        echo " 10. 🛡️ Configure Test Mode Safety Settings"
        echo " 11. 💾 Backup/Restore Domain Configurations"
        echo ""
        echo "b. ⬅️ Back to previous menu"
        echo "m. 🏠 Main menu"
        echo "x. ❌ Exit"
        echo ""
        
        read -p "Select option (1-11, b, m, x): " choice
        echo ""
        
        case "$choice" in
            1) 
                echo -e "${CYAN}Switching to Production Domain...${NC}"
                if switch_to_domain "production"; then
                    echo -e "${GREEN}✓ Successfully switched to production domain${NC}"
                else
                    echo -e "${RED}❌ Failed to switch to production domain${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${CYAN}Switching to Test Domain 1...${NC}"
                if switch_to_domain "test1"; then
                    echo -e "${GREEN}✓ Successfully switched to test domain 1${NC}"
                else
                    echo -e "${RED}❌ Failed to switch to test domain 1${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${CYAN}Switching to Test Domain 2...${NC}"
                if switch_to_domain "test2"; then
                    echo -e "${GREEN}✓ Successfully switched to test domain 2${NC}"
                else
                    echo -e "${RED}❌ Failed to switch to test domain 2${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${CYAN}Switching to Test Domain 3...${NC}"
                if switch_to_domain "test3"; then
                    echo -e "${GREEN}✓ Successfully switched to test domain 3${NC}"
                else
                    echo -e "${RED}❌ Failed to switch to test domain 3${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            5) configure_test_domain "1" && read -p "Press Enter to continue..." ;;
            6) configure_test_domain "2" && read -p "Press Enter to continue..." ;;
            7) configure_test_domain "3" && read -p "Press Enter to continue..." ;;
            8) 
                view_all_configurations
                read -p "Press Enter to continue..."
                ;;
            9)
                test_gam_connectivity
                read -p "Press Enter to continue..."
                ;;
            10)
                configure_safety_settings
                read -p "Press Enter to continue..."
                ;;
            11)
                backup_restore_configs
                read -p "Press Enter to continue..."
                ;;
            b|B) return ;;
            m|M) 
                if type main_menu >/dev/null 2>&1; then
                    main_menu
                else
                    return
                fi
                ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# View all domain configurations
view_all_configurations() {
    load_test_config
    
    echo -e "${CYAN}All Domain Configurations:${NC}"
    echo ""
    
    echo -e "${WHITE}Production Domain:${NC}"
    echo "  Domain: ${PRODUCTION_DOMAIN:-not configured}"
    echo "  Admin: ${PRODUCTION_ADMIN_USER:-not configured}"
    echo "  GAM: ${PRODUCTION_GAM_PATH:-not configured}"
    echo ""
    
    echo -e "${WHITE}Test Domain 1:${NC}"
    echo "  Domain: ${TEST_DOMAIN_1:-not configured}"
    echo "  Admin: ${TEST_DOMAIN_1_ADMIN_USER:-not configured}"
    echo "  GAM: ${TEST_DOMAIN_1_GAM_PATH:-not configured}"
    echo "  Description: ${TEST_DOMAIN_1_DESCRIPTION:-Test Domain 1}"
    echo ""
    
    echo -e "${WHITE}Test Domain 2:${NC}"
    echo "  Domain: ${TEST_DOMAIN_2:-not configured}"
    echo "  Admin: ${TEST_DOMAIN_2_ADMIN_USER:-not configured}"
    echo "  GAM: ${TEST_DOMAIN_2_GAM_PATH:-not configured}"
    echo "  Description: ${TEST_DOMAIN_2_DESCRIPTION:-Test Domain 2}"
    echo ""
    
    echo -e "${WHITE}Test Domain 3:${NC}"
    echo "  Domain: ${TEST_DOMAIN_3:-not configured}"
    echo "  Admin: ${TEST_DOMAIN_3_ADMIN_USER:-not configured}"
    echo "  GAM: ${TEST_DOMAIN_3_GAM_PATH:-not configured}"
    echo "  Description: ${TEST_DOMAIN_3_DESCRIPTION:-Test Domain 3}"
    echo ""
    
    echo -e "${WHITE}Active Mode:${NC} ${ACTIVE_DOMAIN_MODE:-production}"
    echo -e "${WHITE}Test Mode:${NC} ${TEST_MODE_ENABLED:-false}"
}

# Test GAM connectivity for all domains
test_gam_connectivity() {
    echo -e "${CYAN}Testing GAM connectivity for all configured domains...${NC}"
    echo ""
    
    load_test_config
    
    # Test production
    if [[ -n "$PRODUCTION_DOMAIN" ]]; then
        echo -e "${WHITE}Production Domain ($PRODUCTION_DOMAIN):${NC}"
        local old_mode="$ACTIVE_DOMAIN_MODE"
        ACTIVE_DOMAIN_MODE="production"
        if verify_gam_connection; then
            echo "  ✅ Connected"
        else
            echo "  ❌ Failed"
        fi
        ACTIVE_DOMAIN_MODE="$old_mode"
    fi
    
    # Test domain 1
    if [[ -n "$TEST_DOMAIN_1" ]]; then
        echo -e "${WHITE}Test Domain 1 ($TEST_DOMAIN_1):${NC}"
        local old_mode="$ACTIVE_DOMAIN_MODE"
        ACTIVE_DOMAIN_MODE="test1"
        if verify_gam_connection; then
            echo "  ✅ Connected"
        else
            echo "  ❌ Failed"
        fi
        ACTIVE_DOMAIN_MODE="$old_mode"
    fi
    
    # Test domain 2
    if [[ -n "$TEST_DOMAIN_2" ]]; then
        echo -e "${WHITE}Test Domain 2 ($TEST_DOMAIN_2):${NC}"
        local old_mode="$ACTIVE_DOMAIN_MODE"
        ACTIVE_DOMAIN_MODE="test2"
        if verify_gam_connection; then
            echo "  ✅ Connected"
        else
            echo "  ❌ Failed"
        fi
        ACTIVE_DOMAIN_MODE="$old_mode"
    fi
    
    # Test domain 3
    if [[ -n "$TEST_DOMAIN_3" ]]; then
        echo -e "${WHITE}Test Domain 3 ($TEST_DOMAIN_3):${NC}"
        local old_mode="$ACTIVE_DOMAIN_MODE"
        ACTIVE_DOMAIN_MODE="test3"
        if verify_gam_connection; then
            echo "  ✅ Connected"
        else
            echo "  ❌ Failed"
        fi
        ACTIVE_DOMAIN_MODE="$old_mode"
    fi
}

# Configure safety settings
configure_safety_settings() {
    load_test_config
    
    echo -e "${CYAN}Configure Test Mode Safety Settings${NC}"
    echo ""
    
    echo -e "${WHITE}Current Settings:${NC}"
    echo "  Dry Run Mode: ${TEST_MODE_DRY_RUN:-true}"
    echo "  Confirmation Required: ${TEST_MODE_CONFIRMATION_REQUIRED:-true}"
    echo ""
    
    read -p "Enable dry run mode in test domains? (y/N): " dry_run
    if [[ "$dry_run" =~ ^[Yy]$ ]]; then
        update_test_config "TEST_MODE_DRY_RUN" "true"
    else
        update_test_config "TEST_MODE_DRY_RUN" "false"
    fi
    
    read -p "Require confirmation for operations in test domains? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        update_test_config "TEST_MODE_CONFIRMATION_REQUIRED" "true"
    else
        update_test_config "TEST_MODE_CONFIRMATION_REQUIRED" "false"
    fi
    
    echo -e "${GREEN}✓ Safety settings updated${NC}"
}

# Backup and restore configurations
backup_restore_configs() {
    echo -e "${CYAN}Backup/Restore Domain Configurations${NC}"
    echo ""
    echo "1. Create backup of all configurations"
    echo "2. Restore from backup"
    echo "3. List available backups"
    echo ""
    
    read -p "Select option (1-3): " backup_choice
    
    case "$backup_choice" in
        1)
            local backup_name="domain_configs_$(date +%Y%m%d_%H%M%S)"
            local backup_dir="$GWOMBAT_ROOT/local-config/backups"
            mkdir -p "$backup_dir"
            
            echo -e "${CYAN}Creating backup: $backup_name${NC}"
            
            if [[ -f "$TEST_CONFIG_FILE" ]]; then
                cp "$TEST_CONFIG_FILE" "$backup_dir/${backup_name}_test-domains.env"
            fi
            
            if [[ -f "$GWOMBAT_ROOT/local-config/.env" ]]; then
                cp "$GWOMBAT_ROOT/local-config/.env" "$backup_dir/${backup_name}_config.env"
            fi
            
            echo -e "${GREEN}✓ Backup created in: $backup_dir${NC}"
            ;;
        2)
            echo -e "${YELLOW}Available backups:${NC}"
            ls -la "$GWOMBAT_ROOT/local-config/backups/"*_test-domains.env 2>/dev/null | sed 's/.*backups\//  /'
            echo ""
            read -p "Enter backup name (without extension): " restore_name
            # Implementation for restore would go here
            echo -e "${YELLOW}Restore functionality coming soon${NC}"
            ;;
        3)
            echo -e "${YELLOW}Available backups:${NC}"
            ls -la "$GWOMBAT_ROOT/local-config/backups/" 2>/dev/null | grep -E "(test-domains|server)\.env" | sed 's/.*backups\//  /'
            ;;
    esac
}

# Initialize on first run
init_test_domain_config

# If script is run directly, show the menu
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_domain_menu
fi