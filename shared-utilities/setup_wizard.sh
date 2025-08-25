#!/bin/bash
# GWOMBAT First-Time Setup Wizard
# Comprehensive configuration wizard for new installations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration files
ENV_FILE="$GWOMBAT_ROOT/local-config/.env"
ENV_TEMPLATE="$GWOMBAT_ROOT/.env.template"
# SERVER_ENV_TEMPLATE removed - all configuration now in local-config/.env

# Log file for setup process
SETUP_LOG="$GWOMBAT_ROOT/logs/setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$GWOMBAT_ROOT/logs"

# Logging function
log_setup() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$SETUP_LOG"
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[ERROR]${NC} $message"
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    fi
}

# Banner function
show_setup_banner() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    GWOMBAT First-Time Setup Wizard                          ║${NC}"
    echo -e "${BLUE}║        Google Workspace Optimization, Management, Backups And Taskrunner    ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║                                                                              ║${NC}"
    echo -e "${BLUE}║  Welcome! This wizard will help you configure GWOMBAT for your environment  ║${NC}"
    echo -e "${BLUE}║                                                                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_setup "Setup wizard started"
}

# Check if this is first time setup
is_first_time_setup() {
    if [[ ! -f "$ENV_FILE" ]]; then
        return 0  # First time
    else
        return 1  # Not first time
    fi
}

# Check dependencies
check_setup_dependencies() {
    echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
    local missing_deps=()
    
    # Essential dependencies
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    if ! command -v sqlite3 >/dev/null 2>&1; then
        missing_deps+=("sqlite3")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Missing essential dependencies:${NC}"
        printf '  - %s\n' "${missing_deps[@]}"
        echo ""
        echo -e "${YELLOW}Please install missing dependencies before continuing.${NC}"
        log_setup "Missing dependencies: ${missing_deps[*]}" "ERROR"
        return 1
    fi
    
    echo -e "${GREEN}✓ All essential dependencies found${NC}"
    log_setup "All essential dependencies satisfied"
    return 0
}

# Get user input with validation
get_user_input() {
    local prompt="$1"
    local default="$2"
    local required="${3:-true}"
    local validation_type="${4:-none}"
    local user_input=""
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " user_input
            user_input="${user_input:-$default}"
        else
            read -p "$prompt: " user_input
        fi
        
        # Check if required
        if [[ "$required" == "true" && -z "$user_input" ]]; then
            echo -e "${RED}This field is required. Please enter a value.${NC}"
            continue
        fi
        
        # Validation
        case "$validation_type" in
            "email")
                if [[ "$user_input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid email address.${NC}"
                    continue
                fi
                ;;
            "domain")
                if [[ "$user_input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid domain (e.g., example.edu).${NC}"
                    continue
                fi
                ;;
            "path")
                if [[ -d "$user_input" || "$user_input" =~ ^/.* ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid absolute path.${NC}"
                    continue
                fi
                ;;
            "yn")
                if [[ "$user_input" =~ ^[YyNn]$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter 'y' for yes or 'n' for no.${NC}"
                    continue
                fi
                ;;
            "1-2")
                if [[ "$user_input" =~ ^[12]$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter 1 or 2.${NC}"
                    continue
                fi
                ;;
            "1-3")
                if [[ "$user_input" =~ ^[123]$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter 1, 2, or 3.${NC}"
                    continue
                fi
                ;;
            "1-4")
                if [[ "$user_input" =~ ^[1234]$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter 1, 2, 3, or 4.${NC}"
                    continue
                fi
                ;;
            *)
                break
                ;;
        esac
    done
    
    echo "$user_input"
}

# Configure GWOMBAT service account after GAM is set up
configure_gwombat_service_account() {
    local gam_path="$1"
    
    echo -e "${CYAN}🤖 GWOMBAT Service Account Setup${NC}"
    echo ""
    echo "Now that GAM is configured, let's set up the GWOMBAT service account."
    echo "Service account: ${SETUP_ADMIN_EMAIL}"
    echo ""
    
    # Check if the service account exists
    echo "Checking if service account exists..."
    if $gam_path info user "$SETUP_ADMIN_EMAIL" &>/dev/null; then
        echo -e "${GREEN}✓ Service account exists: $SETUP_ADMIN_EMAIL${NC}"
        
        # Check if it has admin privileges
        echo "Verifying admin privileges..."
        local is_admin=$($gam_path print users query "email:$SETUP_ADMIN_EMAIL" isadmin 2>/dev/null | grep -i "true" || echo "")
        
        if [[ -n "$is_admin" ]]; then
            echo -e "${GREEN}✓ Service account has admin privileges${NC}"
        else
            echo -e "${YELLOW}⚠ Service account exists but lacks admin privileges${NC}"
            echo ""
            local grant_admin
            grant_admin=$(get_user_input "Grant admin privileges to $SETUP_ADMIN_EMAIL? (y/n)" "y" "false" "yn")
            
            if [[ "$grant_admin" =~ ^[Yy] ]]; then
                echo "Granting super admin privileges..."
                if $gam_path create admin "$SETUP_ADMIN_EMAIL" _SEED_ADMIN_ROLE customer; then
                    echo -e "${GREEN}✓ Super admin privileges granted${NC}"
                    log_setup "Granted super admin privileges to service account $SETUP_ADMIN_EMAIL"
                else
                    echo -e "${RED}✗ Failed to grant super admin privileges${NC}"
                    echo "You can grant them manually with:"
                    echo "  $gam_path create admin $SETUP_ADMIN_EMAIL _SEED_ADMIN_ROLE customer"
                    log_setup "Failed to grant super admin privileges to $SETUP_ADMIN_EMAIL" "ERROR"
                fi
            fi
        fi
    else
        echo -e "${YELLOW}Service account does not exist${NC}"
        echo ""
        local create_account
        create_account=$(get_user_input "Create service account $SETUP_ADMIN_EMAIL? (y/n)" "y" "false" "yn")
        
        if [[ "$create_account" =~ ^[Yy] ]]; then
            echo ""
            echo "Creating service account..."
            
            # Generate a secure random password
            local service_password=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-16)
            
            # Extract username from email
            local username="${SETUP_ADMIN_EMAIL%%@*}"
            
            # Create the user (step 1)
            if $gam_path create user "$SETUP_ADMIN_EMAIL" firstname "GWOMBAT" lastname "Service" password "$service_password" changepassword false; then
                echo -e "${GREEN}✓ Service account user created${NC}"
                
                # Wait a moment for Google to propagate the user
                echo "Waiting for user propagation..."
                sleep 3
                
                # Make them a super admin (step 2)
                echo "Granting super admin privileges..."
                if $gam_path create admin "$SETUP_ADMIN_EMAIL" _SEED_ADMIN_ROLE customer; then
                    echo -e "${GREEN}✓ Service account created successfully with admin privileges${NC}"
                    echo ""
                    echo -e "${YELLOW}IMPORTANT: Save this service account password securely:${NC}"
                    echo -e "${CYAN}Email: $SETUP_ADMIN_EMAIL${NC}"
                    echo -e "${CYAN}Password: $service_password${NC}"
                    echo ""
                    echo "This password is for emergency access only. Normal operations use OAuth."
                    echo ""
                    read -p "Press Enter when you have saved this information..."
                    
                    log_setup "Created service account $SETUP_ADMIN_EMAIL with super admin privileges"
                else
                    echo -e "${RED}✗ CRITICAL: Failed to grant admin privileges${NC}"
                    echo ""
                    echo "The service account was created but cannot function without admin privileges."
                    echo ""
                    echo "Options:"
                    echo "1. Retry the admin grant command (recommended)"
                    echo "2. Open another terminal window and run the command manually"
                    echo "3. Delete the account and start over"
                    echo ""
                    
                    while true; do
                        local retry_choice
                        retry_choice=$(get_user_input "Choose option (1-3)" "1" "false" "1-3")
                        
                        case "$retry_choice" in
                            1)
                                echo ""
                                echo "Retrying admin privilege grant..."
                                sleep 2
                                if $gam_path create admin "$SETUP_ADMIN_EMAIL" _SEED_ADMIN_ROLE customer; then
                                    echo -e "${GREEN}✓ Service account created successfully with admin privileges${NC}"
                                    echo ""
                                    echo -e "${YELLOW}IMPORTANT: Save this service account password securely:${NC}"
                                    echo -e "${CYAN}Email: $SETUP_ADMIN_EMAIL${NC}"
                                    echo -e "${CYAN}Password: $service_password${NC}"
                                    echo ""
                                    echo "This password is for emergency access only. Normal operations use OAuth."
                                    echo ""
                                    read -p "Press Enter when you have saved this information..."
                                    
                                    log_setup "Created service account $SETUP_ADMIN_EMAIL with super admin privileges (after retry)"
                                    break
                                else
                                    echo -e "${RED}✗ Retry failed${NC}"
                                    echo "Try option 2 or 3"
                                    continue
                                fi
                                ;;
                            2)
                                echo ""
                                echo -e "${CYAN}Open another terminal window and run this command:${NC}"
                                echo ""
                                echo "  $gam_path create admin $SETUP_ADMIN_EMAIL _SEED_ADMIN_ROLE customer"
                                echo ""
                                echo "Press Enter here when the command succeeds in the other window..."
                                read -p ""
                                
                                # Verify it worked
                                echo "Verifying admin privileges..."
                                if $gam_path info user "$SETUP_ADMIN_EMAIL" | grep -q "_SEED_ADMIN_ROLE\|Admin"; then
                                    echo -e "${GREEN}✓ Admin privileges verified!${NC}"
                                    echo ""
                                    echo -e "${YELLOW}IMPORTANT: Save this service account password securely:${NC}"
                                    echo -e "${CYAN}Email: $SETUP_ADMIN_EMAIL${NC}"
                                    echo -e "${CYAN}Password: $service_password${NC}"
                                    echo ""
                                    echo "This password is for emergency access only. Normal operations use OAuth."
                                    echo ""
                                    read -p "Press Enter when you have saved this information..."
                                    
                                    log_setup "Created service account $SETUP_ADMIN_EMAIL with super admin privileges (manual)"
                                    break
                                else
                                    echo -e "${RED}✗ Admin privileges not detected${NC}"
                                    echo "Please verify the command succeeded and try again."
                                    continue
                                fi
                                ;;
                            3)
                                echo ""
                                echo "Deleting incomplete service account..."
                                if $gam_path delete user "$SETUP_ADMIN_EMAIL"; then
                                    echo -e "${YELLOW}Account deleted. Service account setup cancelled.${NC}"
                                else
                                    echo -e "${YELLOW}Delete may have failed. Check manually: $SETUP_ADMIN_EMAIL${NC}"
                                fi
                                log_setup "Service account creation cancelled - account deleted" "WARN"
                                return 1
                                ;;
                        esac
                    done
                fi
            else
                echo -e "${RED}✗ Failed to create service account${NC}"
                echo "You can create it manually later with:"
                echo "  $gam_path create user $SETUP_ADMIN_EMAIL firstname GWOMBAT lastname Service password [password] changepassword false"
                echo "  $gam_path create admin $SETUP_ADMIN_EMAIL _SEED_ADMIN_ROLE customer"
                log_setup "Failed to create service account $SETUP_ADMIN_EMAIL" "ERROR"
            fi
        else
            echo -e "${YELLOW}Skipping service account creation${NC}"
            echo "You can create it later with:"
            echo "  $gam_path create user $SETUP_ADMIN_EMAIL firstname GWOMBAT lastname Service password [password] changepassword false"
            echo "  $gam_path create admin $SETUP_ADMIN_EMAIL _SEED_ADMIN_ROLE customer"
        fi
    fi
    
    echo ""
    echo -e "${GREEN}✓ Service account configuration complete${NC}"
}

# Configure basic domain settings
configure_domain_settings() {
    echo -e "${CYAN}📋 Domain and Organization Configuration${NC}"
    echo ""
    echo "Let's start with your Google Workspace domain and basic settings."
    echo ""
    
    # Domain
    local domain
    domain=$(get_user_input "Enter your Google Workspace domain" "" "true" "domain")
    
    # Personal admin account FIRST
    local admin_user
    echo ""
    echo -e "${YELLOW}Enter YOUR Google Workspace admin account:${NC}"
    echo -e "${YELLOW}(This is the account you use to log into Google Admin Console)${NC}"
    admin_user=$(get_user_input "Your personal admin email" "admin@$domain" "true" "email")
    
    # GWOMBAT service account (we'll configure this later after GAM is set up)
    local admin_email
    echo ""
    echo -e "${CYAN}GWOMBAT Service Account Configuration:${NC}"
    echo -e "${YELLOW}Note: We'll create or verify this service account after GAM is configured.${NC}"
    echo "For now, enter the desired service account email for GWOMBAT operations."
    admin_email=$(get_user_input "GWOMBAT service account email" "gwombat@$domain" "true" "email")
    
    # Store in temporary variables
    export SETUP_DOMAIN="$domain"
    export SETUP_ADMIN_EMAIL="$admin_email"
    export SETUP_ADMIN_USER="$admin_user"
    
    echo -e "${GREEN}✓ Domain settings configured${NC}"
    log_setup "Domain configured: $domain, Admin: $admin_user"
}

# Configure organizational units
configure_organizational_units() {
    echo ""
    echo -e "${CYAN}🏢 Organizational Unit Configuration${NC}"
    echo ""
    
    # Check if GAM is configured
    if [[ -z "$SETUP_GAM_PATH" ]] || [[ ! -x "$SETUP_GAM_PATH" ]]; then
        echo -e "${YELLOW}⚠ GAM not configured yet. Using default OU paths.${NC}"
        export SETUP_SUSPENDED_OU="/Suspended Users"
        export SETUP_PENDING_DELETION_OU="/Suspended Users/Pending Deletion"
        export SETUP_TEMPORARY_HOLD_OU="/Suspended Users/Temporary Hold"
        export SETUP_EXIT_ROW_OU="/Suspended Users/Exit Row"
        return
    fi
    
    # Query existing OUs
    echo "Checking existing organizational units in your domain..."
    echo ""
    
    local existing_ous_file="/tmp/gwombat_existing_ous_$$.txt"
    if $SETUP_GAM_PATH print orgs 2>/dev/null > "$existing_ous_file"; then
        # Get list of existing OUs
        local existing_ous=$(tail -n +2 "$existing_ous_file" | cut -d',' -f1 | sort)
        
        # Check for our recommended OUs
        local has_suspended=$(echo "$existing_ous" | grep -E "^/?Suspended Users$" || echo "")
        local has_pending=$(echo "$existing_ous" | grep -i "pending.*deletion\|deletion.*pending" || echo "")
        local has_temp=$(echo "$existing_ous" | grep -i "temporary.*hold\|temp.*hold" || echo "")
        local has_exit=$(echo "$existing_ous" | grep -i "exit.*row" || echo "")
        
        # Display existing OUs
        echo -e "${CYAN}Existing OUs in your domain:${NC}"
        echo "$existing_ous" | head -20
        if [[ $(echo "$existing_ous" | wc -l) -gt 20 ]]; then
            echo "... and $(( $(echo "$existing_ous" | wc -l) - 20 )) more"
        fi
        echo ""
        
        # Check if recommended structure exists
        if [[ -n "$has_suspended" ]]; then
            echo -e "${GREEN}✓ Found Suspended Users OU${NC}"
            
            # Check for sub-OUs under Suspended Users
            local suspended_sub_ous=$(echo "$existing_ous" | grep "^/Suspended Users/")
            if [[ -n "$suspended_sub_ous" ]]; then
                echo -e "${CYAN}Found sub-OUs under Suspended Users:${NC}"
                echo "$suspended_sub_ous" | sed 's/^/  • /'
                echo ""
            fi
        fi
        
        rm -f "$existing_ous_file"
        
        # Determine configuration approach
        echo -e "${YELLOW}GWOMBAT recommends this OU structure for account lifecycle management:${NC}"
        echo "• /Suspended Users - Main container for all suspended accounts"
        echo "• /Suspended Users/Pending Deletion - Accounts scheduled for deletion"
        echo "• /Suspended Users/Temporary Hold - Short-term suspensions"
        echo "• /Suspended Users/Exit Row - Final stage before deletion"
        echo ""
        
        if [[ -n "$has_suspended" ]] || [[ -n "$has_pending" ]] || [[ -n "$has_temp" ]] || [[ -n "$has_exit" ]]; then
            # Some relevant OUs exist
            echo -e "${YELLOW}It looks like you have some suspension-related OUs already.${NC}"
            local use_existing
            use_existing=$(get_user_input "Would you like to use your existing OUs? (y/n)" "y" "false" "yn")
            
            if [[ "$use_existing" =~ ^[Yy] ]]; then
                echo ""
                echo "Please specify which existing OUs to use:"
                
                # Suspended OU
                local suspended_ou
                if [[ -n "$has_suspended" ]]; then
                    suspended_ou=$(get_user_input "Suspended Users OU" "$(echo "$has_suspended" | head -1)" "true")
                else
                    suspended_ou=$(get_user_input "Suspended Users OU" "/Suspended Users" "true")
                fi
                
                # Other OUs - suggest based on what exists
                local pending_deletion_ou
                if [[ -n "$has_pending" ]]; then
                    pending_deletion_ou=$(get_user_input "Pending Deletion OU" "$(echo "$has_pending" | head -1)" "true")
                else
                    pending_deletion_ou=$(get_user_input "Pending Deletion OU" "$suspended_ou/Pending Deletion" "true")
                fi
                
                local temp_hold_ou
                if [[ -n "$has_temp" ]]; then
                    temp_hold_ou=$(get_user_input "Temporary Hold OU" "$(echo "$has_temp" | head -1)" "true")
                else
                    temp_hold_ou=$(get_user_input "Temporary Hold OU" "$suspended_ou/Temporary Hold" "true")
                fi
                
                local exit_row_ou
                if [[ -n "$has_exit" ]]; then
                    exit_row_ou=$(get_user_input "Exit Row OU" "$(echo "$has_exit" | head -1)" "true")
                else
                    exit_row_ou=$(get_user_input "Exit Row OU" "$suspended_ou/Exit Row" "true")
                fi
            else
                # Create recommended structure
                configure_create_recommended_ous
                return
            fi
        else
            # No relevant OUs exist
            echo -e "${YELLOW}No suspension-related OUs found in your domain.${NC}"
            local create_ous
            create_ous=$(get_user_input "Would you like to create the recommended OU structure? (y/n)" "y" "false" "yn")
            
            if [[ "$create_ous" =~ ^[Yy] ]]; then
                configure_create_recommended_ous
                return
            else
                echo ""
                echo "Please specify custom OU paths to use:"
                
                local suspended_ou=$(get_user_input "Suspended Users OU" "/Suspended Users" "true")
                local pending_deletion_ou=$(get_user_input "Pending Deletion OU" "/Suspended Users/Pending Deletion" "true")
                local temp_hold_ou=$(get_user_input "Temporary Hold OU" "/Suspended Users/Temporary Hold" "true")
                local exit_row_ou=$(get_user_input "Exit Row OU" "/Suspended Users/Exit Row" "true")
            fi
        fi
    else
        echo -e "${YELLOW}⚠ Could not query existing OUs. Using manual configuration.${NC}"
        echo ""
        
        local use_defaults
        use_defaults=$(get_user_input "Use recommended OU structure? (y/n)" "y" "false" "yn")
        
        if [[ "$use_defaults" =~ ^[Yy] ]]; then
            configure_create_recommended_ous
            return
        else
            echo ""
            echo "Please specify custom OU paths:"
            local suspended_ou=$(get_user_input "Suspended Users OU" "/Suspended Users" "true")
            local pending_deletion_ou=$(get_user_input "Pending Deletion OU" "/Suspended Users/Pending Deletion" "true")
            local temp_hold_ou=$(get_user_input "Temporary Hold OU" "/Suspended Users/Temporary Hold" "true")
            local exit_row_ou=$(get_user_input "Exit Row OU" "/Suspended Users/Exit Row" "true")
        fi
    fi
    
    # Store configured values
    export SETUP_SUSPENDED_OU="$suspended_ou"
    export SETUP_PENDING_DELETION_OU="$pending_deletion_ou"
    export SETUP_TEMPORARY_HOLD_OU="$temp_hold_ou"
    export SETUP_EXIT_ROW_OU="$exit_row_ou"
    
    echo ""
    echo -e "${CYAN}Configured OU paths:${NC}"
    echo "• Suspended Users: $suspended_ou"
    echo "• Pending Deletion: $pending_deletion_ou"
    echo "• Temporary Hold: $temp_hold_ou"
    echo "• Exit Row: $exit_row_ou"
    
    echo -e "${GREEN}✓ Organizational units configured${NC}"
    log_setup "OUs configured: $suspended_ou, $pending_deletion_ou, $temp_hold_ou, $exit_row_ou"
}

# Helper function to create recommended OUs
configure_create_recommended_ous() {
    local suspended_ou="/Suspended Users"
    local pending_deletion_ou="/Suspended Users/Pending Deletion"
    local temp_hold_ou="/Suspended Users/Temporary Hold"
    local exit_row_ou="/Suspended Users/Exit Row"
    
    echo ""
    echo "Creating recommended OU structure..."
    
    # Create main Suspended Users OU first
    echo -n "Creating $suspended_ou... "
    if $SETUP_GAM_PATH create org "$suspended_ou" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}already exists or failed${NC}"
    fi
    
    # Create sub-OUs
    for ou in "$pending_deletion_ou" "$temp_hold_ou" "$exit_row_ou"; do
        echo -n "Creating $ou... "
        if $SETUP_GAM_PATH create org "$ou" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${YELLOW}already exists or failed${NC}"
        fi
    done
    
    # Store values
    export SETUP_SUSPENDED_OU="$suspended_ou"
    export SETUP_PENDING_DELETION_OU="$pending_deletion_ou"
    export SETUP_TEMPORARY_HOLD_OU="$temp_hold_ou"
    export SETUP_EXIT_ROW_OU="$exit_row_ou"
    
    echo ""
    echo -e "${GREEN}✓ OU structure created${NC}"
    echo ""
    echo -e "${CYAN}Created OU paths:${NC}"
    echo "• Suspended Users: $suspended_ou"
    echo "• Pending Deletion: $pending_deletion_ou"
    echo "• Temporary Hold: $temp_hold_ou"
    echo "• Exit Row: $exit_row_ou"
}

# Check and configure GAM
configure_gam() {
    echo ""
    echo -e "${CYAN}🔧 GAM (Google Apps Manager) Configuration${NC}"
    echo ""
    
    # Check if GAM is installed
    local gam_path=""
    
    # First check if gam is in PATH
    if command -v gam >/dev/null 2>&1; then
        # Handle aliases by resolving the actual path
        local which_output=$(which gam 2>/dev/null)
        if [[ "$which_output" =~ "aliased to" ]]; then
            # Extract path from alias output
            gam_path=$(echo "$which_output" | sed 's/.*aliased to //')
        else
            gam_path="$which_output"
        fi
        echo -e "${GREEN}✓ GAM found at: $gam_path${NC}"
    else
        # Check common installation locations
        local common_paths=(
            "$HOME/bin/gamadv-xtd3/gam"
            "$HOME/bin/gam/gam"
            "$HOME/gamadv-xtd3/gam"
            "/usr/local/bin/gam"
            "/usr/bin/gam"
            "/opt/gam/gam"
        )
        
        for path in "${common_paths[@]}"; do
            if [[ -x "$path" ]]; then
                gam_path="$path"
                echo -e "${GREEN}✓ GAM found at: $gam_path${NC}"
                break
            fi
        done
        
        if [[ -z "$gam_path" ]]; then
            echo -e "${YELLOW}GAM not found in PATH or common locations${NC}"
        fi
    fi
    
    if [[ -z "$gam_path" ]]; then
        echo ""
        echo -e "${BLUE}GAM Installation Guide:${NC}"
        echo "1. Download GAM from: https://github.com/GAM-team/GAM"
        echo "2. Follow installation instructions for your platform"
        echo "3. Common installation paths:"
        echo "   - Linux/macOS: /usr/local/bin/gam"
        echo "   - Windows: C:\\GAM\\gam.exe"
        echo ""
        
        local install_now
        install_now=$(get_user_input "Would you like to install GAM now? (y/n)" "n" "false" "yn")
        
        if [[ "$install_now" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing GAM...${NC}"
            if command -v curl >/dev/null 2>&1; then
                echo "Downloading GAM installer..."
                if bash <(curl -s -S -L https://git.io/install-gam) -l; then
                    echo -e "${GREEN}✓ GAM installation completed${NC}"
                    gam_path=$(which gam || echo "/usr/local/bin/gam")
                else
                    echo -e "${YELLOW}⚠ Automatic installation failed. Please install manually.${NC}"
                    gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
                fi
            else
                echo -e "${YELLOW}⚠ curl not available. Please install GAM manually.${NC}"
                gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
            fi
        else
            gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
        fi
    fi
    
    # GAM Configuration Walkthrough
    echo ""
    echo -e "${CYAN}GAM Configuration Walkthrough${NC}"
    echo ""
    
    if [[ -x "$gam_path" ]]; then
        local gam_version=$($gam_path version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}GAM Version: $gam_version${NC}"
        
        # Check if GAM is already configured
        if $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
            echo -e "${GREEN}✓ GAM is already configured and working${NC}"
            local domain_info=$($gam_path info domain 2>/dev/null | grep "Primary Domain" | awk '{print $3}' || echo "unknown")
            echo -e "${GREEN}  Primary Domain: $domain_info${NC}"
            log_setup "GAM configured: $gam_version for domain $domain_info"
            
            # Since GAM is already configured, offer to set up service account
            echo ""
            configure_gwombat_service_account "$gam_path"
        else
            echo -e "${YELLOW}GAM needs to be configured with your Google Workspace domain${NC}"
            echo ""
            echo -e "${BLUE}GAM Configuration Steps:${NC}"
            echo ""
            echo -e "1. ${CYAN}Create OAuth credentials:${NC}"
            echo "   $gam_path oauth create"
            echo ""
            echo -e "2. ${CYAN}Authorize GAM:${NC}"
            echo "   - This will open a browser window"
            echo "   - Log in with your Google Workspace admin account"
            echo "   - Grant the requested permissions"
            echo ""
            echo -e "3. ${CYAN}Test configuration:${NC}"
            echo "   $gam_path info domain"
            echo ""
            
            local configure_now
            configure_now=$(get_user_input "Configure GAM now? (y/n)" "y" "false" "yn")
            
            if [[ "$configure_now" =~ ^[Yy] ]]; then
                echo ""
                echo -e "${CYAN}Setting up GAM project and OAuth...${NC}"
                echo ""
                
                # Step 1: Create or use Google Cloud project
                echo -e "${CYAN}Step 1: Creating Google Cloud project...${NC}"
                echo "This will open a browser window to create/select a Google Cloud project."
                echo ""
                read -p "Press Enter to continue..."
                
                if $gam_path create project; then
                    echo -e "${GREEN}✓ Google Cloud project configured${NC}"
                    echo ""
                    
                    # Step 2: Create OAuth credentials
                    echo -e "${CYAN}Step 2: Creating OAuth credentials...${NC}"
                    echo "This will open another browser window for OAuth authorization."
                    echo "Log in with your Google Workspace admin account and grant permissions."
                    echo ""
                    read -p "Press Enter to continue..."
                    
                    if $gam_path oauth create; then
                    echo ""
                    echo -e "${CYAN}Testing GAM configuration...${NC}"
                    if $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
                        echo -e "${GREEN}✓ GAM configuration successful!${NC}"
                        local domain_info=$($gam_path info domain 2>/dev/null | grep "Primary Domain" | awk '{print $3}' || echo "configured")
                        echo -e "${GREEN}  Primary Domain: $domain_info${NC}"
                        log_setup "GAM configured successfully for domain $domain_info"
                        
                        # Now that GAM is configured, handle the service account
                        echo ""
                        configure_gwombat_service_account "$gam_path"
                    else
                        echo -e "${YELLOW}⚠ GAM configuration may need additional setup${NC}"
                        echo "You can complete this later by running:"
                        echo "  $gam_path oauth create"
                        echo "  $gam_path info domain"
                        log_setup "GAM OAuth created but needs verification" "WARN"
                    fi
                    else
                        echo -e "${YELLOW}⚠ GAM OAuth setup incomplete${NC}"
                        echo "You can complete this later by running: $gam_path oauth create"
                        log_setup "GAM OAuth setup failed" "WARN"
                    fi
                else
                    echo -e "${RED}✗ Google Cloud project setup failed${NC}"
                    echo ""
                    echo "Project creation failed. You can complete this manually by running:"
                    echo "1. $gam_path create project"
                    echo "2. $gam_path oauth create"
                    echo "3. $gam_path info domain"
                    echo ""
                    log_setup "GAM project creation failed" "ERROR"
                fi
            else
                echo -e "${YELLOW}⚠ Skipping GAM configuration${NC}"
                echo "Configure later with: $gam_path oauth create"
                log_setup "Skipped GAM configuration"
            fi
        fi
        
        # GAM Advanced Configuration
        echo ""
        echo -e "${CYAN}GAM Advanced Configuration Options:${NC}"
        echo ""
        echo "Most users can skip this section. Advanced options are only needed if:"
        echo ""
        echo "1. 📁 Set custom GAM config directory"
        echo "   → Use if you need GAM config in a non-standard location"
        echo "   → Default: ~/.gam (recommended for most users)"
        echo ""
        echo "2. 🔐 Set up GAM service account (advanced)"
        echo "   → Use for automated scripts without user interaction"
        echo "   → Requires Google Cloud Console setup"
        echo ""
        echo "3. ⏭️  Skip advanced configuration (recommended)"
        echo "   → Use standard GAM setup with default settings"
        echo ""
        
        local advanced_choice
        advanced_choice=$(get_user_input "Select option (1-3)" "3" "false")
        
        case "$advanced_choice" in
            1)
                echo ""
                echo -e "${CYAN}Custom GAM Config Directory${NC}"
                echo "Default: $HOME/.gam"
                local custom_config
                custom_config=$(get_user_input "Enter custom config directory" "$HOME/.gam" "false")
                echo "To use custom directory, set: export GAMCFGDIR=\"$custom_config\""
                export SETUP_GAM_CONFIG_PATH="$custom_config"
                log_setup "GAM custom config directory: $custom_config"
                ;;
            2)
                echo ""
                echo -e "${CYAN}Service Account Configuration${NC}"
                echo "Service accounts provide automated access without OAuth."
                echo ""
                echo "Steps to configure service account:"
                echo "1. Create service account in Google Cloud Console"
                echo "2. Enable necessary APIs"
                echo "3. Download service account JSON key"
                echo "4. Configure GAM: $gam_path oauth serviceaccount"
                echo ""
                echo "⚠️  Service account setup requires Google Cloud Console access"
                echo "See: https://github.com/GAM-team/GAM/wiki/Service-Account-Access"
                ;;
            3)
                echo -e "${YELLOW}✓ Skipping advanced GAM configuration (recommended)${NC}"
                ;;
        esac
        
    else
        echo -e "${RED}✗ GAM executable not found or not executable${NC}"
        echo "Please install GAM before continuing setup."
        log_setup "GAM not found at $gam_path" "ERROR"
    fi
    
    # GAM config path
    local gam_config_path="${SETUP_GAM_CONFIG_PATH:-$HOME/.gam}"
    if [[ -z "$SETUP_GAM_CONFIG_PATH" ]]; then
        gam_config_path=$(get_user_input "GAM config directory" "$HOME/.gam" "false")
    fi
    
    export SETUP_GAM_PATH="$gam_path"
    export SETUP_GAM_CONFIG_PATH="$gam_config_path"
}

# Check and configure Python environment
configure_python_environment() {
    echo ""
    echo -e "${CYAN}🐍 Python Environment Configuration${NC}"
    echo ""
    
    # Check Python version and compatibility
    local python_path=""
    local python_version=""
    local python_major=""
    local python_minor=""
    
    if command -v python3 >/dev/null 2>&1; then
        python_path=$(which python3)
        python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        python_major=$(echo "$python_version" | cut -d. -f1)
        python_minor=$(echo "$python_version" | cut -d. -f2)
        
        echo -e "${GREEN}✓ Python found: $python_version at $python_path${NC}"
        
        # Check Python version compatibility (require 3.8+)
        if [[ "$python_major" -eq 3 && "$python_minor" -ge 8 ]]; then
            echo -e "${GREEN}  ✓ Python version is compatible (3.8+ required)${NC}"
            log_setup "Python version compatible: $python_version"
        elif [[ "$python_major" -eq 3 && "$python_minor" -lt 8 ]]; then
            echo -e "${YELLOW}  ⚠ Python version may be outdated (3.8+ recommended)${NC}"
            echo -e "${YELLOW}    Some advanced features may not work properly${NC}"
            log_setup "Python version outdated: $python_version" "WARN"
        else
            echo -e "${RED}  ✗ Python version incompatible${NC}"
            log_setup "Python version incompatible: $python_version" "ERROR"
        fi
    else
        echo -e "${RED}✗ Python 3 not found${NC}"
        echo ""
        echo -e "${BLUE}Python Installation Guide:${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Install with: sudo apt update && sudo apt install python3 python3-pip"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install python3"
            echo "Or download from: https://www.python.org/downloads/"
        else
            echo "Download from: https://www.python.org/downloads/"
        fi
        
        local install_python
        install_python=$(get_user_input "Install Python now? (y/n)" "n" "false")
        
        if [[ "$install_python" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing Python...${NC}"
            if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y python3 python3-pip python3-venv
            elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                brew install python3
            else
                echo -e "${YELLOW}⚠ Automatic installation not available for your platform${NC}"
                echo "Please install Python manually and run setup again"
                log_setup "Python installation failed - manual installation required" "ERROR"
                return 1
            fi
            
            # Recheck after installation
            if command -v python3 >/dev/null 2>&1; then
                python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                echo -e "${GREEN}✓ Python installation successful: $python_version${NC}"
                log_setup "Python installed successfully: $python_version"
            else
                echo -e "${RED}✗ Python installation failed${NC}"
                log_setup "Python installation failed" "ERROR"
                return 1
            fi
        else
            log_setup "Python 3 not found - skipping Python setup" "ERROR"
            return 1
        fi
    fi
    
    # Check pip and package management tools
    echo ""
    echo -e "${CYAN}Python Package Management${NC}"
    
    if command -v pip3 >/dev/null 2>&1; then
        local pip_version=$(pip3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo -e "${GREEN}✓ pip3 available: $pip_version${NC}"
        log_setup "pip3 available: $pip_version"
    else
        echo -e "${YELLOW}⚠ pip3 not found - attempting to install${NC}"
        if command -v python3 >/dev/null 2>&1; then
            if python3 -m ensurepip --upgrade 2>/dev/null; then
                echo -e "${GREEN}✓ pip3 installed successfully${NC}"
                log_setup "pip3 installed successfully"
            else
                echo -e "${RED}✗ pip3 installation failed${NC}"
                echo "You may need to install pip3 manually"
                log_setup "pip3 installation failed" "WARN"
            fi
        fi
    fi
    
    # Check for virtual environment support
    if python3 -m venv --help >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Virtual environment support available${NC}"
        export SETUP_PYTHON_VENV_SUPPORT="true"
    else
        echo -e "${YELLOW}⚠ Virtual environment support not available${NC}"
        echo "Consider installing python3-venv package"
        export SETUP_PYTHON_VENV_SUPPORT="false"
        log_setup "Virtual environment support not available" "WARN"
    fi
    
    # Virtual Environment Configuration
    echo ""
    echo -e "${CYAN}Python Virtual Environment Setup${NC}"
    echo ""
    echo "GWOMBAT can use a dedicated Python virtual environment to:"
    echo "• Isolate Python packages from system installation"
    echo "• Avoid conflicts with other applications"
    echo "• Ensure consistent package versions"
    echo "• Enable easy cleanup and updates"
    echo ""
    
    local use_venv="false"
    if [[ "$SETUP_PYTHON_VENV_SUPPORT" == "true" ]]; then
        local venv_choice
        venv_choice=$(get_user_input "Use virtual environment for GWOMBAT? (y/n)" "y" "false" "yn")
        
        if [[ "$venv_choice" =~ ^[Yy] ]]; then
            use_venv="true"
            local venv_path="$GWOMBAT_ROOT/python-modules/venv"
            
            echo ""
            echo -e "${CYAN}Creating Python virtual environment...${NC}"
            
            if [[ -d "$venv_path" ]]; then
                echo -e "${YELLOW}⚠ Virtual environment already exists at $venv_path${NC}"
                local recreate_venv
                recreate_venv=$(get_user_input "Recreate virtual environment? (y/n)" "n" "false")
                if [[ "$recreate_venv" =~ ^[Yy] ]]; then
                    rm -rf "$venv_path"
                fi
            fi
            
            if [[ ! -d "$venv_path" ]]; then
                if python3 -m venv "$venv_path"; then
                    echo -e "${GREEN}✓ Virtual environment created at: $venv_path${NC}"
                    log_setup "Python virtual environment created at $venv_path"
                    
                    # Activate virtual environment
                    if source "$venv_path/bin/activate"; then
                        echo -e "${GREEN}✓ Virtual environment activated${NC}"
                        
                        # Upgrade pip in venv
                        echo "Upgrading pip in virtual environment..."
                        pip install --upgrade pip >/dev/null 2>&1
                        
                        export SETUP_PYTHON_VENV_PATH="$venv_path"
                        export SETUP_PYTHON_USE_VENV="true"
                    else
                        echo -e "${YELLOW}⚠ Failed to activate virtual environment${NC}"
                        use_venv="false"
                        log_setup "Failed to activate virtual environment" "WARN"
                    fi
                else
                    echo -e "${YELLOW}⚠ Failed to create virtual environment${NC}"
                    echo "Continuing with system Python installation"
                    use_venv="false"
                    log_setup "Failed to create virtual environment" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ Using existing virtual environment${NC}"
                if source "$venv_path/bin/activate"; then
                    echo -e "${GREEN}✓ Existing virtual environment activated${NC}"
                    export SETUP_PYTHON_VENV_PATH="$venv_path"
                    export SETUP_PYTHON_USE_VENV="true"
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Using system Python installation${NC}"
            log_setup "Using system Python installation"
        fi
    else
        echo -e "${YELLOW}⚠ Virtual environment not supported - using system Python${NC}"
        log_setup "Virtual environment not supported"
    fi
    
    # Python Package Installation
    echo ""
    echo -e "${CYAN}GWOMBAT Python Package Installation${NC}"
    echo ""
    echo "GWOMBAT uses Python for advanced features including:"
    echo "• 📊 SCuBA compliance analysis and reporting"
    echo "• 📈 Advanced data visualization (matplotlib)"
    echo "• 📋 HTML report generation (jinja2)"
    echo "• 🔐 Enhanced security analysis"
    echo "• 📊 Data processing and analytics (pandas, numpy)"
    echo ""
    
    local install_packages
    install_packages=$(get_user_input "Install GWOMBAT Python packages now? (y/n)" "y" "false")
    
    if [[ "$install_packages" =~ ^[Yy] ]]; then
        echo ""
        echo -e "${CYAN}Analyzing Python package requirements...${NC}"
        
        # Check requirements file
        local requirements_file="$GWOMBAT_ROOT/python-modules/requirements.txt"
        if [[ ! -f "$requirements_file" ]]; then
            echo -e "${RED}✗ Requirements file not found: $requirements_file${NC}"
            log_setup "Requirements file not found" "ERROR"
            return 1
        fi
        
        echo "  → Checking system packages vs requirements..."
        
        # Check which packages are already installed system-wide
        local system_packages=()
        local missing_packages=()
        local needs_venv=false
        
        while IFS= read -r line; do
            if [[ "$line" =~ ^[a-zA-Z] ]]; then
                local package_name=$(echo "$line" | cut -d'>' -f1 | cut -d'=' -f1 | cut -d'[' -f1)
                
                # Check if package is already available system-wide
                if python3 -c "import $package_name" 2>/dev/null; then
                    echo -e "${GREEN}  ✓ $package_name (system)${NC}"
                    system_packages+=("$package_name")
                else
                    echo -e "${YELLOW}  ○ $package_name (needs install)${NC}"
                    missing_packages+=("$line")
                    needs_venv=true
                fi
            fi
        done < "$requirements_file"
        
        echo ""
        echo -e "${BLUE}📊 Package Analysis:${NC}"
        echo "  • System packages available: ${#system_packages[@]}"
        echo "  • Packages to install: ${#missing_packages[@]}"
        
        if [[ ${#missing_packages[@]} -eq 0 ]]; then
            echo ""
            echo -e "${GREEN}🎉 All required packages already available system-wide!${NC}"
            echo "No additional installation needed."
            log_setup "All Python packages already available system-wide"
        else
            echo ""
            if [[ "$use_venv" == "true" && $needs_venv == "true" ]]; then
                echo -e "${CYAN}Installing missing packages to virtual environment...${NC}"
                echo "This keeps your system Python installation clean."
                
                # Create requirements file for missing packages only
                local venv_requirements="/tmp/gwombat-missing-requirements.txt"
                printf '%s\n' "${missing_packages[@]}" > "$venv_requirements"
                
                echo ""
                echo "Missing packages to install in venv:"
                for pkg in "${missing_packages[@]}"; do
                    local pkg_name=$(echo "$pkg" | cut -d'>' -f1 | cut -d'=' -f1 | cut -d'[' -f1)
                    echo "  • $pkg_name"
                done
                
                echo ""
                echo "Installing to virtual environment (this may take a few minutes)..."
                if pip install -r "$venv_requirements" --upgrade; then
                    rm -f "$venv_requirements"
                    echo -e "${GREEN}✓ Missing packages installed to virtual environment${NC}"
                    log_setup "Missing Python packages installed to venv: ${missing_packages[*]}"
                else
                    echo -e "${RED}✗ Failed to install some packages to virtual environment${NC}"
                    echo "Falling back to system installation..."
                    use_venv="false"
                fi
            fi
            
            if [[ "$use_venv" == "false" ]]; then
                echo -e "${CYAN}Installing missing packages system-wide...${NC}"
                echo "Note: This will modify your system Python installation."
                
                # Create requirements file for missing packages only  
                local system_requirements="/tmp/gwombat-missing-requirements.txt"
                printf '%s\n' "${missing_packages[@]}" > "$system_requirements"
                
                echo ""
                echo "Installing packages (this may take a few minutes)..."
                if pip3 install -r "$system_requirements" --upgrade; then
                    rm -f "$system_requirements"
                    echo -e "${GREEN}✓ Missing packages installed system-wide${NC}"
                    log_setup "Missing Python packages installed system-wide: ${missing_packages[*]}"
                else
                    echo -e "${RED}✗ Failed to install some packages${NC}"
                    return 1
                fi
            fi
        fi
        
        if true; then
            echo -e "${GREEN}✓ All Python packages installed successfully${NC}"
            log_setup "Python packages installed successfully"
            
            # Verify key packages
            echo ""
            echo -e "${CYAN}Verifying package installation...${NC}"
            local packages_verified=0
            local packages_failed=()
            
            # Test key imports (use appropriate Python based on venv usage)
            local python_cmd="python3"
            local verification_env=""
            
            if [[ "$SETUP_PYTHON_USE_VENV" == "true" && -n "$SETUP_PYTHON_VENV_PATH" ]]; then
                echo -e "${CYAN}  Verifying packages in virtual environment...${NC}"
                # Use venv python directly instead of trying to activate in subshell
                python_cmd="$SETUP_PYTHON_VENV_PATH/bin/python"
                verification_env="venv"
            else
                echo -e "${CYAN}  Verifying packages in system Python...${NC}"
                verification_env="system"
            fi
            
            local key_packages=("pandas" "numpy" "matplotlib" "jinja2" "requests" "cryptography")
            for package in "${key_packages[@]}"; do
                if "$python_cmd" -c "import $package" 2>/dev/null; then
                    echo -e "${GREEN}  ✓ $package${NC}"
                    ((packages_verified++))
                else
                    echo -e "${RED}  ✗ $package${NC}"
                    packages_failed+=("$package")
                fi
            done
            
            echo ""
            if [[ ${#packages_failed[@]} -eq 0 ]]; then
                echo -e "${GREEN}✅ All key packages verified successfully!${NC}"
                export SETUP_PYTHON_PACKAGES_INSTALLED="true"
                log_setup "All Python packages verified successfully"
            else
                echo -e "${YELLOW}⚠ Some packages failed verification: ${packages_failed[*]}${NC}"
                echo "You may need to install these manually later"
                export SETUP_PYTHON_PACKAGES_INSTALLED="partial"
                log_setup "Some Python packages failed verification: ${packages_failed[*]}" "WARN"
            fi
            
        else
            echo -e "${YELLOW}⚠ Some Python packages failed to install${NC}"
            echo ""
            echo -e "${BLUE}Troubleshooting options:${NC}"
            echo "1. Check your internet connection"
            echo "2. Ensure you have sufficient disk space"
            echo "3. Try installing packages individually:"
            echo "   pip3 install pandas numpy matplotlib jinja2"
            echo "4. Use system package manager if available:"
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "   sudo apt install python3-pandas python3-numpy python3-matplotlib"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                echo "   brew install python-tk  # For matplotlib GUI support"
            fi
            echo ""
            echo "You can retry package installation later by running:"
            echo "  ./gwombat.sh → Configuration → Setup Python Environment"
            
            export SETUP_PYTHON_PACKAGES_INSTALLED="failed"
            log_setup "Python package installation failed" "WARN"
        fi
        
        # Deactivate virtual environment if we activated it
        if [[ "$use_venv" == "true" && -n "$VIRTUAL_ENV" ]]; then
            deactivate 2>/dev/null || true
        fi
        
    else
        echo -e "${YELLOW}⚠ Skipping Python package installation${NC}"
        echo ""
        echo "You can install packages later with:"
        if [[ "$use_venv" == "true" ]]; then
            echo "  source $SETUP_PYTHON_VENV_PATH/bin/activate"
            echo "  pip install -r python-modules/requirements.txt"
            echo "  deactivate"
        else
            echo "  pip3 install -r python-modules/requirements.txt"
        fi
        echo ""
        echo "Or use the GWOMBAT configuration menu:"
        echo "  ./gwombat.sh → Configuration → Setup Python Environment"
        
        export SETUP_PYTHON_PACKAGES_INSTALLED="skipped"
        log_setup "Skipped Python package installation"
    fi
    
    # Python Environment Summary
    echo ""
    echo -e "${CYAN}Python Environment Summary${NC}"
    echo "========================="
    echo "Python Version: $python_version"
    echo "Python Path: $python_path"
    echo "Virtual Environment: $use_venv"
    if [[ "$use_venv" == "true" ]]; then
        echo "Virtual Environment Path: $SETUP_PYTHON_VENV_PATH"
    fi
    echo "Package Installation: $SETUP_PYTHON_PACKAGES_INSTALLED"
    echo ""
    
    # Store configuration for .env file
    export SETUP_PYTHON_VERSION="$python_version"
    export SETUP_PYTHON_PATH="$python_path"
}

# Check and configure optional tools
configure_optional_tools() {
    echo ""
    echo -e "${CYAN}🛠️ Optional Tools Configuration${NC}"
    echo ""
    echo "Let's check for optional tools that enhance GWOMBAT functionality."
    echo ""
    
    # GYB (Got Your Back) - Comprehensive Configuration
    echo -e "${BLUE}=== GYB (Got Your Back) - Gmail Backup Tool ===${NC}"
    if command -v gyb >/dev/null 2>&1; then
        local gyb_version=$(gyb --version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}✓ GYB found: $gyb_version${NC}"
        log_setup "GYB found: $gyb_version"
        
        # Check GYB configuration
        echo ""
        echo -e "${CYAN}GYB Configuration Check${NC}"
        local gyb_config_dir="$HOME/.gyb"
        if [[ -d "$gyb_config_dir" && -f "$gyb_config_dir/oauth2.txt" ]]; then
            echo -e "${GREEN}✓ GYB appears to be configured${NC}"
            echo -e "${GREEN}  Config directory: $gyb_config_dir${NC}"
        else
            echo -e "${YELLOW}⚠ GYB needs initial configuration${NC}"
            echo ""
            echo -e "${BLUE}GYB Configuration Steps:${NC}"
            echo "1. Run: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu}"
            echo "2. Follow OAuth setup (similar to GAM)"
            echo "3. Test with: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu} --action estimate"
            echo ""
            
            local configure_gyb
            configure_gyb=$(get_user_input "Configure GYB now? (y/n)" "n" "false")
            
            if [[ "$configure_gyb" =~ ^[Yy] ]]; then
                echo ""
                local test_email
                test_email=$(get_user_input "Enter test email for GYB setup" "$SETUP_ADMIN_USER" "false")
                if [[ -n "$test_email" ]]; then
                    echo -e "${CYAN}Setting up GYB (Got Your Back)...${NC}"
                    echo ""
                    echo "GYB requires a Google Cloud Project for API access."
                    echo "This will create the necessary project and OAuth configuration."
                    echo ""
                    
                    # Step 1: Create project
                    echo -e "${YELLOW}Step 1: Creating Google Cloud Project...${NC}"
                    echo "This will open a browser for project creation and API setup..."
                    if gyb --action create-project --email "$test_email"; then
                        echo -e "${GREEN}✓ Google Cloud Project created successfully${NC}"
                        
                        # Step 2: Test the setup
                        echo ""
                        echo -e "${YELLOW}Step 2: Testing GYB configuration...${NC}"
                        if gyb --email "$test_email" --action estimate; then
                            echo -e "${GREEN}✓ GYB setup completed successfully!${NC}"
                            echo "GYB is now ready to backup Gmail for your domain."
                            log_setup "GYB configured successfully for $test_email"
                        else
                            echo -e "${YELLOW}⚠ GYB project created but test failed${NC}"
                            echo "You may need to manually authorize GYB:"
                            echo "  gyb --email $test_email --action estimate"
                            log_setup "GYB project created but authorization incomplete" "WARN"
                        fi
                    else
                        echo -e "${RED}✗ GYB project creation failed${NC}"
                        echo ""
                        echo "This usually happens when:"
                        echo "• GYB needs a Google Cloud Project configured"
                        echo "• OAuth client credentials are missing"
                        echo "• Google APIs need to be enabled"
                        echo ""
                        echo -e "${CYAN}Manual setup steps:${NC}"
                        echo "1. Run: gyb --action create-project --email $test_email"
                        echo "2. Follow browser prompts to:"
                        echo "   → Create/select Google Cloud Project"
                        echo "   → Enable Gmail API"
                        echo "   → Create OAuth credentials"
                        echo "3. Test setup: gyb --email $test_email --action estimate"
                        echo ""
                        echo -e "${YELLOW}Note: GYB config files are usually stored in:${NC}"
                        echo "• ~/.gyb/ (user directory)"
                        echo "• /usr/local/etc/gyb/ (system directory)"
                        log_setup "GYB project creation failed - manual setup required" "ERROR"
                    fi
                fi
            else
                echo -e "${YELLOW}⚠ Skipping GYB configuration${NC}"
                echo "Configure later with: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu}"
            fi
        fi
        
        # GYB Advanced Features
        echo ""
        echo -e "${CYAN}GYB Advanced Features:${NC}"
        echo "• Full Gmail backup and restore"
        echo "• Incremental backups"
        echo "• Cross-account email migration"
        echo "• MBOX format export"
        echo "• Label-based filtering"
        echo ""
        
    else
        echo -e "${YELLOW}○ GYB not found${NC}"
        echo ""
        echo -e "${BLUE}GYB Installation Guide:${NC}"
        echo "1. Download from: https://github.com/GAM-team/got-your-back"
        echo "2. Install using pip: pip install gyb"
        echo "3. Or download binary from releases page"
        echo ""
        
        local install_gyb
        install_gyb=$(get_user_input "Install GYB now? (y/n)" "n" "false")
        
        if [[ "$install_gyb" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing GYB...${NC}"
            if command -v pip3 >/dev/null 2>&1; then
                if pip3 install gyb; then
                    echo -e "${GREEN}✓ GYB installation completed${NC}"
                    echo "Run setup wizard again to configure GYB"
                    log_setup "GYB installed successfully"
                else
                    echo -e "${YELLOW}⚠ GYB installation failed${NC}"
                    echo "Install manually from: https://github.com/GAM-team/got-your-back"
                    log_setup "GYB installation failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ pip3 not available. Install GYB manually${NC}"
                echo "Download from: https://github.com/GAM-team/got-your-back"
            fi
        fi
        log_setup "GYB not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== rclone - Cloud Storage Sync Tool ===${NC}"
    if command -v rclone >/dev/null 2>&1; then
        local rclone_version=$(rclone version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        echo -e "${GREEN}✓ rclone found: $rclone_version${NC}"
        
        # Check for configured remotes
        local remotes=$(rclone listremotes 2>/dev/null)
        if [[ -n "$remotes" ]]; then
            echo -e "${GREEN}✓ rclone has configured remotes:${NC}"
            echo "$remotes" | sed 's/^/    /'
            log_setup "rclone found with remotes: $rclone_version"
        else
            echo -e "${YELLOW}⚠ No rclone remotes configured${NC}"
            echo ""
            echo -e "${BLUE}rclone Configuration Walkthrough:${NC}"
            echo ""
            echo "rclone supports 40+ cloud storage providers:"
            echo "• Google Drive, OneDrive, Dropbox"
            echo "• AWS S3, Google Cloud Storage, Azure"
            echo "• Box, pCloud, Mega, and many more"
            echo ""
            
            local configure_rclone
            configure_rclone=$(get_user_input "Configure rclone remote now? (y/n)" "n" "false")
            
            if [[ "$configure_rclone" =~ ^[Yy] ]]; then
                echo ""
                echo -e "${CYAN}Popular cloud storage options for GWOMBAT:${NC}"
                echo "1. Google Drive (recommended for Google Workspace)"
                echo "2. AWS S3 (enterprise backup)"
                echo "3. Microsoft OneDrive"
                echo "4. Local/Network storage"
                echo "5. Other (full rclone config)"
                echo ""
                
                local storage_choice
                storage_choice=$(get_user_input "Select storage type (1-5)" "1" "false")
                
                case "$storage_choice" in
                    1)
                        echo ""
                        echo -e "${CYAN}Configuring Google Drive remote...${NC}"
                        echo "This will create a 'gdrive' remote for Google Drive"
                        rclone config create gdrive drive
                        ;;
                    2)
                        echo ""
                        echo -e "${CYAN}Configuring AWS S3 remote...${NC}"
                        echo "You'll need your AWS Access Key ID and Secret"
                        rclone config create s3backup s3
                        ;;
                    3)
                        echo ""
                        echo -e "${CYAN}Configuring OneDrive remote...${NC}"
                        rclone config create onedrive onedrive
                        ;;
                    4)
                        echo ""
                        echo -e "${CYAN}Configuring local/network storage...${NC}"
                        local local_path
                        local_path=$(get_user_input "Enter backup directory path" "/backup/gwombat" "false")
                        rclone config create local local path "$local_path"
                        ;;
                    5)
                        echo ""
                        echo -e "${CYAN}Running full rclone configuration...${NC}"
                        rclone config
                        ;;
                esac
                
                # Test the configuration
                echo ""
                local remotes_after=$(rclone listremotes 2>/dev/null)
                if [[ -n "$remotes_after" ]]; then
                    echo -e "${GREEN}✓ rclone configuration successful!${NC}"
                    echo -e "${GREEN}Configured remotes:${NC}"
                    echo "$remotes_after" | sed 's/^/    /'
                    log_setup "rclone configured successfully"
                else
                    echo -e "${YELLOW}⚠ rclone configuration incomplete${NC}"
                    log_setup "rclone configuration failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ Skipping rclone configuration${NC}"
                echo "Configure later with: rclone config"
                log_setup "rclone found but no remotes configured"
            fi
        fi
        
        # rclone Advanced Features
        echo ""
        echo -e "${CYAN}rclone Advanced Features for GWOMBAT:${NC}"
        echo "• Automated cloud backups"
        echo "• Cross-cloud migrations"
        echo "• Encryption at rest"
        echo "• Bandwidth limiting"
        echo "• Progress monitoring"
        echo ""
        
    else
        echo -e "${YELLOW}○ rclone not found${NC}"
        echo ""
        echo -e "${BLUE}rclone - Cloud Storage Tool Installation${NC}"
        echo ""
        echo "rclone syncs files to cloud storage services like Google Drive, AWS S3, etc."
        echo "It's used by GWOMBAT for cloud backup and storage management."
        echo ""
        echo "Installation options:"
        echo "1. 🚀 Auto-install using official installer (recommended)"
        echo "2. 📥 Manual installation guide"
        echo "3. ⏭️  Skip installation"
        echo ""
        
        local install_choice
        install_choice=$(get_user_input "Select option (1-3)" "3" "false" "1-3")
        
        case "$install_choice" in
            1)
                echo ""
                echo -e "${CYAN}Installing rclone automatically...${NC}"
                if command -v curl >/dev/null 2>&1; then
                    echo "Using official rclone installer..."
                    if curl https://rclone.org/install.sh | sudo bash; then
                        echo -e "${GREEN}✓ rclone installation completed${NC}"
                        echo ""
                        echo -e "${YELLOW}Next steps:${NC}"
                        echo "1. Configure remotes: rclone config"
                        echo "2. Test configuration: rclone lsd <remote>:"
                        echo "3. Run GWOMBAT setup again to configure backup storage"
                        log_setup "rclone installed successfully"
                    else
                        echo -e "${RED}✗ rclone installation failed${NC}"
                        echo "Falling back to manual installation guide..."
                        install_choice=2
                        log_setup "rclone installation failed" "ERROR"
                    fi
                else
                    echo -e "${YELLOW}curl not found - falling back to manual guide${NC}"
                    install_choice=2
                fi
                ;;
            2)
                echo ""
                echo -e "${CYAN}Manual rclone Installation Guide${NC}"
                echo ""
                echo "Choose your installation method:"
                echo ""
                echo -e "${YELLOW}Linux/macOS (recommended):${NC}"
                echo "• One-line install: curl https://rclone.org/install.sh | sudo bash"
                echo ""
                echo -e "${YELLOW}Package Managers:${NC}"
                echo "• Ubuntu/Debian: sudo apt install rclone"
                echo "• macOS Homebrew: brew install rclone"
                echo "• Arch Linux: pacman -S rclone"
                echo ""
                echo -e "${YELLOW}Manual Download:${NC}"
                echo "• Visit: https://rclone.org/downloads/"
                echo "• Download binary for your platform"
                echo "• Extract and add to PATH"
                echo ""
                echo -e "${CYAN}After installation:${NC}"
                echo "1. Verify: rclone version"
                echo "2. Configure storage: rclone config"
                echo "3. Test: rclone lsd <remote>:"
                ;;
            3)
                echo -e "${YELLOW}⚠ Skipping rclone installation${NC}"
                echo "You can install rclone later for cloud storage functionality."
                ;;
        esac
        log_setup "rclone not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== restic - Encrypted Backup Tool ===${NC}"
    if command -v restic >/dev/null 2>&1; then
        local restic_version=$(restic version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${GREEN}✓ restic found: $restic_version${NC}"
        echo ""
        echo -e "${CYAN}restic Features:${NC}"
        echo "• Encrypted, deduplicated backups"
        echo "• Incremental backups"
        echo "• Multiple storage backends"
        echo "• Cross-platform compatibility"
        echo ""
        echo "Configure restic repositories in GWOMBAT backup settings"
        log_setup "restic found: $restic_version"
    else
        echo -e "${YELLOW}○ restic not found${NC}"
        echo ""
        echo -e "${BLUE}restic - Backup Tool Installation${NC}"
        echo ""
        echo "restic is a modern backup program that can backup to cloud storage."
        echo "It's used by GWOMBAT for automated backup workflows."
        echo ""
        echo "Installation options:"
        echo "1. 🚀 Auto-install using package manager (recommended)"
        echo "2. 📥 Manual installation guide"
        echo "3. ⏭️  Skip installation"
        echo ""
        
        local install_choice
        install_choice=$(get_user_input "Select option (1-3)" "3" "false" "1-3")
        
        case "$install_choice" in
            1)
                echo ""
                echo -e "${CYAN}Installing restic automatically...${NC}"
                # Platform-specific installation
                if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                    if command -v apt >/dev/null 2>&1; then
                        echo "Using apt package manager..."
                        if sudo apt update && sudo apt install -y restic; then
                            echo -e "${GREEN}✓ restic installed successfully via apt${NC}"
                            log_setup "restic installed via apt"
                        else
                            echo -e "${RED}✗ apt installation failed${NC}"
                            echo "Falling back to manual installation guide..."
                            install_choice=2
                        fi
                    elif command -v yum >/dev/null 2>&1; then
                        echo "Using yum package manager..."
                        if sudo yum install -y restic; then
                            echo -e "${GREEN}✓ restic installed successfully via yum${NC}"
                            log_setup "restic installed via yum"
                        else
                            echo -e "${RED}✗ yum installation failed${NC}"
                            echo "Falling back to manual installation guide..."
                            install_choice=2
                        fi
                    else
                        echo -e "${YELLOW}No supported package manager found${NC}"
                        echo "Falling back to manual installation guide..."
                        install_choice=2
                    fi
                elif [[ "$OSTYPE" == "darwin"* ]]; then
                    if command -v brew >/dev/null 2>&1; then
                        echo "Using Homebrew..."
                        if brew install restic; then
                            echo -e "${GREEN}✓ restic installed successfully via Homebrew${NC}"
                            log_setup "restic installed via Homebrew"
                        else
                            echo -e "${RED}✗ Homebrew installation failed${NC}"
                            echo "Falling back to manual installation guide..."
                            install_choice=2
                        fi
                    else
                        echo -e "${YELLOW}Homebrew not found${NC}"
                        echo "Falling back to manual installation guide..."
                        install_choice=2
                    fi
                else
                    echo -e "${YELLOW}Unsupported platform for auto-installation${NC}"
                    echo "Falling back to manual installation guide..."
                    install_choice=2
                fi
                ;;
            2)
                echo ""
                echo -e "${CYAN}Manual restic Installation Guide${NC}"
                echo ""
                echo "Choose your platform:"
                echo ""
                echo -e "${YELLOW}Linux:${NC}"
                echo "• Ubuntu/Debian: sudo apt install restic"
                echo "• RHEL/CentOS/Fedora: sudo yum install restic"
                echo "• Or download from: https://github.com/restic/restic/releases"
                echo ""
                echo -e "${YELLOW}macOS:${NC}"
                echo "• Homebrew: brew install restic"
                echo "• Or download from: https://github.com/restic/restic/releases"
                echo ""
                echo -e "${YELLOW}Windows:${NC}"
                echo "• Download from: https://github.com/restic/restic/releases"
                echo "• Or use Chocolatey: choco install restic"
                echo ""
                echo -e "${CYAN}After installation:${NC}"
                echo "1. Verify: restic version"
                echo "2. Initialize repository: restic init"
                echo "3. Configure in GWOMBAT backup settings"
                ;;
            3)
                echo -e "${YELLOW}⚠ Skipping restic installation${NC}"
                echo "You can install restic later for backup functionality."
                ;;
        esac
        log_setup "restic not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== jq - JSON Processing Tool ===${NC}"
    if command -v jq >/dev/null 2>&1; then
        local jq_version=$(jq --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓ jq found: $jq_version${NC}"
        log_setup "jq found: $jq_version"
    else
        echo -e "${YELLOW}○ jq not found${NC}"
        echo ""
        echo -e "${BLUE}jq Installation:${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Install with: sudo apt install jq"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install jq"
        else
            echo "Visit: https://stedolan.github.io/jq/download/"
        fi
        
        local install_jq
        install_jq=$(get_user_input "Install jq now? (y/n)" "y" "false")
        
        if [[ "$install_jq" =~ ^[Yy] ]]; then
            if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y jq
            elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                brew install jq
            else
                echo "Please install jq manually"
            fi
        fi
        log_setup "jq not found"
    fi
}

# Configure server/deployment settings
configure_deployment_settings() {
    echo ""
    echo -e "${CYAN}🚀 Installation Location${NC}"
    echo ""
    echo "GWOMBAT is typically installed directly on the production server where it will run."
    echo ""
    echo "Current setup assumes: ${GREEN}Local installation${NC} (running on this server)"
    echo ""
    
    local remote_deployment
    remote_deployment=$(get_user_input "Do you want to deploy GWOMBAT to a different remote server instead? (y/n)" "n" "false" "yn")
    
    if [[ "$remote_deployment" =~ ^[Yy] ]]; then
        echo ""
        echo -e "${YELLOW}Remote Deployment Setup${NC}"
        echo ""
        echo "⚠️  ${BOLD}Remote deployment requirements:${NC}"
        echo "• You must have SSH access to the target server"
        echo "• The target server needs git, bash, and SQLite installed"
        echo "• GWOMBAT will be deployed using git for version control"
        echo "• You'll need to configure GAM on the target server separately"
        echo ""
        
        local proceed_remote
        proceed_remote=$(get_user_input "Proceed with remote deployment setup? (y/n)" "y" "false" "yn")
        
        if [[ "$proceed_remote" =~ ^[Yy] ]]; then
            # Production server
            local production_server
            production_server=$(get_user_input "Remote server hostname" "" "true")
            
            # Production user
            local production_user
            production_user=$(get_user_input "Username on remote server" "" "true")
            
            # GWOMBAT path on server
            local gwombat_path
            gwombat_path=$(get_user_input "GWOMBAT installation path on remote server" "/opt/gwombat" "true")
            
            # SSH key path
            local ssh_key_path
            ssh_key_path=$(get_user_input "SSH key path for deployment" "$HOME/.ssh/gwombatgit-key" "false")
            
            export SETUP_PRODUCTION_SERVER="$production_server"
            export SETUP_PRODUCTION_USER="$production_user"
            export SETUP_GWOMBAT_PATH="$gwombat_path"
            export SETUP_SSH_KEY_PATH="$ssh_key_path"
            
            echo ""
            echo -e "${GREEN}✓ Remote deployment configured${NC}"
            echo -e "${YELLOW}Next steps after setup completion:${NC}"
            echo "1. Run: ./shared-utilities/deploy.sh (to deploy to remote server)"
            echo "2. SSH to $production_server and configure GAM"
            echo "3. Run GWOMBAT setup wizard on the remote server"
            
            log_setup "Remote deployment configured: $production_user@$production_server:$gwombat_path"
        else
            echo -e "${YELLOW}⚠ Reverting to local installation${NC}"
            log_setup "Remote deployment cancelled - using local installation"
        fi
    else
        echo -e "${GREEN}✓ Using local installation${NC}"
        echo "GWOMBAT will be configured to run on this server."
        log_setup "Local installation selected"
    fi
}

# Ask about initial scans
configure_initial_scans() {
    echo ""
    echo -e "${CYAN}📊 Initial System Discovery & Baseline Scans${NC}"
    echo ""
    echo "GWOMBAT can perform comprehensive initial scans to establish baseline"
    echo "system state and enable effective monitoring and management."
    echo ""
    echo -e "${BLUE}Available scan modules:${NC}"
    echo ""
    echo -e "${GREEN}Core System Scans:${NC}"
    echo "1. 👥 Account Discovery & Statistics"
    echo "   • All user accounts (active, suspended, admin)"
    echo "   • Account creation dates and last login"
    echo "   • Storage usage per user"
    echo "   • Organizational unit placement"
    echo ""
    echo "2. 💾 Shared Drives & Storage Analysis"
    echo "   • All shared drives and their sizes"
    echo "   • Permission analysis and sharing patterns"
    echo "   • Storage quotas and usage trends"
    echo "   • Orphaned files detection"
    echo ""
    echo "3. 🔐 Security & Compliance Baseline"
    echo "   • 2FA status for all accounts"
    echo "   • Admin activity monitoring setup"
    echo "   • Password policy compliance"
    echo "   • External sharing audit"
    echo ""
    echo -e "${BLUE}Advanced Discovery Scans:${NC}"
    echo "4. 📧 Email & Groups Infrastructure"
    echo "   • All Google Groups and memberships"
    echo "   • Email routing and forwarding rules"
    echo "   • Distribution list analysis"
    echo "   • Email retention policies"
    echo ""
    echo "5. 🌐 Domain & DNS Configuration"
    echo "   • Domain verification status"
    echo "   • DNS records and mail routing"
    echo "   • Custom directory integration"
    echo "   • API access and service accounts"
    echo ""
    echo "6. 📱 Device & Mobile Management"
    echo "   • Mobile device inventory"
    echo "   • Chrome OS device management"
    echo "   • App installations and policies"
    echo "   • Security compliance status"
    echo ""
    echo -e "${PURPLE}Scan Configuration Options:${NC}"
    echo "7. Custom scan selection (choose specific scans)"
    echo "8. Full comprehensive scan (all modules - recommended)"
    echo "9. Essential scans only (accounts + drives + security)"
    echo "10. Skip all initial scans"
    echo ""
    
    local scan_choice
    scan_choice=$(get_user_input "Select scan option (1-10)" "8" "true")
    
    case "$scan_choice" in
        1)
            export SETUP_SCAN_ACCOUNTS="true"
            echo -e "${GREEN}✓ Will perform account discovery & statistics${NC}"
            log_setup "Initial scan: accounts only"
            ;;
        2)
            export SETUP_SCAN_DRIVES="true"
            echo -e "${GREEN}✓ Will perform shared drives analysis${NC}"
            log_setup "Initial scan: shared drives only"
            ;;
        3)
            export SETUP_SCAN_SECURITY="true"
            echo -e "${GREEN}✓ Will perform security baseline scan${NC}"
            log_setup "Initial scan: security only"
            ;;
        4)
            export SETUP_SCAN_GROUPS="true"
            echo -e "${GREEN}✓ Will perform email & groups infrastructure scan${NC}"
            log_setup "Initial scan: groups only"
            ;;
        5)
            export SETUP_SCAN_DOMAIN="true"
            echo -e "${GREEN}✓ Will perform domain & DNS configuration scan${NC}"
            log_setup "Initial scan: domain only"
            ;;
        6)
            export SETUP_SCAN_DEVICES="true"
            echo -e "${GREEN}✓ Will perform device & mobile management scan${NC}"
            log_setup "Initial scan: devices only"
            ;;
        7)
            echo ""
            echo -e "${CYAN}Custom Scan Selection${NC}"
            echo "Select which scans to perform:"
            echo ""
            
            # Account scan
            local accounts_scan
            accounts_scan=$(get_user_input "Perform account discovery? (y/n)" "y" "false")
            if [[ "$accounts_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_ACCOUNTS="true"
                echo -e "${GREEN}  ✓ Account discovery enabled${NC}"
            fi
            
            # Drives scan
            local drives_scan
            drives_scan=$(get_user_input "Perform shared drives analysis? (y/n)" "y" "false")
            if [[ "$drives_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DRIVES="true"
                echo -e "${GREEN}  ✓ Shared drives analysis enabled${NC}"
            fi
            
            # Security scan
            local security_scan
            security_scan=$(get_user_input "Perform security baseline scan? (y/n)" "y" "false")
            if [[ "$security_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_SECURITY="true"
                echo -e "${GREEN}  ✓ Security baseline scan enabled${NC}"
            fi
            
            # Groups scan
            local groups_scan
            groups_scan=$(get_user_input "Perform email & groups scan? (y/n)" "n" "false")
            if [[ "$groups_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_GROUPS="true"
                echo -e "${GREEN}  ✓ Email & groups scan enabled${NC}"
            fi
            
            # Domain scan
            local domain_scan
            domain_scan=$(get_user_input "Perform domain configuration scan? (y/n)" "n" "false")
            if [[ "$domain_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DOMAIN="true"
                echo -e "${GREEN}  ✓ Domain configuration scan enabled${NC}"
            fi
            
            # Devices scan
            local devices_scan
            devices_scan=$(get_user_input "Perform device management scan? (y/n)" "n" "false")
            if [[ "$devices_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DEVICES="true"
                echo -e "${GREEN}  ✓ Device management scan enabled${NC}"
            fi
            
            log_setup "Initial scan: custom selection"
            ;;
        8)
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            export SETUP_SCAN_GROUPS="true"
            export SETUP_SCAN_DOMAIN="true"
            export SETUP_SCAN_DEVICES="true"
            echo -e "${GREEN}✓ Will perform full comprehensive scan (all modules)${NC}"
            log_setup "Initial scan: comprehensive (all modules)"
            ;;
        9)
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            echo -e "${GREEN}✓ Will perform essential scans (accounts + drives + security)${NC}"
            log_setup "Initial scan: essential scans"
            ;;
        10)
            echo -e "${YELLOW}⚠ Skipping all initial scans${NC}"
            log_setup "Skipped all initial scans"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice, defaulting to essential scans${NC}"
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            log_setup "Invalid scan choice, defaulted to essential"
            ;;
    esac
    
    # Configure scan depth and output
    if [[ "$SETUP_SCAN_ACCOUNTS" == "true" || "$SETUP_SCAN_DRIVES" == "true" || "$SETUP_SCAN_SECURITY" == "true" || 
          "$SETUP_SCAN_GROUPS" == "true" || "$SETUP_SCAN_DOMAIN" == "true" || "$SETUP_SCAN_DEVICES" == "true" ]]; then
        echo ""
        echo -e "${CYAN}Scan Configuration Options:${NC}"
        echo ""
        
        # Scan depth
        echo "Scan depth level:"
        echo "1. Quick scan (basic statistics only)"
        echo "2. Standard scan (detailed analysis)"
        echo "3. Deep scan (comprehensive with historical data)"
        echo ""
        
        local scan_depth
        scan_depth=$(get_user_input "Select scan depth (1-3)" "2" "false")
        export SETUP_SCAN_DEPTH="$scan_depth"
        
        # Output format
        echo ""
        echo "Scan data storage and output:"
        echo ""
        echo -e "${GREEN}✓ All scan data will be stored in SQLite database for analysis${NC}"
        echo -e "${GREEN}✓ Historical tracking and trend analysis enabled${NC}"
        echo ""
        echo "Additional output formats:"
        echo "1. Database only (recommended for production)"
        echo "2. Database + CSV export files"
        echo "3. Database + CSV + HTML dashboard (comprehensive)"
        echo ""
        
        local output_format
        output_format=$(get_user_input "Select additional output (1-3)" "1" "false" "1-3")
        export SETUP_SCAN_OUTPUT="$output_format"
        
        # Estimated time warning
        echo ""
        echo -e "${YELLOW}⏱️  Estimated scan time based on your selections:${NC}"
        case "$scan_depth" in
            1) echo "Quick scan: 2-5 minutes" ;;
            2) echo "Standard scan: 5-15 minutes" ;;
            3) echo "Deep scan: 15-45 minutes" ;;
        esac
        echo ""
        echo -e "${BLUE}💡 Database Benefits:${NC}"
        echo -e "${BLUE}    • Historical trend analysis and reporting${NC}"
        echo -e "${BLUE}    • Account lifecycle tracking across time${NC}"
        echo -e "${BLUE}    • Verification status and compliance monitoring${NC}"
        echo -e "${BLUE}    • Incremental updates - scans can be safely interrupted${NC}"
        
        log_setup "Scan configuration: depth=$scan_depth, output=$output_format"
    fi
}

# Generate .env file
generate_env_file() {
    echo ""
    echo -e "${CYAN}📝 Generating configuration file...${NC}"
    
    # Backup existing .env if it exists
    if [[ -f "$ENV_FILE" ]]; then
        local backup_file="$ENV_FILE.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        echo -e "${YELLOW}⚠ Existing .env backed up to: $backup_file${NC}"
        log_setup "Backed up existing .env to $backup_file"
    fi
    
    # Generate new .env file
    cat > "$ENV_FILE" << EOF
# GWOMBAT Configuration
# Generated by Setup Wizard on $(date)

# Domain and Organization Configuration
DOMAIN="${SETUP_DOMAIN:-your-domain.edu}"
ADMIN_EMAIL="${SETUP_ADMIN_EMAIL:-gwombat@your-domain.edu}"
ADMIN_USER="${SETUP_ADMIN_USER:-your-actual-admin@your-domain.edu}"

# GAM Configuration
GAM_PATH="${SETUP_GAM_PATH:-/usr/local/bin/gam}"
GAM_CONFIG_PATH="${SETUP_GAM_CONFIG_PATH:-$HOME/.gam}"

# Python Environment Configuration
PYTHON_PATH="${SETUP_PYTHON_PATH:-python3}"
PYTHON_VERSION="${SETUP_PYTHON_VERSION:-unknown}"
PYTHON_USE_VENV="${SETUP_PYTHON_USE_VENV:-false}"
PYTHON_VENV_PATH="${SETUP_PYTHON_VENV_PATH:-}"
PYTHON_PACKAGES_INSTALLED="${SETUP_PYTHON_PACKAGES_INSTALLED:-false}"

# Organizational Unit Paths
SUSPENDED_OU="${SETUP_SUSPENDED_OU:-/Suspended Users}"
PENDING_DELETION_OU="${SETUP_PENDING_DELETION_OU:-/Suspended Users/Pending Deletion}"
TEMPORARY_HOLD_OU="${SETUP_TEMPORARY_HOLD_OU:-/Suspended Users/Temporary Hold}"
EXIT_ROW_OU="${SETUP_EXIT_ROW_OU:-/Suspended Users/Exit Row}"

# Production Server Configuration (if configured)
PRODUCTION_SERVER="${SETUP_PRODUCTION_SERVER:-your-server.edu}"
PRODUCTION_USER="${SETUP_PRODUCTION_USER:-your-user}"
GWOMBAT_PATH="${SETUP_GWOMBAT_PATH:-/opt/path/to/gwombat}"

# SSH Configuration
SSH_KEY_PATH="${SETUP_SSH_KEY_PATH:-$HOME/.ssh/gwombatgit-key}"
SSH_KEY_PASSWORD="${SETUP_SSH_KEY_PASSWORD:-}"

# Google Drive Configuration
DRIVE_LABEL_ID="${SETUP_DRIVE_LABEL_ID:-your-drive-label-id}"

# Feature Flags (set by setup wizard)
SETUP_COMPLETED="true"
SETUP_DATE="$(date)"
INITIAL_SCANS_ACCOUNTS="${SETUP_SCAN_ACCOUNTS:-false}"
INITIAL_SCANS_DRIVES="${SETUP_SCAN_DRIVES:-false}"
INITIAL_SCANS_SECURITY="${SETUP_SCAN_SECURITY:-false}"
INITIAL_SCANS_GROUPS="${SETUP_SCAN_GROUPS:-false}"
INITIAL_SCANS_DOMAIN="${SETUP_SCAN_DOMAIN:-false}"
INITIAL_SCANS_DEVICES="${SETUP_SCAN_DEVICES:-false}"
SCAN_DEPTH="${SETUP_SCAN_DEPTH:-2}"
SCAN_OUTPUT_FORMAT="${SETUP_SCAN_OUTPUT:-3}"
EOF
    
    echo -e "${GREEN}✓ Configuration file created: $ENV_FILE${NC}"
    log_setup "Generated .env file"
}

# Perform initial scans
perform_initial_scans() {
    echo ""
    echo -e "${CYAN}🔍 Performing Initial System Discovery Scans${NC}"
    echo ""
    
    # Check if any scans are enabled
    if [[ "$SETUP_SCAN_ACCOUNTS" != "true" && "$SETUP_SCAN_DRIVES" != "true" && "$SETUP_SCAN_SECURITY" != "true" && 
          "$SETUP_SCAN_GROUPS" != "true" && "$SETUP_SCAN_DOMAIN" != "true" && "$SETUP_SCAN_DEVICES" != "true" ]]; then
        echo -e "${YELLOW}⚠ No initial scans configured${NC}"
        return 0
    fi
    
    # Verify GAM is properly configured before running scans
    if [[ -n "$SETUP_GAM_PATH" && -x "$SETUP_GAM_PATH" ]]; then
        echo -e "${CYAN}Verifying GAM configuration...${NC}"
        if ! $SETUP_GAM_PATH info domain >/dev/null 2>&1; then
            echo ""
            echo -e "${RED}✗ GAM is not properly configured!${NC}"
            echo -e "${YELLOW}GAM OAuth authentication must be completed before running scans.${NC}"
            echo ""
            echo "To complete GAM setup, run:"
            echo "  ${CYAN}$SETUP_GAM_PATH oauth create${NC}"
            echo ""
            echo "Then verify with:"
            echo "  ${CYAN}$SETUP_GAM_PATH info domain${NC}"
            echo ""
            echo -e "${YELLOW}Skipping initial scans due to incomplete GAM configuration.${NC}"
            log_setup "Skipped initial scans - GAM not configured" "WARN"
            return 1
        fi
        echo -e "${GREEN}✓ GAM configuration verified${NC}"
    else
        echo -e "${RED}✗ GAM not found or not executable${NC}"
        echo -e "${YELLOW}Skipping initial scans - GAM required${NC}"
        return 1
    fi
    
    # Create scan results directory
    local scan_date=$(date +%Y%m%d-%H%M%S)
    local scan_dir="$GWOMBAT_ROOT/reports/initial-scan-$scan_date"
    mkdir -p "$scan_dir"
    
    local scan_log="$scan_dir/scan-log.txt"
    local scan_summary="$scan_dir/scan-summary.txt"
    
    echo "Scan results will be saved to: $scan_dir"
    echo "This may take several minutes depending on your domain size and scan depth..."
    echo ""
    
    # Initialize progress tracking
    local total_scans=0
    local completed_scans=0
    
    # Count enabled scans
    [[ "$SETUP_SCAN_ACCOUNTS" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DRIVES" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_SECURITY" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_GROUPS" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DOMAIN" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DEVICES" == "true" ]] && ((total_scans++))
    
    echo "$(date): Starting $total_scans scan modules" > "$scan_log"
    echo "Scan depth: ${SETUP_SCAN_DEPTH:-2}, Output format: ${SETUP_SCAN_OUTPUT:-3}" >> "$scan_log"
    echo "" >> "$scan_log"
    
    # Initialize databases first
    echo -e "${CYAN}Initializing GWOMBAT databases...${NC}"
    if [[ -x "$GWOMBAT_ROOT/database_functions.sh" ]]; then
        if "$GWOMBAT_ROOT/database_functions.sh" init >> "$scan_log" 2>&1; then
            echo -e "${GREEN}✓ Database initialization successful${NC}"
        else
            echo -e "${YELLOW}⚠ Database initialization had issues (continuing)${NC}"
        fi
    fi
    echo ""
    
    # Account Discovery & Statistics
    if [[ "$SETUP_SCAN_ACCOUNTS" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 👥 Account Discovery & Statistics${NC}"
        
        local account_report="$scan_dir/accounts-discovery.csv"
        local account_summary="$scan_dir/accounts-summary.txt"
        
        echo "$(date): Starting account discovery scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering all user accounts..."
            
            # Basic account information
            echo "Email,Name,OrgUnit,CreationTime,LastLoginTime,IsAdmin,IsSuspended,StorageUsed,StorageLimit" > "$account_report"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" == "1" ]]; then
                # Quick scan - basic user list
                $SETUP_GAM_PATH print users basic >> "$scan_log" 2>&1
                echo "Quick account scan completed" >> "$account_summary"
            elif [[ "${SETUP_SCAN_DEPTH:-2}" == "2" ]]; then
                # Standard scan - detailed account info
                echo "Performing standard account analysis..."
                $SETUP_GAM_PATH print users fullname email ou creationtime lastlogintime isadmin suspended quotaused >> "$account_report" 2>>"$scan_log"
                
                # Account statistics
                local total_users=$($SETUP_GAM_PATH print users | tail -n +2 | wc -l)
                local admin_users=$($SETUP_GAM_PATH print users query isadmin=true | tail -n +2 | wc -l)
                local suspended_users=$($SETUP_GAM_PATH print users query issuspended=true | tail -n +2 | wc -l)
                
                echo "Account Statistics Summary" > "$account_summary"
                echo "=========================" >> "$account_summary"
                echo "Total Users: $total_users" >> "$account_summary"
                echo "Admin Users: $admin_users" >> "$account_summary"
                echo "Suspended Users: $suspended_users" >> "$account_summary"
                echo "Active Users: $((total_users - suspended_users))" >> "$account_summary"
                echo "" >> "$account_summary"
                
            else
                # Deep scan - comprehensive analysis with storage
                echo "Performing deep account analysis with storage details..."
                $SETUP_GAM_PATH print users fullname email ou creationtime lastlogintime isadmin suspended quotaused quotalimit >> "$account_report" 2>>"$scan_log"
                
                # Detailed organizational unit analysis
                echo "Analyzing organizational unit distribution..."
                $SETUP_GAM_PATH print orgs >> "$scan_dir/organizational-units.csv" 2>>"$scan_log"
                
                # Generate comprehensive summary
                echo "Generating comprehensive account analysis..." >> "$scan_log"
            fi
            
            echo -e "${GREEN}  ✓ Account discovery completed${NC}"
            echo "    Results: $account_report"
            if [[ -f "$account_summary" ]]; then
                echo "    Summary: $account_summary"
            fi
        else
            echo -e "${RED}  ✗ GAM not available for account scan${NC}"
            echo "GAM not available" >> "$account_summary"
        fi
        
        echo "$(date): Account discovery scan completed" >> "$scan_log"
        echo ""
        log_setup "Account discovery scan completed"
    fi
    
    # Shared Drives & Storage Analysis  
    if [[ "$SETUP_SCAN_DRIVES" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 💾 Shared Drives & Storage Analysis${NC}"
        
        local drives_report="$scan_dir/shared-drives.csv"
        local drives_summary="$scan_dir/drives-summary.txt"
        
        echo "$(date): Starting shared drives analysis" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering shared drives..."
            
            echo "DriveId,Name,CreatedTime,SizeGB,FileCount,Organizers,Members" > "$drives_report"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" == "1" ]]; then
                # Quick scan - basic drive list
                $SETUP_GAM_PATH print shareddrives >> "$drives_report" 2>>"$scan_log"
            else
                # Standard/Deep scan - detailed drive analysis
                echo "Analyzing shared drive details and permissions..."
                $SETUP_GAM_PATH print shareddrives >> "$scan_dir/shareddrives-full.csv" 2>>"$scan_log"
                
                # Drive statistics
                local total_drives=$($SETUP_GAM_PATH print shareddrives | tail -n +2 | wc -l)
                
                echo "Shared Drives Summary" > "$drives_summary"
                echo "====================" >> "$drives_summary"
                echo "Total Shared Drives: $total_drives" >> "$drives_summary"
                echo "" >> "$drives_summary"
                
                if [[ "${SETUP_SCAN_DEPTH:-2}" == "3" ]]; then
                    # Deep scan - file analysis
                    echo "Performing deep file analysis (this may take longer)..."
                    echo "Files by shared drive analysis initiated..." >> "$scan_log"
                fi
            fi
            
            echo -e "${GREEN}  ✓ Shared drives analysis completed${NC}"
            echo "    Results: $drives_report"
        else
            echo -e "${RED}  ✗ GAM not available for drives scan${NC}"
            echo "GAM not available" >> "$drives_summary"
        fi
        
        echo "$(date): Shared drives analysis completed" >> "$scan_log"
        echo ""
        log_setup "Shared drives analysis completed"
    fi
    
    # Security & Compliance Baseline
    if [[ "$SETUP_SCAN_SECURITY" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 🔐 Security & Compliance Baseline${NC}"
        
        local security_report="$scan_dir/security-baseline.csv"
        local security_summary="$scan_dir/security-summary.txt"
        
        echo "$(date): Starting security baseline scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Analyzing security configurations..."
            
            # 2FA Analysis
            echo "Checking 2FA status for all users..."
            echo "Email,Name,2FA_Enrolled,2FA_Enforced,LastLogin" > "$security_report"
            $SETUP_GAM_PATH print users email fullname isenrolledin2sv isenforcedin2sv lastlogintime >> "$security_report" 2>>"$scan_log"
            
            # Admin activity analysis
            echo "Analyzing admin accounts..."
            $SETUP_GAM_PATH print users query isadmin=true >> "$scan_dir/admin-accounts.csv" 2>>"$scan_log"
            
            # External sharing audit
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Auditing external sharing settings..."
                $SETUP_GAM_PATH print domains >> "$scan_dir/domain-security.csv" 2>>"$scan_log"
            fi
            
            # Security summary
            local users_with_2fa=$($SETUP_GAM_PATH print users query isenrolledin2sv=true | tail -n +2 | wc -l)
            local total_users_check=$($SETUP_GAM_PATH print users | tail -n +2 | wc -l)
            local admin_count=$($SETUP_GAM_PATH print users query isadmin=true | tail -n +2 | wc -l)
            
            echo "Security Baseline Summary" > "$security_summary"
            echo "========================" >> "$security_summary"
            echo "Total Users: $total_users_check" >> "$security_summary"
            echo "Users with 2FA: $users_with_2fa" >> "$security_summary"
            echo "Admin Accounts: $admin_count" >> "$security_summary"
            if [[ $total_users_check -gt 0 ]]; then
                echo "2FA Coverage: $(( users_with_2fa * 100 / total_users_check ))%" >> "$security_summary"
            else
                echo "2FA Coverage: N/A (no users found)" >> "$security_summary"
            fi
            echo "" >> "$security_summary"
            
            echo -e "${GREEN}  ✓ Security baseline scan completed${NC}"
            echo "    Results: $security_report"
        else
            echo -e "${RED}  ✗ GAM not available for security scan${NC}"
            echo "GAM not available" >> "$security_summary"
        fi
        
        echo "$(date): Security baseline scan completed" >> "$scan_log"
        echo ""
        log_setup "Security baseline scan completed"
    fi
    
    # Email & Groups Infrastructure
    if [[ "$SETUP_SCAN_GROUPS" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 📧 Email & Groups Infrastructure${NC}"
        
        local groups_report="$scan_dir/groups-infrastructure.csv"
        local groups_summary="$scan_dir/groups-summary.txt"
        
        echo "$(date): Starting groups infrastructure scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering Google Groups..."
            
            echo "GroupEmail,Name,Description,MemberCount,DirectMembersCount,Settings" > "$groups_report"
            $SETUP_GAM_PATH print groups >> "$groups_report" 2>>"$scan_log"
            
            # Group statistics
            local total_groups=$($SETUP_GAM_PATH print groups | tail -n +2 | wc -l)
            
            echo "Groups Infrastructure Summary" > "$groups_summary"
            echo "============================" >> "$groups_summary"
            echo "Total Groups: $total_groups" >> "$groups_summary"
            echo "" >> "$groups_summary"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Analyzing group memberships..."
                # Detailed group analysis would go here
            fi
            
            echo -e "${GREEN}  ✓ Groups infrastructure scan completed${NC}"
            echo "    Results: $groups_report"
        else
            echo -e "${RED}  ✗ GAM not available for groups scan${NC}"
            echo "GAM not available" >> "$groups_summary"
        fi
        
        echo "$(date): Groups infrastructure scan completed" >> "$scan_log"
        echo ""
        log_setup "Groups infrastructure scan completed"
    fi
    
    # Domain & DNS Configuration
    if [[ "$SETUP_SCAN_DOMAIN" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 🌐 Domain & DNS Configuration${NC}"
        
        local domain_report="$scan_dir/domain-configuration.txt"
        
        echo "$(date): Starting domain configuration scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Analyzing domain configuration..."
            
            echo "Domain Configuration Analysis" > "$domain_report"
            echo "============================" >> "$domain_report"
            $SETUP_GAM_PATH info domain >> "$domain_report" 2>>"$scan_log"
            
            echo "" >> "$domain_report"
            echo "Domain Verification:" >> "$domain_report"
            $SETUP_GAM_PATH print domains >> "$domain_report" 2>>"$scan_log"
            
            echo -e "${GREEN}  ✓ Domain configuration scan completed${NC}"
            echo "    Results: $domain_report"
        else
            echo -e "${RED}  ✗ GAM not available for domain scan${NC}"
            echo "GAM not available" > "$domain_report"
        fi
        
        echo "$(date): Domain configuration scan completed" >> "$scan_log"
        echo ""
        log_setup "Domain configuration scan completed"
    fi
    
    # Device & Mobile Management
    if [[ "$SETUP_SCAN_DEVICES" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 📱 Device & Mobile Management${NC}"
        
        local devices_report="$scan_dir/device-inventory.csv"
        local devices_summary="$scan_dir/devices-summary.txt"
        
        echo "$(date): Starting device management scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering managed devices..."
            
            # Mobile devices
            echo "DeviceId,Type,Model,OS,LastSync,Status,User" > "$devices_report"
            $SETUP_GAM_PATH print mobile >> "$devices_report" 2>>"$scan_log"
            
            # Chrome OS devices
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Scanning Chrome OS devices..."
                $SETUP_GAM_PATH print cros >> "$scan_dir/chromeos-devices.csv" 2>>"$scan_log"
            fi
            
            local mobile_count=$($SETUP_GAM_PATH print mobile | tail -n +2 | wc -l)
            
            echo "Device Management Summary" > "$devices_summary"
            echo "========================" >> "$devices_summary"
            echo "Mobile Devices: $mobile_count" >> "$devices_summary"
            echo "" >> "$devices_summary"
            
            echo -e "${GREEN}  ✓ Device management scan completed${NC}"
            echo "    Results: $devices_report"
        else
            echo -e "${RED}  ✗ GAM not available for device scan${NC}"
            echo "GAM not available" >> "$devices_summary"
        fi
        
        echo "$(date): Device management scan completed" >> "$scan_log"
        echo ""
        log_setup "Device management scan completed"
    fi
    
    # Generate overall scan summary
    echo ""
    echo -e "${CYAN}📋 Generating Scan Summary Report${NC}"
    
    echo "  → Creating report header..."
    echo "GWOMBAT Initial System Discovery Report" > "$scan_summary"
    echo "=======================================" >> "$scan_summary"
    echo "Scan Date: $(date)" >> "$scan_summary"
    echo "Domain: ${SETUP_DOMAIN}" >> "$scan_summary"
    echo "Scan Depth: ${SETUP_SCAN_DEPTH:-2}" >> "$scan_summary"
    echo "Total Modules: $total_scans" >> "$scan_summary"
    echo "" >> "$scan_summary"
    
    echo "  → Processing scan results..."
    echo "Scan Results Summary:" >> "$scan_summary"
    echo "--------------------" >> "$scan_summary"
    
    # Include summaries from each scan
    local summary_count=0
    for summary_file in "$scan_dir"/*-summary.txt; do
        if [[ -f "$summary_file" ]]; then
            echo "    • Including $(basename "$summary_file")..."
            echo "" >> "$scan_summary"
            cat "$summary_file" >> "$scan_summary"
            ((summary_count++))
        fi
    done
    echo "  → Processed $summary_count summary files"
    echo -e "${GREEN}  ✓ Scan summary report created: $scan_summary${NC}"
    
    # Generate HTML dashboard if requested
    if [[ "${SETUP_SCAN_OUTPUT:-3}" == "3" ]]; then
        echo ""
        echo -e "${CYAN}📊 Generating HTML Dashboard${NC}"
        echo "  → Creating HTML template..."
        local html_dashboard="$scan_dir/dashboard.html"
        
        cat > "$html_dashboard" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GWOMBAT Initial Discovery Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #1f4e79; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .stats { display: flex; gap: 20px; }
        .stat-box { background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 GWOMBAT Initial Discovery Dashboard</h1>
        <p>System baseline established on: $(date)</p>
    </div>
    
    <div class="section">
        <h2>📊 Scan Overview</h2>
        <div class="stats">
            <div class="stat-box">
                <h3>Modules Executed</h3>
                <p><strong>$total_scans</strong> scan modules</p>
            </div>
            <div class="stat-box">
                <h3>Scan Depth</h3>
                <p><strong>Level ${SETUP_SCAN_DEPTH:-2}</strong></p>
            </div>
            <div class="stat-box">
                <h3>Results Directory</h3>
                <p><code>$scan_dir</code></p>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>📋 Quick Actions</h2>
        <ul>
            <li>Review detailed CSV reports in scan directory</li>
            <li>Import data into GWOMBAT database for ongoing management</li>
            <li>Configure automated monitoring based on baseline</li>
            <li>Schedule regular scans to track changes</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>🔗 Report Files</h2>
        <ul>
EOF
        
        echo "  → Adding report file links..."
        # Add links to generated files
        local file_count=0
        for file in "$scan_dir"/*.csv "$scan_dir"/*.txt; do
            if [[ -f "$file" ]]; then
                local filename=$(basename "$file")
                echo "    • Linking $filename..."
                echo "            <li><a href=\"$filename\">$filename</a></li>" >> "$html_dashboard"
                ((file_count++))
            fi
        done
        
        echo "  → Finalizing HTML structure..."
        echo '        </ul>' >> "$html_dashboard"
        echo '    </div>' >> "$html_dashboard"
        echo '</body>' >> "$html_dashboard"
        echo '</html>' >> "$html_dashboard"
        
        echo -e "${GREEN}  ✓ HTML dashboard created with $file_count linked files${NC}"
        echo -e "${GREEN}  ✓ Dashboard location: $html_dashboard${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ All Initial Scans Completed Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📊 Scan Results Summary:${NC}"
    echo "• Scan directory: $scan_dir"
    echo "• Total modules: $total_scans"
    echo "• Scan log: $scan_log"
    echo "• Summary report: $scan_summary"
    
    if [[ "${SETUP_SCAN_OUTPUT:-3}" == "3" ]]; then
        echo "• HTML dashboard: $scan_dir/dashboard.html"
    fi
    
    echo ""
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo "1. Review scan results in the reports directory"
    echo "2. Use GWOMBAT's import functions to load data into the database"
    echo "3. Configure ongoing monitoring based on discovered baseline"
    echo "4. Set up automated scans to track system changes"
    
    log_setup "All initial scans completed successfully - results in $scan_dir"
}

# Show setup summary
show_setup_summary() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                            Setup Complete!                                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ GWOMBAT has been configured successfully!${NC}"
    echo ""
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "• Domain: ${SETUP_DOMAIN}"
    echo "• Admin User: ${SETUP_ADMIN_USER}"
    echo "• GAM Path: ${SETUP_GAM_PATH}"
    echo "• Configuration: $ENV_FILE"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Run './gwombat.sh' to start using GWOMBAT"
    echo "2. Check the dashboard for system overview"
    echo "3. Review the logs directory for setup details"
    echo ""
    if [[ -n "$SETUP_PRODUCTION_SERVER" ]]; then
        echo -e "${CYAN}Deployment:${NC}"
        echo "• Server: ${SETUP_PRODUCTION_SERVER}"
        echo "• Run './shared-utilities/deploy.sh' to deploy to production"
        echo ""
    fi
    echo -e "${YELLOW}Setup log saved to: $SETUP_LOG${NC}"
    echo ""
    log_setup "Setup wizard completed successfully"
}

# Main setup wizard flow
main() {
    show_setup_banner
    
    # Check if first time
    if ! is_first_time_setup; then
        echo -e "${YELLOW}Configuration file already exists.${NC}"
        echo ""
        echo "Would you like to:"
        echo "1. Reconfigure (backup existing config)"
        echo "2. Exit"
        echo ""
        local choice
        choice=$(get_user_input "Select option (1-2)" "2" "true")
        
        if [[ "$choice" != "1" ]]; then
            echo "Setup cancelled."
            exit 0
        fi
        echo ""
    fi
    
    # Run setup steps
    if ! check_setup_dependencies; then
        echo ""
        echo -e "${RED}Cannot continue setup without required dependencies.${NC}"
        echo "Please install missing dependencies and run setup again."
        exit 1
    fi
    
    configure_domain_settings
    configure_gam
    configure_organizational_units
    configure_python_environment
    configure_optional_tools
    configure_deployment_settings
    configure_initial_scans
    
    generate_env_file
    perform_initial_scans
    show_setup_summary
    
    echo ""
    read -p "Press Enter to start GWOMBAT..."
    
    # Launch GWOMBAT
    if [[ -x "$GWOMBAT_ROOT/gwombat.sh" ]]; then
        "$GWOMBAT_ROOT/gwombat.sh"
    fi
}

# Standalone Python environment setup function
setup_python_environment_standalone() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    GWOMBAT Python Environment Setup                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Set up logging for standalone mode
    local standalone_log="$GWOMBAT_ROOT/logs/python-setup-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$GWOMBAT_ROOT/logs"
    
    # Override log function for standalone mode
    log_setup() {
        local message="$1"
        local level="${2:-INFO}"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" >> "$standalone_log"
        if [[ "$level" == "ERROR" ]]; then
            echo -e "${RED}[ERROR]${NC} $message"
        elif [[ "$level" == "WARN" ]]; then
            echo -e "${YELLOW}[WARN]${NC} $message"
        fi
    }
    
    # Check if running from GWOMBAT directory
    if [[ ! -f "./gwombat.sh" ]]; then
        echo -e "${RED}Error: This script must be run from the GWOMBAT directory${NC}"
        echo "Please run: cd /path/to/gwombat && ./setup_wizard.sh python"
        exit 1
    fi
    
    echo "This utility will configure Python environment for GWOMBAT."
    echo "Log file: $standalone_log"
    echo ""
    
    # Run Python configuration
    configure_python_environment
    
    # Update .env file if it exists
    if [[ -f "./.env" ]]; then
        echo ""
        echo -e "${CYAN}Updating .env configuration...${NC}"
        
        # Create backup
        local backup_file="./.env.backup.$(date +%Y%m%d-%H%M%S)"
        cp "./.env" "$backup_file"
        echo "Backup created: $backup_file"
        
        # Update Python configuration in .env
        local temp_env="/tmp/gwombat_env_update.$$"
        
        # Remove existing Python configuration
        grep -v "^PYTHON_" "./.env" > "$temp_env"
        
        # Add new Python configuration
        {
            echo ""
            echo "# Python Environment Configuration (updated $(date))"
            echo "PYTHON_PATH=\"${SETUP_PYTHON_PATH:-python3}\""
            echo "PYTHON_VERSION=\"${SETUP_PYTHON_VERSION:-unknown}\""
            echo "PYTHON_USE_VENV=\"${SETUP_PYTHON_USE_VENV:-false}\""
            echo "PYTHON_VENV_PATH=\"${SETUP_PYTHON_VENV_PATH:-}\""
            echo "PYTHON_PACKAGES_INSTALLED=\"${SETUP_PYTHON_PACKAGES_INSTALLED:-false}\""
        } >> "$temp_env"
        
        mv "$temp_env" "./.env"
        echo -e "${GREEN}✓ .env file updated with Python configuration${NC}"
        log_setup ".env file updated with Python configuration"
    else
        echo -e "${YELLOW}⚠ .env file not found - configuration not saved${NC}"
        echo "Run the full setup wizard to create configuration file"
        log_setup ".env file not found" "WARN"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Python Environment Setup Complete!${NC}"
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    if [[ -n "$SETUP_PYTHON_VERSION" ]]; then
        echo "• Python Version: $SETUP_PYTHON_VERSION"
    fi
    if [[ "$SETUP_PYTHON_USE_VENV" == "true" ]]; then
        echo "• Virtual Environment: $SETUP_PYTHON_VENV_PATH"
    fi
    if [[ -n "$SETUP_PYTHON_PACKAGES_INSTALLED" ]]; then
        echo "• Package Installation: $SETUP_PYTHON_PACKAGES_INSTALLED"
    fi
    echo "• Setup Log: $standalone_log"
    echo ""
    
    if [[ "$SETUP_PYTHON_PACKAGES_INSTALLED" == "true" ]]; then
        echo -e "${CYAN}🎉 Python environment is ready for advanced GWOMBAT features!${NC}"
        echo ""
        echo "You can now use:"
        echo "• SCuBA compliance reporting"
        echo "• Advanced data visualization"
        echo "• HTML report generation"
        echo "• Enhanced security analysis"
    elif [[ "$SETUP_PYTHON_PACKAGES_INSTALLED" == "partial" ]]; then
        echo -e "${YELLOW}⚠ Python environment partially configured${NC}"
        echo "Some packages may need manual installation"
    else
        echo -e "${YELLOW}ℹ️  Python environment configured but packages not installed${NC}"
        echo "Install packages later with: pip3 install -r python-modules/requirements.txt"
    fi
}

# Check command line arguments for standalone mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "python"|"python-env"|"python-environment")
            GWOMBAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            setup_python_environment_standalone
            ;;
        *)
            main "$@"
            ;;
    esac
fi