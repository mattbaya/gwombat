#!/bin/bash

# GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner
#
# A comprehensive suspended account lifecycle management system with database tracking,
# verification, and automated workflows. For complete documentation, installation
# instructions, and usage examples, please refer to README.md.
#
# This system manages Google Workspace accounts through their complete lifecycle
# from suspension to deletion with persistent state tracking and verification capabilities.
#
# Key Features:
# - Database-driven account lifecycle tracking with SQLite
# - Account scanning and automated stage discovery
# - List-based batch operations with verification
# - Secure deployment with git-based workflows
# - Environment-configurable paths and settings
#
# For complete documentation including installation, usage, configuration,
# and deployment instructions, see README.md and DEPLOYMENT.md
#

# GWOMBAT Configuration
# Google Workspace Optimization, Management, Backups And Taskrunner - consolidates all suspended account operations with menu system and preview functionality

# Variables now loaded via load_configuration() function

# Organizational Unit paths (configurable via local-config/server.env)
OU_TEMPHOLD="${TEMPORARY_HOLD_OU:-/Suspended Accounts/Suspended - Temporary Hold}"
OU_PENDING_DELETION="${PENDING_DELETION_OU:-/Suspended Accounts/Suspended - Pending Deletion}"  
OU_SUSPENDED="${SUSPENDED_OU:-/Suspended Accounts}"
OU_ACTIVE="${DOMAIN:-yourdomain.edu}"

# Google Drive Label IDs (configurable via local-config/server.env)
LABEL_ID="${DRIVE_LABEL_ID:-default-label-id}"

# Load server-specific configuration
if [[ -f "local-config/server.env" ]]; then
    source local-config/server.env
    echo "Loaded server configuration from local-config/server.env"
else
    echo "Warning: local-config/server.env not found, using default paths"
fi

# Advanced Logging and Reporting Configuration
LOG_DIR="${LOG_PATH:-./logs}"
BACKUP_DIR="${BACKUPS_PATH:-./backups}"
REPORT_DIR="${REPORTS_PATH:-./reports}"
TMP_DIR="${TMP_PATH:-./tmp}"
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$REPORT_DIR" "$TMP_DIR"

# Log files
SESSION_ID=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/session-${SESSION_ID}.log"
ERROR_LOG="${LOG_DIR}/errors-$(date +%Y%m%d).log"
OPERATION_LOG="${LOG_DIR}/operations-$(date +%Y%m%d).log"
PERFORMANCE_LOG="${LOG_DIR}/performance-$(date +%Y%m%d).log"
AUDIT_LOG="${LOG_DIR}/audit-$(date +%Y%m%d).log"

# Report files
DAILY_SUMMARY="${REPORT_DIR}/daily-summary-$(date +%Y%m%d).txt"
OPERATION_SUMMARY="${REPORT_DIR}/operation-summary-${SESSION_ID}.txt"
USER_ACTIVITY_REPORT="${REPORT_DIR}/user-activity-$(date +%Y%m%d).txt"

# Configuration Management
CONFIG_FILE="./config/gwombat-config.json"
CONFIG_DIR="./config"
mkdir -p "$CONFIG_DIR"

# Load configuration from file or set defaults
load_configuration() {
    # Set default values
    DEFAULT_GAM_PATH="/usr/local/bin/gam"
    DEFAULT_SCRIPT_PATH="${GWOMBAT_PATH:-$(pwd)}"
    DEFAULT_SHARED_UTILITIES_PATH="shared-utilities"
    DEFAULT_PROGRESS_ENABLED="true"
    DEFAULT_CONFIRMATION_LEVEL="normal"
    DEFAULT_LOG_RETENTION_DAYS="30"
    DEFAULT_BACKUP_RETENTION_DAYS="90"
    DEFAULT_OPERATION_TIMEOUT="300"
    
    # Load .env file if it exists
    if [[ -f ".env" ]]; then
        source .env
        echo "Loaded environment configuration from .env"
    fi
    
    # Override with environment variables if set
    GAM="${GAM_PATH:-$DEFAULT_GAM_PATH}"
    SCRIPTPATH="${SCRIPT_PATH:-$DEFAULT_SCRIPT_PATH}"
    SHARED_UTILITIES_PATH="${SHARED_UTILITIES_PATH:-$DEFAULT_SHARED_UTILITIES_PATH}"
    PROGRESS_ENABLED="${PROGRESS_SETTING:-$DEFAULT_PROGRESS_ENABLED}"
    CONFIRMATION_LEVEL="${CONFIRMATION_SETTING:-$DEFAULT_CONFIRMATION_LEVEL}"
    LOG_RETENTION_DAYS="${LOG_RETENTION:-$DEFAULT_LOG_RETENTION_DAYS}"
    BACKUP_RETENTION_DAYS="${BACKUP_RETENTION:-$DEFAULT_BACKUP_RETENTION_DAYS}"
    OPERATION_TIMEOUT="${OP_TIMEOUT:-$DEFAULT_OPERATION_TIMEOUT}"
    
    # Load from config file if it exists
    if [[ -f "$CONFIG_FILE" ]]; then
        # Parse JSON config file
        local config_gam=$(grep '"gam_path"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_script_path=$(grep '"script_path"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_listshared=$(grep '"listshared_path"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_progress=$(grep '"progress_enabled"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_confirmation=$(grep '"confirmation_level"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_log_retention=$(grep '"log_retention_days"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_backup_retention=$(grep '"backup_retention_days"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        local config_timeout=$(grep '"operation_timeout"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
        
        # Use config values if available
        [[ -n "$config_gam" ]] && GAM="$config_gam"
        [[ -n "$config_script_path" ]] && SCRIPTPATH="$config_script_path"
        [[ -n "$config_shared_utilities" ]] && SHARED_UTILITIES_PATH="$config_shared_utilities"
        [[ -n "$config_progress" ]] && PROGRESS_ENABLED="$config_progress"
        [[ -n "$config_confirmation" ]] && CONFIRMATION_LEVEL="$config_confirmation"
        [[ -n "$config_log_retention" ]] && LOG_RETENTION_DAYS="$config_log_retention"
        [[ -n "$config_backup_retention" ]] && BACKUP_RETENTION_DAYS="$config_backup_retention"
        [[ -n "$config_timeout" ]] && OPERATION_TIMEOUT="$config_timeout"
    fi
}

# Create default configuration file
create_default_config() {
    cat > "$CONFIG_FILE" << EOF
{
  "version": "2.0",
  "description": "GWOMBAT Configuration",
  "created": "$(date -Iseconds)",
  "settings": {
    "gam_path": "/usr/local/bin/gam",
    "script_path": "${SCRIPT_TEMP_PATH:-./tmp}/suspended",
    "listshared_path": "${SCRIPT_TEMP_PATH:-./tmp}/listshared",
    "progress_enabled": "true",
    "confirmation_level": "normal",
    "log_retention_days": "30",
    "backup_retention_days": "90",
    "operation_timeout": "300"
  },
  "organizational_units": {
    "temporary_hold": "/Suspended Accounts/Suspended - Temporary Hold",
    "pending_deletion": "/Suspended Accounts/Suspended - Pending Deletion",
    "suspended": "/Suspended Accounts",
    "active": "/${DOMAIN:-yourdomain.edu}"
  },
  "google_drive": {
    "label_id": "xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb",
    "field_id": "62BB395EC6",
    "selection_id": "68E9987D43"
  },
  "features": {
    "dry_run_default": false,
    "backup_enabled": true,
    "performance_logging": true,
    "audit_logging": true,
    "auto_cleanup": true
  }
}
EOF
    echo -e "${GREEN}Default configuration created: $CONFIG_FILE${NC}"
}

# Load configuration
load_configuration

# Initialize session logging
echo "=== SESSION START: $(date) ===" >> "$LOG_FILE"
echo "Session ID: $SESSION_ID" >> "$LOG_FILE"
echo "User: $(whoami)" >> "$LOG_FILE"
echo "Working Directory: $(pwd)" >> "$LOG_FILE"
echo "Script Version: GWOMBAT v3.0" >> "$LOG_FILE"
echo "GAM Path: $GAM" >> "$LOG_FILE"
echo "Script Path: $SCRIPTPATH" >> "$LOG_FILE"
echo "Progress Enabled: $PROGRESS_ENABLED" >> "$LOG_FILE"
echo "Confirmation Level: $CONFIRMATION_LEVEL" >> "$LOG_FILE"

FIELD_ID="62BB395EC6"
SELECTION_ID="68E9987D43"

# Global settings
DRY_RUN=false
DISCOVERY_MODE=false
PROGRESS_ENABLED=true

# Security: GAM Input Sanitization Function
# Removes or escapes dangerous shell characters from user inputs to prevent command injection
sanitize_gam_input() {
    local input="$1"
    local sanitized=""
    
    if [[ -z "$input" ]]; then
        echo ""
        return 0
    fi
    
    # Remove dangerous shell metacharacters that could lead to command injection
    # Keep only alphanumeric, dots, hyphens, underscores, @, spaces, and basic punctuation for emails/usernames
    sanitized=$(echo "$input" | sed 's/[;&|`$(){}[\]<>"'\''\\]//g')
    
    # Log sanitization if changes were made
    if [[ "$input" != "$sanitized" ]]; then
        echo "WARNING: Input sanitized - removed potentially dangerous characters" >> "$AUDIT_LOG"
        echo "Original: $input" >> "$AUDIT_LOG"
        echo "Sanitized: $sanitized" >> "$AUDIT_LOG"
        echo "Timestamp: $(date)" >> "$AUDIT_LOG"
        echo "---" >> "$AUDIT_LOG"
        
        # Also log to console if not in quiet mode
        if [[ "${QUIET_MODE:-false}" != "true" ]]; then
            echo -e "${YELLOW}WARNING: Input sanitized to remove potentially dangerous characters${NC}" >&2
        fi
    fi
    
    echo "$sanitized"
}

# Enhanced dependency check function with logging and optional tools
store_domain_in_database() {
    local domain="$1"
    local db_file="${SCRIPTPATH}/local-config/local-config/account_lifecycle.db"
    
    if [[ -f "$db_file" && -n "$domain" ]]; then
        sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('configured_domain', '$domain');" 2>/dev/null
        sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('domain_set_at', datetime('now'));" 2>/dev/null
    fi
}

reset_database_for_domain_change() {
    local new_domain="$1"
    local old_domain="$2"
    local db_file="${SCRIPTPATH}/local-config/local-config/account_lifecycle.db"
    
    echo -e "${YELLOW}⚠️  Domain change detected!${NC}"
    echo -e "${YELLOW}   Old domain: $old_domain${NC}"
    echo -e "${YELLOW}   New domain: $new_domain${NC}"
    echo ""
    echo -e "${YELLOW}Database contains data for the old domain and must be reset.${NC}"
    echo -e "${YELLOW}This will clear all account data, lists, and history.${NC}"
    echo ""
    
    if [[ -f "$db_file" ]]; then
        local account_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "0")
        local list_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM account_lists;" 2>/dev/null || echo "0")
        
        if [[ "$account_count" -gt 0 || "$list_count" -gt 0 ]]; then
            echo -e "${CYAN}Current database contains:${NC}"
            echo "  • $account_count accounts"
            echo "  • $list_count account lists"
            echo ""
            
            # Create backup before reset
            local backup_file="${db_file}.backup-${old_domain}-$(date +%Y%m%d_%H%M%S)"
            echo -e "${CYAN}Creating backup: ${backup_file}${NC}"
            cp "$db_file" "$backup_file"
            echo -e "${GREEN}✓ Backup created${NC}"
            echo ""
        fi
    fi
    
    echo -e "${RED}Reset database for domain change? (y/N)${NC}"
    read -p "> " confirm
    if [[ "$confirm" =~ ^[Yy] ]]; then
        if [[ -f "$db_file" ]]; then
            rm "$db_file"
            echo -e "${GREEN}✓ Database reset for new domain: $new_domain${NC}"
        fi
        
        # Initialize fresh database with new domain
        if [[ -f "${SCRIPTPATH}/local-config/database_schema.sql" ]]; then
            echo -e "${CYAN}Initializing fresh database...${NC}"
            sqlite3 "$db_file" < "${SCRIPTPATH}/local-config/database_schema.sql"
            sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('configured_domain', '$new_domain');"
            sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('domain_changed_at', datetime('now'));"
            echo -e "${GREEN}✓ Fresh database initialized for: $new_domain${NC}"
        fi
        return 0
    else
        echo -e "${YELLOW}Database reset cancelled. GWOMBAT cannot proceed with mixed domain data.${NC}"
        return 1
    fi
}

show_gam_info() {
    local gam_path="${GAM_PATH:-gam}"
    
    echo -e "${BLUE}=== GAM Configuration Information ===${NC}"
    echo ""
    echo -e "${CYAN}GAM Path:${NC} $gam_path"
    echo -e "${CYAN}GAM Config Path:${NC} ${GAM_CONFIG_PATH:-~/.gam}"
    echo ""
    
    if ! command -v "$gam_path" >/dev/null 2>&1; then
        echo -e "${RED}❌ GAM not found at: $gam_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}GAM Domain Information:${NC}"
    local gam_domain_info
    if command -v timeout >/dev/null 2>&1; then
        gam_domain_info=$(timeout 15 "$gam_path" info domain 2>/dev/null)
    else
        gam_domain_info=$("$gam_path" info domain 2>/dev/null)
    fi
    
    if [[ -n "$gam_domain_info" ]]; then
        echo "$gam_domain_info"
    else
        echo -e "${YELLOW}⚠️  GAM not configured or cannot access domain${NC}"
        echo "Run: $gam_path oauth create"
    fi
    
    echo ""
    echo -e "${CYAN}OAuth Token Location:${NC}"
    if [[ -n "${GAM_CONFIG_PATH}" ]]; then
        local token_path="${GAM_CONFIG_PATH}/oauth2.txt"
        if [[ -f "$token_path" ]]; then
            echo -e "${GREEN}✓ Found: $token_path${NC}"
            echo -e "${GRAY}Created: $(stat -f "%Sm" "$token_path" 2>/dev/null || stat -c "%y" "$token_path" 2>/dev/null)${NC}"
        else
            echo -e "${YELLOW}⚠️  Not found: $token_path${NC}"
        fi
    else
        echo -e "${YELLOW}No GAM_CONFIG_PATH set${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Current GWOMBAT Configuration:${NC}"
    echo -e "Domain: ${DOMAIN:-not set}"
    echo -e "Admin User: ${ADMIN_USER:-not set}"
    echo ""
}

verify_gam_domain() {
    local gam_path="${GAM:-gam}"
    local configured_domain="${DOMAIN}"
    local db_file="${SCRIPTPATH}/local-config/account_lifecycle.db"
    
    if [[ -z "$configured_domain" ]]; then
        echo -e "${RED}❌ CRITICAL: No DOMAIN configured in .env file${NC}"
        echo -e "${YELLOW}Please set DOMAIN in your .env file${NC}"
        return 1
    fi
    
    if ! command -v "$gam_path" >/dev/null 2>&1; then
        echo -e "${RED}❌ CRITICAL: GAM not found at: $gam_path${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔒 Verifying GAM domain matches configuration...${NC}"
    
    # Get domain from GAM
    local gam_domain_info
    if command -v timeout >/dev/null 2>&1; then
        gam_domain_info=$(timeout 15 "$gam_path" info domain 2>/dev/null)
    else
        gam_domain_info=$("$gam_path" info domain 2>/dev/null)
    fi
    
    if [[ -z "$gam_domain_info" ]]; then
        echo -e "${RED}❌ CRITICAL: GAM is not configured or cannot access domain information${NC}"
        echo -e "${YELLOW}Please run: $gam_path oauth create${NC}"
        echo -e "${YELLOW}Or check GAM configuration with: $gam_path info domain${NC}"
        return 1
    fi
    
    # Extract primary domain from GAM output (handle various formats)
    local gam_primary_domain=$(echo "$gam_domain_info" | grep -i "Primary Domain" | awk '{print $3}' | cut -d':' -f1 | sed 's/Verified.*$//' | tr -d '[:space:]')
    
    if [[ -z "$gam_primary_domain" ]]; then
        echo -e "${RED}❌ CRITICAL: Cannot determine primary domain from GAM${NC}"
        echo -e "${GRAY}GAM Output:${NC}"
        echo "$gam_domain_info" | head -10
        echo ""
        echo -e "${CYAN}For detailed GAM info, run: show_gam_info${NC}"
        return 1
    fi
    
    # Compare domains (case-insensitive)
    local gam_domain_lower=$(echo "$gam_primary_domain" | tr '[:upper:]' '[:lower:]')
    local config_domain_lower=$(echo "$configured_domain" | tr '[:upper:]' '[:lower:]')
    if [[ "$gam_domain_lower" == "$config_domain_lower" ]]; then
        echo -e "${GREEN}✅ VERIFIED: GAM domain matches configuration${NC}"
        echo -e "${GREEN}   Configured: $configured_domain${NC}"
        echo -e "${GREEN}   GAM Domain: $gam_primary_domain${NC}"
        
        # Check if database has different domain data
        if [[ -f "$db_file" ]]; then
            local db_domain=$(sqlite3 "$db_file" "SELECT value FROM config WHERE key='configured_domain';" 2>/dev/null)
            if [[ -n "$db_domain" && "$db_domain" != "$configured_domain" ]]; then
                echo ""
                if ! reset_database_for_domain_change "$configured_domain" "$db_domain"; then
                    return 1
                fi
            else
                # Store/update domain in database if not already set
                store_domain_in_database "$configured_domain"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}❌ CRITICAL SECURITY ISSUE: Domain mismatch!${NC}"
        echo -e "${RED}   .env DOMAIN: $configured_domain${NC}"
        echo -e "${RED}   GAM Domain:  $gam_primary_domain${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  This is a security risk - GAM commands will run against: $gam_primary_domain${NC}"
        echo -e "${YELLOW}⚠️  But GWOMBAT is configured for: $configured_domain${NC}"
        echo ""
        echo -e "${CYAN}To fix this issue:${NC}"
        echo "1. Update DOMAIN in .env to: $gam_primary_domain"
        echo "2. OR reconfigure GAM for domain: $configured_domain"
        echo "3. OR use a different GAM config path for $configured_domain"
        echo ""
        echo -e "${CYAN}For detailed GAM info, run: show_gam_info${NC}"
        return 1
    fi
}

check_dependencies() {
    local missing_deps=()
    local warnings=()
    local recommendations=()
    local optional_tools=()
    
    log_info "Starting GWOMBAT dependency check" "console"
    echo -e "${BLUE}=== GWOMBAT Dependency Check ===${NC}"
    echo ""
    
    # Critical domain verification first
    if ! verify_gam_domain; then
        echo -e "${RED}❌ CRITICAL: Domain verification failed - stopping dependency check${NC}"
        echo -e "${YELLOW}Fix the domain configuration before proceeding${NC}"
        return 1
    fi
    echo ""
    
    # Essential dependencies
    echo -e "${CYAN}Essential Dependencies:${NC}"
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
        log_error "Essential dependency missing: bash"
    else
        local bash_version=$(bash --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        echo -e "${GREEN}✓ Bash: $bash_version${NC}"
        log_info "Bash version: $bash_version"
    fi
    
    if ! command -v sqlite3 >/dev/null 2>&1; then
        missing_deps+=("sqlite3")
        log_error "Essential dependency missing: sqlite3"
    else
        local sqlite_version=$(sqlite3 --version | cut -d' ' -f1)
        echo -e "${GREEN}✓ SQLite: $sqlite_version${NC}"
        log_info "SQLite version: $sqlite_version"
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
        log_error "Essential dependency missing: git"
    else
        local git_version=$(git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo -e "${GREEN}✓ Git: $git_version${NC}"
        log_info "Git version: $git_version"
    fi
    
    # Check Python
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
        log_error "Essential dependency missing: python3"
    else
        local python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${GREEN}✓ Python: $python_version${NC}"
        log_info "Python version: $python_version"
        
        # Check Python packages for SCuBA compliance
        if python3 -c "import google.api_core" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Google API packages available${NC}"
            log_info "Python Google API packages detected"
        else
            recommendations+=("Install Python Google API packages for SCuBA compliance: pip3 install -r python-modules/requirements.txt")
            log_info "Python Google API packages missing - SCuBA compliance will need setup"
        fi
    fi
    
    echo ""
    echo -e "${CYAN}Google Workspace Integration:${NC}"
    
    # Check GAM
    local gam_path="${GAM:-${GAM_PATH:-/usr/local/bin/gam}}"
    if [[ -x "$gam_path" ]]; then
        local gam_version=$($gam_path version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}✓ GAM: $gam_version${NC}"
        echo -e "${GREEN}  Path: $gam_path${NC}"
        log_info "GAM found: $gam_version at $gam_path"
        
        # Check if GAM is configured (with timeout handling)
        echo -e "${YELLOW}  Checking GAM configuration...${NC}"
        if command -v timeout >/dev/null 2>&1; then
            # Use timeout if available (Linux)
            if timeout 10 $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
                echo -e "${GREEN}  ✓ GAM is configured${NC}"
                log_info "GAM is configured and working"
            else
                recommendations+=("GAM needs configuration: Run 'gam info domain' to verify setup")
                echo -e "${YELLOW}  ○ GAM found but not configured or timed out${NC}"
                log_info "GAM found but not configured or configuration check timed out"
            fi
        else
            # Fallback for macOS - skip configuration check to avoid hang
            echo -e "${YELLOW}  ○ GAM found - configuration check skipped (run 'gam info domain' to verify)${NC}"
            recommendations+=("Verify GAM configuration: Run 'gam info domain' manually")
            log_info "GAM found but configuration check skipped (timeout not available)"
        fi
    else
        missing_deps+=("GAM (Google Apps Manager)")
        echo -e "${RED}✗ GAM not found at: $gam_path${NC}"
        log_error "GAM not found at: $gam_path"
    fi
    
    echo ""
    echo -e "${CYAN}Backup & Cloud Tools:${NC}"
    
    # Check GYB (Got Your Back)
    if command -v gyb >/dev/null 2>&1; then
        local gyb_version=$(gyb --version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}✓ GYB (Got Your Back): $gyb_version${NC}"
        optional_tools+=("GYB for Gmail backups")
        log_info "GYB found: $gyb_version"
    else
        recommendations+=("Install GYB for Gmail backups: https://github.com/GAM-team/got-your-back")
        echo -e "${YELLOW}○ GYB not found - install for Gmail backup capabilities${NC}"
        log_info "GYB not found - Gmail backup capabilities limited"
    fi
    
    # Check rclone
    if command -v rclone >/dev/null 2>&1; then
        local rclone_version=$(rclone version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        echo -e "${GREEN}✓ rclone: $rclone_version${NC}"
        optional_tools+=("rclone for cloud storage")
        log_info "rclone found: $rclone_version"
        
        # Check if rclone has any remotes configured (with timeout handling)
        if command -v timeout >/dev/null 2>&1; then
            if timeout 5 rclone listremotes 2>/dev/null | grep -q ":"; then
                echo -e "${GREEN}  ✓ rclone has configured remotes${NC}"
                log_info "rclone has configured remotes"
            else
                recommendations+=("Configure rclone remotes for cloud backup: rclone config")
                log_info "rclone found but no remotes configured or check timed out"
            fi
        else
            echo -e "${YELLOW}  ○ rclone found - remote check skipped${NC}"
            recommendations+=("Configure rclone remotes for cloud backup: rclone config")
            log_info "rclone found but remote check skipped (timeout not available)"
        fi
    else
        recommendations+=("Install rclone for cloud storage integration: https://rclone.org/install/")
        echo -e "${YELLOW}○ rclone not found - install for cloud backup capabilities${NC}"
        log_info "rclone not found - cloud backup capabilities limited"
    fi
    
    # Check restic
    if command -v restic >/dev/null 2>&1; then
        local restic_version=$(restic version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${GREEN}✓ restic: $restic_version${NC}"
        optional_tools+=("restic for encrypted backups")
        log_info "restic found: $restic_version"
    else
        recommendations+=("Install restic for encrypted incremental backups: https://restic.net/")
        echo -e "${YELLOW}○ restic not found - install for encrypted backup capabilities${NC}"
        log_info "restic not found - encrypted backup capabilities limited"
    fi
    
    echo ""
    echo -e "${CYAN}System Tools:${NC}"
    
    # Optional dependencies
    if command -v expect >/dev/null 2>&1; then
        echo -e "${GREEN}✓ expect (deployment automation)${NC}"
        log_info "expect found - deployment automation available"
    else
        warnings+=("expect - needed for automated deployment")
        log_info "expect not found - manual deployment required"
    fi
    
    if command -v curl >/dev/null 2>&1; then
        echo -e "${GREEN}✓ curl${NC}"
        log_info "curl found"
    else
        warnings+=("curl - useful for web requests")
        log_info "curl not found"
    fi
    
    if command -v jq >/dev/null 2>&1; then
        echo -e "${GREEN}✓ jq (JSON processing)${NC}"
        log_info "jq found - JSON processing available"
    else
        recommendations+=("Install jq for enhanced JSON processing: apt install jq / brew install jq")
        echo -e "${YELLOW}○ jq not found - install for enhanced JSON processing${NC}"
        log_info "jq not found - JSON processing limited"
    fi
    
    # Display results
    echo ""
    echo -e "${BLUE}=== Dependency Check Results ===${NC}"
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All essential dependencies satisfied${NC}"
        log_info "All essential dependencies satisfied"
    else
        echo -e "${RED}✗ Missing essential dependencies:${NC}"
        printf '  - %s\n' "${missing_deps[@]}"
        echo ""
        echo -e "${YELLOW}See REQUIREMENTS.md for installation instructions${NC}"
        log_error "Missing essential dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Optional dependencies missing:${NC}"
        printf '  - %s\n' "${warnings[@]}"
        log_info "Optional dependencies missing: ${warnings[*]}"
    fi
    
    if [[ ${#optional_tools[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Available optional tools:${NC}"
        printf '  - %s\n' "${optional_tools[@]}"
        log_info "Available optional tools: ${optional_tools[*]}"
    fi
    
    if [[ ${#recommendations[@]} -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}💡 Recommendations for enhanced functionality:${NC}"
        printf '  - %s\n' "${recommendations[@]}"
        log_info "Recommendations provided: ${#recommendations[@]} items"
    fi
    
    echo ""
    log_info "Dependency check completed successfully"
    return 0
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Advanced Logging Functions
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" >> "$LOG_FILE"
    if [[ "${2:-}" == "console" ]]; then
        echo -e "${CYAN}[INFO]${NC} $message"
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" >> "$LOG_FILE"
    echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
    echo -e "${RED}[ERROR]${NC} $message"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $message" >> "$LOG_FILE"
    if [[ "${2:-}" == "console" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} $message"
    fi
}

log_operation() {
    local operation="$1"
    local user="$2"
    local status="$3"
    local details="${4:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$status] $operation | User: $user | Details: $details" >> "$OPERATION_LOG"
    echo "[$timestamp] [OPERATION] $operation for $user - $status" >> "$LOG_FILE"
    
    # Also log to audit log for compliance
    echo "[$timestamp] | Session: $SESSION_ID | Operation: $operation | User: $user | Status: $status | Details: $details" >> "$AUDIT_LOG"
}

log_performance() {
    local operation="$1"
    local duration="$2"
    local user_count="${3:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] Operation: $operation | Duration: ${duration}s | Users: $user_count | Rate: $(echo "scale=2; $user_count / $duration" | bc 2>/dev/null || echo "N/A") users/sec" >> "$PERFORMANCE_LOG"
}

start_operation_timer() {
    OPERATION_START_TIME=$(date +%s)
}

end_operation_timer() {
    local operation="$1"
    local user_count="${2:-1}"
    local end_time=$(date +%s)
    local duration=$((end_time - OPERATION_START_TIME))
    log_performance "$operation" "$duration" "$user_count"
}

create_backup() {
    local user="$1"
    local operation="$2"
    local backup_file="${BACKUP_DIR}/${user}-${operation}-$(date +%Y%m%d_%H%M%S).json"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN: Would create backup for $user at $backup_file"
        return 0
    fi
    
    log_info "Creating backup for user $user"
    
    # Create backup of user information
    {
        echo "{"
        echo "  \"user\": \"$user\","
        echo "  \"operation\": \"$operation\","
        echo "  \"timestamp\": \"$(date -Iseconds)\","
        echo "  \"session_id\": \"$SESSION_ID\","
        echo "  \"user_info\": {"
        
        local user_info=$($GAM info user "$user" 2>/dev/null || echo "User not found")
        if [[ "$user_info" != "User not found" ]]; then
            local lastname=$(echo "$user_info" | grep "Last Name:" | awk -F': ' '{print $2}' | sed 's/"/\\"/g')
            local firstname=$(echo "$user_info" | grep "First Name:" | awk -F': ' '{print $2}' | sed 's/"/\\"/g')
            local suspended=$(echo "$user_info" | grep "Account Suspended:" | awk -F': ' '{print $2}')
            local orgunit=$(echo "$user_info" | grep "Org Unit Path:" | awk -F': ' '{print $2}' | sed 's/"/\\"/g')
            local department=$(echo "$user_info" | grep "Department:" | awk -F': ' '{print $2}' | sed 's/"/\\"/g')
            
            echo "    \"first_name\": \"${firstname:-}\","
            echo "    \"last_name\": \"${lastname:-}\","
            echo "    \"suspended\": \"${suspended:-}\","
            echo "    \"org_unit\": \"${orgunit:-}\","
            echo "    \"department\": \"${department:-}\""
        else
            echo "    \"error\": \"User not found\""
        fi
        
        echo "  }"
        echo "}"
    } > "$backup_file"
    
    if [[ -f "$backup_file" ]]; then
        log_info "Backup created successfully: $backup_file"
        echo "$backup_file"
    else
        log_error "Failed to create backup for $user"
        return 1
    fi
}

generate_operation_summary() {
    local total_users="$1"
    local operation="$2"
    local success_count="$3"
    local error_count="$4"
    local skip_count="$5"
    
    {
        echo "=== OPERATION SUMMARY ==="
        echo "Session ID: $SESSION_ID"
        echo "Timestamp: $(date)"
        echo "Operation: $operation"
        echo "Total Users Processed: $total_users"
        echo "Successful: $success_count"
        echo "Errors: $error_count"
        echo "Skipped: $skip_count"
        echo "Success Rate: $(echo "scale=2; $success_count * 100 / $total_users" | bc 2>/dev/null || echo "N/A")%"
        echo ""
        echo "=== DETAILS ==="
        
        # Extract relevant log entries for this session
        grep "Session: $SESSION_ID" "$AUDIT_LOG" 2>/dev/null | while read -r line; do
            echo "$line"
        done
        
    } > "$OPERATION_SUMMARY"
    
    log_info "Operation summary generated: $OPERATION_SUMMARY"
}

generate_daily_report() {
    local report_date=$(date +%Y-%m-%d)
    
    {
        echo "=== DAILY ACTIVITY REPORT ==="
        echo "Date: $report_date"
        echo "Generated: $(date)"
        echo ""
        
        echo "=== SESSION SUMMARY ==="
        local session_count=$(grep -c "SESSION START" "${LOG_DIR}"/session-*-*.log 2>/dev/null || echo "0")
        echo "Total Sessions: $session_count"
        echo ""
        
        echo "=== OPERATIONS SUMMARY ==="
        if [[ -f "$OPERATION_LOG" ]]; then
            echo "Total Operations: $(wc -l < "$OPERATION_LOG" 2>/dev/null || echo "0")"
            echo ""
            echo "Operations by Type:"
            grep -o "add_gwombat_hold\|remove_gwombat_hold\|add_pending\|remove_pending" "$OPERATION_LOG" 2>/dev/null | sort | uniq -c | sort -nr || echo "No operations found"
            echo ""
            echo "Operations by Status:"
            grep -o "SUCCESS\|ERROR\|SKIPPED" "$OPERATION_LOG" 2>/dev/null | sort | uniq -c | sort -nr || echo "No status data"
        else
            echo "No operations logged today"
        fi
        echo ""
        
        echo "=== ERROR SUMMARY ==="
        if [[ -f "$ERROR_LOG" ]]; then
            local error_count=$(wc -l < "$ERROR_LOG" 2>/dev/null || echo "0")
            echo "Total Errors: $error_count"
            if [[ $error_count -gt 0 ]]; then
                echo ""
                echo "Recent Errors:"
                tail -10 "$ERROR_LOG" 2>/dev/null || echo "Cannot read error log"
            fi
        else
            echo "No errors logged today"
        fi
        echo ""
        
        echo "=== PERFORMANCE SUMMARY ==="
        if [[ -f "$PERFORMANCE_LOG" ]]; then
            echo "Performance Data Available: Yes"
            local avg_duration=$(awk -F'Duration: |s' '{sum += $2; count++} END {print (count > 0 ? sum/count : 0)}' "$PERFORMANCE_LOG" 2>/dev/null || echo "N/A")
            echo "Average Operation Duration: ${avg_duration}s"
        else
            echo "No performance data available"
        fi
        
    } > "$DAILY_SUMMARY"
    
    log_info "Daily report generated: $DAILY_SUMMARY"
    echo -e "${GREEN}Daily report generated: $DAILY_SUMMARY${NC}"
}

cleanup_logs() {
    local days_to_keep="${1:-30}"
    log_info "Starting log cleanup (keeping $days_to_keep days)"
    
    # Clean up old log files
    find "$LOG_DIR" -name "*.log" -type f -mtime +$days_to_keep -delete 2>/dev/null
    find "$REPORT_DIR" -name "*.txt" -type f -mtime +$days_to_keep -delete 2>/dev/null
    find "$BACKUP_DIR" -name "*.json" -type f -mtime +$days_to_keep -delete 2>/dev/null
    
    log_info "Log cleanup completed"
}

# Database backup functions
create_database_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/account_lifecycle_${timestamp}.db.gz"
    local db_file="${SCRIPTPATH}/local-config/local-config/account_lifecycle.db"
    
    echo -e "${CYAN}Creating database backup...${NC}"
    
    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"
    
    # Check if database exists
    if [[ ! -f "$db_file" ]]; then
        echo -e "${RED}Database file not found: $db_file${NC}"
        return 1
    fi
    
    # Create compressed backup
    if gzip -c "$db_file" > "$backup_file"; then
        echo -e "${GREEN}✅ Database backup created: $backup_file${NC}"
        log_info "Database backup created: $backup_file"
        
        # Get backup size
        local backup_size=$(du -h "$backup_file" | cut -f1)
        echo -e "${CYAN}Backup size: $backup_size${NC}"
        
        return 0
    else
        echo -e "${RED}❌ Failed to create database backup${NC}"
        return 1
    fi
}

upload_backup_to_drive() {
    local latest_backup=$(ls -t "$BACKUP_DIR"/*.db.gz 2>/dev/null | head -1)
    
    if [[ -z "$latest_backup" ]]; then
        echo -e "${RED}No database backup found to upload${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Uploading backup to Google Drive...${NC}"
    
    # Use GAM to upload to admin user's drive
    local admin_email="${ADMIN_EMAIL:-admin@${DOMAIN:-yourdomain.edu}}"
    local backup_filename=$(basename "$latest_backup")
    
    if $GAM user "$admin_email" add drivefile localfile "$latest_backup" drivefilename "GWOMBAT_DB_Backup_$backup_filename" parentname "GWOMBAT Backups" 2>/dev/null; then
        echo -e "${GREEN}✅ Backup uploaded to Google Drive successfully${NC}"
        log_info "Database backup uploaded to Google Drive: $backup_filename"
        return 0
    else
        echo -e "${YELLOW}⚠️  Failed to upload to Google Drive (folder may not exist)${NC}"
        echo -e "${CYAN}Trying upload to root Drive folder...${NC}"
        
        if $GAM user "$admin_email" add drivefile localfile "$latest_backup" drivefilename "GWOMBAT_DB_Backup_$backup_filename" 2>/dev/null; then
            echo -e "${GREEN}✅ Backup uploaded to Google Drive root folder${NC}"
            log_info "Database backup uploaded to Google Drive root: $backup_filename"
            return 0
        else
            echo -e "${RED}❌ Failed to upload backup to Google Drive${NC}"
            return 1
        fi
    fi
}

cleanup_database_backups() {
    local days_to_keep="${1:-5}"
    
    echo -e "${CYAN}Cleaning up database backups older than $days_to_keep days...${NC}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${YELLOW}No backup directory found${NC}"
        return 0
    fi
    
    # Count backups before cleanup
    local before_count=$(ls "$BACKUP_DIR"/*.db.gz 2>/dev/null | wc -l)
    
    # Remove old backups
    find "$BACKUP_DIR" -name "*.db.gz" -type f -mtime +$days_to_keep -delete 2>/dev/null
    
    # Count backups after cleanup
    local after_count=$(ls "$BACKUP_DIR"/*.db.gz 2>/dev/null | wc -l)
    local removed_count=$((before_count - after_count))
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
    echo -e "${CYAN}Removed $removed_count old backups, $after_count backups remaining${NC}"
    
    log_info "Database backup cleanup: removed $removed_count backups, $after_count remaining"
}

restore_database_backup() {
    echo -e "${CYAN}Available database backups:${NC}"
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo -e "${RED}No backup directory found${NC}"
        return 1
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/*.db.gz 2>/dev/null))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${RED}No database backups found${NC}"
        return 1
    fi
    
    # List available backups
    local i=1
    for backup in "${backups[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_date=$(date -r "$backup" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown date")
        local backup_size=$(du -h "$backup" | cut -f1)
        echo "$i. $backup_name ($backup_date) - $backup_size"
        ((i++))
    done
    
    echo ""
    read -p "Select backup to restore (1-${#backups[@]}): " backup_choice
    
    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ $backup_choice -lt 1 ]] || [[ $backup_choice -gt ${#backups[@]} ]]; then
        echo -e "${RED}Invalid selection${NC}"
        return 1
    fi
    
    local selected_backup="${backups[$((backup_choice-1))]}"
    local db_file="${SCRIPTPATH}/local-config/local-config/account_lifecycle.db"
    local backup_of_current="${db_file}.backup_$(date +%Y%m%d_%H%M%S)"
    
    echo ""
    echo -e "${YELLOW}⚠️  WARNING: This will replace the current database!${NC}"
    echo -e "${CYAN}Current database will be backed up to: $(basename "$backup_of_current")${NC}"
    echo ""
    read -p "Are you sure you want to restore from backup? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        echo -e "${YELLOW}Restore cancelled${NC}"
        return 0
    fi
    
    # Backup current database if it exists
    if [[ -f "$db_file" ]]; then
        if cp "$db_file" "$backup_of_current"; then
            echo -e "${GREEN}✅ Current database backed up${NC}"
        else
            echo -e "${RED}❌ Failed to backup current database${NC}"
            return 1
        fi
    fi
    
    # Restore from backup
    if gunzip -c "$selected_backup" > "$db_file"; then
        echo -e "${GREEN}✅ Database restored successfully from backup${NC}"
        log_info "Database restored from backup: $(basename "$selected_backup")"
        return 0
    else
        echo -e "${RED}❌ Failed to restore database from backup${NC}"
        # Try to restore the backup we just made
        if [[ "$backup_of_current" ]]; then
            cp "$backup_of_current" "$db_file"
            echo -e "${YELLOW}Current database restored from backup${NC}"
        fi
        return 1
    fi
}

# Function for reports and cleanup menu
reports_and_cleanup_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Reports and Maintenance ===${NC}"
        echo ""
        echo "1. Generate daily activity report"
        echo "2. Generate operation summary for current session"
        echo "3. View current session log"
        echo "4. View error log"
        echo "5. View performance statistics"
        echo "6. Clean up old logs (30+ days)"
        echo "7. Clean up old logs (custom days)"
        echo "8. Database backup management"
        echo "9. Configuration management"
        echo "10. Audit file ownership locations"
        echo ""
        echo "p. Previous menu (Main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-10, p, m, x): " report_choice
        echo ""
        
        case $report_choice in
            1)
                echo -e "${CYAN}Generating daily activity report...${NC}"
                generate_daily_report
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${CYAN}Generating operation summary for session $SESSION_ID...${NC}"
                # Count operations from current session
                local session_ops=$(grep "Session: $SESSION_ID" "$AUDIT_LOG" 2>/dev/null | wc -l || echo "0")
                local success_count=$(grep "Session: $SESSION_ID.*SUCCESS" "$AUDIT_LOG" 2>/dev/null | wc -l || echo "0")
                local error_count=$(grep "Session: $SESSION_ID.*ERROR" "$AUDIT_LOG" 2>/dev/null | wc -l || echo "0")
                local skip_count=$(grep "Session: $SESSION_ID.*SKIPPED\|Session: $SESSION_ID.*DRY-RUN" "$AUDIT_LOG" 2>/dev/null | wc -l || echo "0")
                
                generate_operation_summary "$session_ops" "current_session" "$success_count" "$error_count" "$skip_count"
                echo -e "${GREEN}Operation summary generated: $OPERATION_SUMMARY${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${CYAN}Current session log:${NC}"
                echo "Session ID: $SESSION_ID"
                echo "Log file: $LOG_FILE"
                echo ""
                if [[ -f "$LOG_FILE" ]]; then
                    tail -20 "$LOG_FILE"
                    echo ""
                    echo -e "${YELLOW}(Showing last 20 lines)${NC}"
                else
                    echo "No session log found"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${CYAN}Recent errors:${NC}"
                if [[ -f "$ERROR_LOG" ]]; then
                    tail -10 "$ERROR_LOG"
                    echo ""
                    echo -e "${YELLOW}(Showing last 10 errors)${NC}"
                else
                    echo "No errors logged today"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Performance statistics:${NC}"
                if [[ -f "$PERFORMANCE_LOG" ]]; then
                    cat "$PERFORMANCE_LOG"
                    echo ""
                    local avg_duration=$(awk -F'Duration: |s' '{sum += $2; count++} END {print (count > 0 ? sum/count : 0)}' "$PERFORMANCE_LOG" 2>/dev/null || echo "N/A")
                    echo -e "${GREEN}Average operation duration: ${avg_duration}s${NC}"
                else
                    echo "No performance data available"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo -e "${CYAN}Cleaning up logs older than 30 days...${NC}"
                cleanup_logs 30
                echo -e "${GREEN}Cleanup completed${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                read -p "Enter number of days to keep: " custom_days
                if [[ "$custom_days" =~ ^[0-9]+$ ]]; then
                    echo -e "${CYAN}Cleaning up logs older than $custom_days days...${NC}"
                    cleanup_logs "$custom_days"
                    echo -e "${GREEN}Cleanup completed${NC}"
                else
                    echo -e "${RED}Invalid number of days${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                echo -e "${CYAN}Database Backup Management${NC}"
                echo ""
                echo "1. Create database backup now"
                echo "2. Create backup and upload to Google Drive"
                echo "3. View recent backups"
                echo "4. Clean up old backups (keep 5 days)"
                echo "5. Restore from backup"
                echo ""
                read -p "Select backup option (1-5): " backup_choice
                case $backup_choice in
                    1)
                        create_database_backup
                        ;;
                    2)
                        create_database_backup
                        upload_backup_to_drive
                        ;;
                    3)
                        echo -e "${CYAN}Recent database backups:${NC}"
                        if [[ -d "$BACKUP_DIR" ]]; then
                            ls -la "$BACKUP_DIR"/*.db.gz 2>/dev/null | tail -10
                            echo ""
                            echo -e "${YELLOW}(Showing 10 most recent database backups)${NC}"
                        else
                            echo "No backup directory found"
                        fi
                        ;;
                    4)
                        cleanup_database_backups 5
                        ;;
                    5)
                        restore_database_backup
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                configuration_menu
                ;;
            16)
                audit_file_ownership_menu
                ;;
            p|P)
                return  # Previous menu
                ;;
            m|M)
                return  # Main menu (since this is called from main)
                ;;
            x|X)
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-10, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Configuration management menu
configuration_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Configuration Management ===${NC}"
        echo ""
        
        # Show domain configuration prominently
        echo -e "${CYAN}🌐 Domain Configuration:${NC}"
        if [[ -n "$DOMAIN" ]]; then
            echo -e "${GREEN}  Domain: ${BOLD}$DOMAIN${NC}"
            if [[ -n "$ADMIN_USER" ]]; then
                echo -e "${GREEN}  Admin User: $ADMIN_USER${NC}"
            fi
            if [[ -n "$ADMIN_EMAIL" ]]; then
                echo -e "${GREEN}  Admin Email: $ADMIN_EMAIL${NC}"
            fi
        else
            echo -e "${YELLOW}  ⚠️ No domain configured${NC}"
        fi
        echo ""
        
        echo -e "${CYAN}System Configuration:${NC}"
        echo "  GAM Path: $GAM"
        echo "  Script Path: $SCRIPTPATH"
        echo "  Progress Enabled: $PROGRESS_ENABLED"
        echo "  Confirmation Level: $CONFIRMATION_LEVEL"
        echo "  Log Retention: $LOG_RETENTION_DAYS days"
        echo "  Operation Timeout: $OPERATION_TIMEOUT seconds"
        echo ""
        
        echo -e "${CYAN}Configuration Options:${NC}"
        echo "1. 🧙 Setup Wizard (First-time or reconfiguration)"
        echo "2. 🔄 Configure New Domain (backup current config)"
        echo "3. 🐍 Setup Python Environment"
        echo "4. 💾 Backup Current Configuration"
        echo "5. 📁 Restore Configuration from Backup"
        echo "6. View full configuration file"
        echo "7. Create default configuration file"
        echo "8. Edit GAM path"
        echo "9. Edit script paths"
        echo "10. Toggle progress display"
        echo "11. Change confirmation level"
        echo "12. Set log retention"
        echo "13. Test configuration"
        echo "14. 🔒 Show GAM configuration and domain info"
        echo "15. Reset to defaults"
        echo ""
        echo "p. Previous menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-15, p, m, x): " config_choice
        echo ""
        
        case $config_choice in
            1)
                # Setup Wizard
                echo -e "${CYAN}Running Setup Wizard...${NC}"
                if [[ -x "./setup_wizard.sh" ]]; then
                    ./setup_wizard.sh
                else
                    echo -e "${RED}Setup wizard not found at ./setup_wizard.sh${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                # Configure New Domain with Backup
                echo -e "${CYAN}Configure New Domain${NC}"
                echo ""
                if [[ -n "$DOMAIN" ]]; then
                    echo -e "${YELLOW}⚠️ Current domain: $DOMAIN${NC}"
                    echo ""
                    echo "Configuring a new domain will:"
                    echo "• Backup current configuration and database"
                    echo "• Reset GWOMBAT for the new domain"
                    echo "• Preserve all existing data safely"
                    echo ""
                    read -p "Continue with domain change? (y/N): " confirm_domain_change
                    if [[ "$confirm_domain_change" =~ ^[Yy]$ ]]; then
                        # Create backup
                        local backup_timestamp=$(date +%Y%m%d-%H%M%S)
                        local backup_dir="./backups/domain-backup-${DOMAIN}-${backup_timestamp}"
                        mkdir -p "$backup_dir"
                        
                        echo "Creating backup in $backup_dir..."
                        
                        # Backup configuration files
                        [[ -f ".env" ]] && cp ".env" "$backup_dir/"
                        [[ -f "local-config/server.env" ]] && cp "local-config/server.env" "$backup_dir/"
                        [[ -f "$CONFIG_FILE" ]] && cp "$CONFIG_FILE" "$backup_dir/"
                        
                        # Backup database
                        [[ -f "local-config/account_lifecycle.db" ]] && cp "local-config/account_lifecycle.db" "$backup_dir/"
                        
                        # Backup any local-config/reports/logs
                        [[ -d "reports" ]] && cp -r "reports" "$backup_dir/"
                        [[ -d "logs" ]] && cp -r "logs" "$backup_dir/" 2>/dev/null || true
                        
                        echo -e "${GREEN}✓ Backup created: $backup_dir${NC}"
                        echo ""
                        
                        # Run setup wizard for new domain
                        echo "Starting setup wizard for new domain..."
                        if [[ -x "./setup_wizard.sh" ]]; then
                            ./setup_wizard.sh
                        else
                            echo -e "${RED}Setup wizard not found${NC}"
                        fi
                    else
                        echo "Domain change cancelled."
                    fi
                else
                    echo "No current domain configured. Running setup wizard..."
                    if [[ -x "./setup_wizard.sh" ]]; then
                        ./setup_wizard.sh
                    else
                        echo -e "${RED}Setup wizard not found${NC}"
                    fi
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                # Python Environment Setup
                echo -e "${CYAN}Setting up Python Environment...${NC}"
                if [[ -x "./setup_wizard.sh" ]]; then
                    ./setup_wizard.sh python
                else
                    echo -e "${RED}Setup wizard not found at ./setup_wizard.sh${NC}"
                    echo "You can install Python packages manually with:"
                    echo "pip3 install -r python-modules/requirements.txt"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                # Backup Current Configuration
                echo -e "${CYAN}Backup Current Configuration${NC}"
                echo ""
                local backup_timestamp=$(date +%Y%m%d-%H%M%S)
                local backup_dir="./backups/config-backup-${backup_timestamp}"
                mkdir -p "$backup_dir"
                
                echo "Creating configuration backup..."
                echo "Backup location: $backup_dir"
                echo ""
                
                # Backup configuration files
                local files_backed_up=0
                if [[ -f ".env" ]]; then
                    cp ".env" "$backup_dir/"
                    echo "  ✓ .env"
                    ((files_backed_up++))
                fi
                if [[ -f "local-config/server.env" ]]; then
                    cp "local-config/server.env" "$backup_dir/"
                    echo "  ✓ local-config/server.env"
                    ((files_backed_up++))
                fi
                if [[ -f "$CONFIG_FILE" ]]; then
                    cp "$CONFIG_FILE" "$backup_dir/"
                    echo "  ✓ gwombat-config.json"
                    ((files_backed_up++))
                fi
                if [[ -f "local-config/account_lifecycle.db" ]]; then
                    cp "local-config/account_lifecycle.db" "$backup_dir/"
                    echo "  ✓ local-config/account_lifecycle.db"
                    ((files_backed_up++))
                fi
                
                echo ""
                echo -e "${GREEN}✓ Backup completed: $files_backed_up files saved${NC}"
                echo "Backup location: $backup_dir"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                # Restore Configuration from Backup
                echo -e "${CYAN}Restore Configuration from Backup${NC}"
                echo ""
                
                if [[ -d "./backups" ]]; then
                    echo "Available backups:"
                    local backup_dirs=(./backups/*/)
                    if [[ ${#backup_dirs[@]} -gt 0 && -d "${backup_dirs[0]}" ]]; then
                        local i=1
                        for backup_dir in "${backup_dirs[@]}"; do
                            local backup_name=$(basename "$backup_dir")
                            echo "$i. $backup_name"
                            ((i++))
                        done
                        echo ""
                        read -p "Select backup to restore (1-$((i-1)), or Enter to cancel): " backup_choice
                        
                        if [[ "$backup_choice" =~ ^[0-9]+$ ]] && [[ "$backup_choice" -ge 1 ]] && [[ "$backup_choice" -lt "$i" ]]; then
                            local selected_backup="${backup_dirs[$((backup_choice-1))]}"
                            echo ""
                            echo -e "${YELLOW}⚠️ This will overwrite current configuration${NC}"
                            read -p "Continue with restore? (y/N): " confirm_restore
                            
                            if [[ "$confirm_restore" =~ ^[Yy]$ ]]; then
                                echo "Restoring from $selected_backup..."
                                
                                # Restore files
                                [[ -f "$selected_backup/.env" ]] && cp "$selected_backup/.env" "./" && echo "  ✓ .env restored"
                                [[ -f "$selected_backup/local-config/server.env" ]] && cp "$selected_backup/local-config/server.env" "./" && echo "  ✓ local-config/server.env restored"
                                [[ -f "$selected_backup/gwombat-config.json" ]] && cp "$selected_backup/gwombat-config.json" "$CONFIG_FILE" && echo "  ✓ config restored"
                                [[ -f "$selected_backup/local-config/account_lifecycle.db" ]] && cp "$selected_backup/local-config/account_lifecycle.db" "./" && echo "  ✓ database restored"
                                
                                echo ""
                                echo -e "${GREEN}✓ Configuration restored successfully${NC}"
                                echo -e "${YELLOW}Please restart GWOMBAT to reload configuration${NC}"
                            else
                                echo "Restore cancelled."
                            fi
                        else
                            echo "Invalid selection or cancelled."
                        fi
                    else
                        echo "No backups found in ./backups/"
                    fi
                else
                    echo "No backups directory found."
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo -e "${CYAN}Configuration file contents:${NC}"
                if [[ -f "$CONFIG_FILE" ]]; then
                    cat "$CONFIG_FILE"
                else
                    echo "No configuration file found at $CONFIG_FILE"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${CYAN}Creating default configuration file...${NC}"
                create_default_config
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                echo "Current GAM path: $GAM"
                read -p "Enter new GAM path: " new_gam_path
                if [[ -x "$new_gam_path" ]]; then
                    GAM="$new_gam_path"
                    echo -e "${GREEN}GAM path updated to: $GAM${NC}"
                    log_info "GAM path updated to: $GAM"
                else
                    echo -e "${RED}Warning: File not found or not executable: $new_gam_path${NC}"
                    echo -e "${YELLOW}Update anyway? (y/n)${NC}"
                    read -p "> " confirm
                    if [[ "$confirm" =~ ^[Yy] ]]; then
                        GAM="$new_gam_path"
                        echo -e "${GREEN}GAM path updated to: $GAM${NC}"
                        log_warning "GAM path updated to non-executable file: $GAM"
                    fi
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Current script path: $SCRIPTPATH"
                read -p "Enter new script path: " new_script_path
                if [[ -d "$new_script_path" ]]; then
                    SCRIPTPATH="$new_script_path"
                    echo -e "${GREEN}Script path updated to: $SCRIPTPATH${NC}"
                    log_info "Script path updated to: $SCRIPTPATH"
                else
                    echo -e "${RED}Warning: Directory not found: $new_script_path${NC}"
                    echo -e "${YELLOW}Update anyway? (y/n)${NC}"
                    read -p "> " confirm
                    if [[ "$confirm" =~ ^[Yy] ]]; then
                        SCRIPTPATH="$new_script_path"
                        echo -e "${GREEN}Script path updated to: $SCRIPTPATH${NC}"
                        log_warning "Script path updated to non-existent directory: $SCRIPTPATH"
                    fi
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo "Current progress setting: $PROGRESS_ENABLED"
                if [[ "$PROGRESS_ENABLED" == "true" ]]; then
                    PROGRESS_ENABLED="false"
                    echo -e "${GREEN}Progress display disabled${NC}"
                else
                    PROGRESS_ENABLED="true"
                    echo -e "${GREEN}Progress display enabled${NC}"
                fi
                log_info "Progress display setting changed to: $PROGRESS_ENABLED"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            16)
                echo "Current confirmation level: $CONFIRMATION_LEVEL"
                echo "Available levels: normal, high, minimal"
                read -p "Enter new confirmation level: " new_level
                case $new_level in
                    "normal"|"high"|"minimal")
                        CONFIRMATION_LEVEL="$new_level"
                        echo -e "${GREEN}Confirmation level updated to: $CONFIRMATION_LEVEL${NC}"
                        log_info "Confirmation level updated to: $CONFIRMATION_LEVEL"
                        ;;
                    *)
                        echo -e "${RED}Invalid confirmation level. Use: normal, high, or minimal${NC}"
                        ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                echo "Current log retention: $LOG_RETENTION_DAYS days"
                read -p "Enter new log retention (days): " new_retention
                if [[ "$new_retention" =~ ^[0-9]+$ ]]; then
                    LOG_RETENTION_DAYS="$new_retention"
                    echo -e "${GREEN}Log retention updated to: $LOG_RETENTION_DAYS days${NC}"
                    log_info "Log retention updated to: $LOG_RETENTION_DAYS days"
                else
                    echo -e "${RED}Invalid number: $new_retention${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo "Current backup retention: $BACKUP_RETENTION_DAYS days"
                read -p "Enter new backup retention (days): " new_backup_retention
                if [[ "$new_backup_retention" =~ ^[0-9]+$ ]]; then
                    BACKUP_RETENTION_DAYS="$new_backup_retention"
                    echo -e "${GREEN}Backup retention updated to: $BACKUP_RETENTION_DAYS days${NC}"
                    log_info "Backup retention updated to: $BACKUP_RETENTION_DAYS days"
                else
                    echo -e "${RED}Invalid number: $new_backup_retention${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${CYAN}Testing configuration...${NC}"
                echo ""
                
                # Test GAM
                echo -n "Testing GAM access: "
                if [[ -x "$GAM" ]]; then
                    if timeout 10 "$GAM" version >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ GAM is accessible and working${NC}"
                    else
                        echo -e "${YELLOW}⚠ GAM executable found but may not be configured properly${NC}"
                    fi
                else
                    echo -e "${RED}✗ GAM not found or not executable at: $GAM${NC}"
                fi
                
                # Test directories
                echo -n "Testing script directory: "
                if [[ -d "$SCRIPTPATH" ]]; then
                    echo -e "${GREEN}✓ Directory exists: $SCRIPTPATH${NC}"
                else
                    echo -e "${RED}✗ Directory not found: $SCRIPTPATH${NC}"
                fi
                
                echo -n "Testing listshared directory: "
                if [[ -d "$SHARED_UTILITIES_PATH" ]]; then
                    echo -e "${GREEN}✓ Directory exists: $SHARED_UTILITIES_PATH${NC}"
                else
                    echo -e "${RED}✗ Directory not found: $SHARED_UTILITIES_PATH${NC}"
                fi
                
                # Test log directories
                echo -n "Testing log directories: "
                if [[ -d "$LOG_DIR" && -d "$BACKUP_DIR" && -d "$REPORT_DIR" ]]; then
                    echo -e "${GREEN}✓ All log directories exist${NC}"
                else
                    echo -e "${YELLOW}⚠ Some log directories missing (will be created)${NC}"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                show_gam_info
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo -e "${YELLOW}This will reset all configuration to defaults. Continue? (y/n)${NC}"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy] ]]; then
                    load_configuration
                    echo -e "${GREEN}Configuration reset to defaults${NC}"
                    log_info "Configuration reset to defaults"
                else
                    echo "Reset cancelled"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            p|P)
                return
                ;;
            m|M)
                return
                ;;
            x|X)
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-15, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Audit file ownership locations
audit_file_ownership() {
    local username="$1"
    
    echo -e "${BLUE}=== Auditing file ownership locations for: $username ===${NC}"
    echo ""
    
    # Validate user exists
    if ! $GAM info user "$username" >/dev/null 2>&1; then
        echo -e "${RED}Error: User $username not found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Analyzing file ownership locations...${NC}"
    echo "This may take a moment for users with many files."
    echo ""
    
    # Create a temporary file to hold user files data
    local tempfile=$(mktemp)
    local count=0
    local mismatch_count=0
    
    # Get the list of files owned by the user
    echo -e "${CYAN}Getting file list for $username...${NC}"
    if ! $GAM user "$username" print filelist id title mimeType owners.emailAddress > "$tempfile" 2>/dev/null; then
        echo -e "${RED}Error: Failed to retrieve file list for $username${NC}"
        rm -f "$tempfile"
        return 1
    fi
    
    # Check if we have any files
    local total_files=$(tail -n +2 "$tempfile" | wc -l)
    if [[ $total_files -eq 0 ]]; then
        echo -e "${YELLOW}No files found for user $username${NC}"
        rm -f "$tempfile"
        return 0
    fi
    
    echo -e "${GREEN}Found $total_files files to analyze${NC}"
    echo ""
    echo -e "${CYAN}Checking file locations...${NC}"
    
    # Check each file and the owner of its parent folder
    tail -n +2 "$tempfile" | while IFS=, read -r user fileID fileName mimeType owner; do
        ((count++))
        
        # Show progress every 10 files
        if [[ $((count % 10)) -eq 0 ]]; then
            echo -e "${CYAN}Processed $count of $total_files files...${NC}"
        fi
        
        # Get the folder ID where the file is located
        local folderID=$($GAM user "$username" show fileinfo "$fileID" 2>/dev/null | grep 'Parent ID' | cut -d' ' -f3)
        
        # If folderID is empty, skip to the next iteration
        if [[ -z "$folderID" ]]; then
            continue
        fi
        
        # Get the owner of the folder
        local folderOwner=$($GAM info fileid "$folderID" 2>/dev/null | grep 'Owner Email' | cut -d' ' -f3)
        
        # Check if the folder owner is different from the file owner
        if [[ "$folderOwner" != "$owner" && -n "$folderOwner" ]]; then
            echo -e "${YELLOW}MISMATCH: File '$fileName' ($fileID) is owned by $owner but located in folder owned by $folderOwner${NC}"
            ((mismatch_count++))
        fi
    done
    
    # Clean up the temporary file
    rm -f "$tempfile"
    
    echo ""
    echo -e "${GREEN}Analysis complete for $username${NC}"
    echo -e "${CYAN}Files analyzed: $total_files${NC}"
    echo -e "${YELLOW}Location mismatches found: $mismatch_count${NC}"
    
    if [[ $mismatch_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Note: Location mismatches may indicate:${NC}"
        echo "- Files moved to folders owned by other users"
        echo "- Shared folders where ownership differs"
        echo "- Files that may need attention during account suspension"
    fi
    
    log_info "File ownership audit completed for $username: $total_files files analyzed, $mismatch_count mismatches"
}

audit_file_ownership_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== File Ownership Audit ===${NC}"
        echo ""
        echo "This tool helps identify files owned by a user that are located"
        echo "in folders owned by different users, which may need attention"
        echo "during account suspension or transfer operations."
        echo ""
        echo "1. Audit single user"
        echo "2. Audit multiple users from file"
        echo "3. Audit multiple users (manual entry)"
        echo "4. Return to main menu"
        echo ""
        read -p "Select an option (1-4): " audit_choice
        echo ""
        
        case $audit_choice in
            1)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    audit_file_ownership "$username"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                read -p "Enter path to file containing usernames (one per line): " user_file
                if [[ -f "$user_file" ]]; then
                    echo -e "${CYAN}Processing users from file...${NC}"
                    local total_users=$(wc -l < "$user_file")
                    local current_user=0
                    
                    while read -r username; do
                        [[ -z "$username" ]] && continue
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of $total_users ===${NC}"
                        audit_file_ownership "$username"
                        echo ""
                    done < "$user_file"
                    
                    echo -e "${GREEN}Batch audit completed${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}File not found: $user_file${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                echo -e "${CYAN}Enter usernames (one per line, empty line to finish):${NC}"
                local usernames=()
                while true; do
                    read -p "Username: " username
                    [[ -z "$username" ]] && break
                    usernames+=("$username")
                done
                
                if [[ ${#usernames[@]} -gt 0 ]]; then
                    echo -e "${CYAN}Processing ${#usernames[@]} users...${NC}"
                    local current_user=0
                    
                    for username in "${usernames[@]}"; do
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of ${#usernames[@]} ===${NC}"
                        audit_file_ownership "$username"
                        echo ""
                    done
                    
                    echo -e "${GREEN}Batch audit completed${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}No usernames provided${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-4.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Dashboard and Statistics Menu
dashboard_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== 🎯 Dashboard & Statistics ===${NC}"
        echo ""
        
        # Show quick statistics at the top of the menu
        echo -e "${CYAN}Current Statistics:${NC}"
        
        # Dashboard stats
        if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
            local quick_stats=$($SHARED_UTILITIES_PATH/dashboard_functions.sh stats 2>/dev/null)
            if [[ -n "$quick_stats" ]]; then
                IFS='|' read -r suspended_total pending_deletion temporary_hold exit_row inactive_users_30d shared_drives_count <<< "$quick_stats"
                echo -e "  ${WHITE}Suspended Users:${NC} ${YELLOW}$suspended_total${NC} | ${WHITE}Pending Deletion:${NC} ${RED}$pending_deletion${NC} | ${WHITE}Shared Drives:${NC} ${GREEN}$shared_drives_count${NC}"
            fi
        fi
        
        # Security stats
        if [[ -x "$SHARED_UTILITIES_PATH/security_reports.sh" ]]; then
            local security_stats=$($SHARED_UTILITIES_PATH/security_reports.sh stats 2>/dev/null)
            if [[ -n "$security_stats" ]]; then
                IFS='|' read -r alerts_24h compliance_rate failed_logins admin_actions high_risk_oauth <<< "$security_stats"
                echo -e "  ${WHITE}Security Alerts (24h):${NC} ${RED}$alerts_24h${NC} | ${WHITE}Compliance Rate:${NC} ${GREEN}${compliance_rate}%${NC} | ${WHITE}Failed Logins:${NC} ${YELLOW}$failed_logins${NC}"
            fi
        fi
        echo ""
        
        echo -e "${GREEN}=== DASHBOARD OPTIONS ===${NC}"
        echo "1. 📊 Show Full Dashboard (Live OU statistics and system overview)"
        echo "2. 🔄 Refresh Statistics (Force refresh of all statistics)"
        echo "3. 📈 Extended Statistics Only (Inactive users, shared drives, storage)"
        echo "4. 🏥 System Health Check"
        echo ""
        echo -e "${RED}=== SECURITY REPORTS ===${NC}"
        echo "5. 🔒 Security Dashboard (GAM7 enhanced security monitoring)"
        echo "6. 🚨 Security Scans (Login activities, admin actions, compliance)"
        echo "7. 📋 Generate Security Report"
        echo ""
        # Check backup tools availability
        local backup_tools_available=false
        local gyb_available=false
        local rclone_available=false
        
        if [[ -x "$SHARED_UTILITIES_PATH/backup_tools.sh" ]]; then
            backup_tools_available=true
            # Check individual tool availability
            if command -v "${GYB_PATH:-gyb}" >/dev/null 2>&1; then
                gyb_available=true
            fi
            if command -v "${RCLONE_PATH:-rclone}" >/dev/null 2>&1; then
                rclone_available=true
            fi
        fi
        
        echo -e "${BLUE}=== BACKUP TOOLS ===${NC}"
        if [[ "$backup_tools_available" == "true" ]]; then
            echo "8. 💾 Backup Tools Status (GYB and rclone integration)"
        else
            echo -e "${GRAY}8. 💾 Backup Tools Status (Not available - backup_tools.sh missing)${NC}"
        fi
        
        if [[ "$gyb_available" == "true" ]]; then
            echo "9. 📧 Gmail Backup Operations"
        else
            echo -e "${GRAY}9. 📧 Gmail Backup Operations (Install GYB: pip install gyb)${NC}"
        fi
        
        if [[ "$rclone_available" == "true" ]]; then
            echo "10. ☁️  Cloud Storage Operations"
        else
            echo -e "${GRAY}10. ☁️  Cloud Storage Operations (Install rclone: https://rclone.org/install/)${NC}"
        fi
        
        if [[ "$backup_tools_available" == "true" ]]; then
            echo "11. 🔧 Backup User on Suspension"
        else
            echo -e "${GRAY}11. 🔧 Backup User on Suspension (Requires backup tools)${NC}"
        fi
        echo ""
        echo -e "${PURPLE}=== CONFIGURATION & SCHEDULING ===${NC}"
        echo "12. ⚙️  Configuration Management (Dashboard, security, scheduling settings)"
        echo "13. 🕐 Scheduler Management (Background task automation with opt-out)"
        echo ""
        echo -e "${GRAY}=== DATABASE MANAGEMENT ===${NC}"
        echo "14. 🗄️  Initialize Dashboard Database"
        echo "15. 🗄️  Initialize Backup Tools Database"
        echo "16. 🗄️  Initialize Security Reports Database"
        echo "17. 🗄️  Initialize Configuration Management Database"
        echo ""
        echo "18. ↩️  Return to main menu"
        echo ""
        echo "p. Previous menu (main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        
        # Check for 'r' to refresh
        echo -e "${GRAY}Tip: Press 'r' to refresh statistics${NC}"
        read -p "Select an option (1-18, r, p, m, x): " dashboard_choice
        echo ""
        
        case $dashboard_choice in
            1)
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}Loading full dashboard...${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh show
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}Refreshing all statistics...${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh scan
                    echo -e "${GREEN}Statistics refreshed. Showing updated dashboard...${NC}"
                    echo ""
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh show true
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}Refreshing extended statistics...${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh scan-extended
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}System Health Check:${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh health
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                # Security Dashboard
                if [[ -x "$SHARED_UTILITIES_PATH/security_reports.sh" ]]; then
                    $SHARED_UTILITIES_PATH/security_reports.sh dashboard
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Enhanced Security Reports Setup Required ===${NC}"
                    echo ""
                    echo "Enhanced Security Reports provide comprehensive security monitoring:"
                    echo "• Login activity analysis and suspicious pattern detection"
                    echo "• Admin activity monitoring and privilege change tracking"
                    echo "• Security compliance checking (2FA, password policies)"
                    echo "• OAuth application risk assessment and monitoring"
                    echo "• Automated security alerting and incident detection"
                    echo ""
                    echo -e "${CYAN}Requirements:${NC}"
                    echo "• GAM7 (GAMADV-XS3) for advanced reporting capabilities"
                    echo "• security_reports.sh in shared-utilities/"
                    echo "• Properly configured Google Workspace API access"
                    echo ""
                    echo -e "${GREEN}Once setup is complete, enhanced security monitoring will be available here.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                # Security Scans
                if [[ -x "$SHARED_UTILITIES_PATH/security_reports.sh" ]]; then
                    echo -e "${CYAN}Security Scans Menu${NC}"
                    echo ""
                    echo "1. Scan login activities (7 days)"
                    echo "2. Scan admin activities (24 hours)"
                    echo "3. Scan security compliance (2FA, passwords)"
                    echo "4. Scan OAuth applications"
                    echo "5. Run comprehensive security scan"
                    echo "6. Check GAM7 availability"
                    read -p "Select scan type (1-6): " scan_choice
                    
                    case $scan_choice in
                        1) 
                            read -p "Enter days to scan (default 7): " days
                            days="${days:-7}"
                            $SHARED_UTILITIES_PATH/security_reports.sh scan-logins "$days"
                            ;;
                        2)
                            read -p "Enter days to scan (default 1): " days
                            days="${days:-1}"
                            $SHARED_UTILITIES_PATH/security_reports.sh scan-admin "$days"
                            ;;
                        3) $SHARED_UTILITIES_PATH/security_reports.sh scan-compliance ;;
                        4) $SHARED_UTILITIES_PATH/security_reports.sh scan-oauth ;;
                        5) 
                            read -p "Enter days for login/admin scans (default 7): " days
                            days="${days:-7}"
                            $SHARED_UTILITIES_PATH/security_reports.sh scan-all "$days"
                            ;;
                        15) $SHARED_UTILITIES_PATH/security_reports.sh check-gam ;;
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Security Scanning Setup Required ===${NC}"
                    echo ""
                    echo "Security scanning provides detailed analysis of:"
                    echo "• User login patterns and failed authentication attempts"
                    echo "• Administrator actions and privilege changes"
                    echo "• Security compliance violations and policy gaps"
                    echo "• High-risk OAuth application permissions"
                    echo ""
                    echo -e "${CYAN}Setup Requirements:${NC}"
                    echo "• Install security_reports.sh in shared-utilities/"
                    echo "• Ensure GAM7 is properly configured"
                    echo "• Initialize security reports database"
                    echo ""
                    echo -e "${GREEN}Once configured, comprehensive security scanning will be available here.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                # Generate Security Report
                if [[ -x "$SHARED_UTILITIES_PATH/security_reports.sh" ]]; then
                    echo -e "${CYAN}Security Report Generation${NC}"
                    echo ""
                    echo "1. Summary report (key metrics and alerts)"
                    echo "2. Full report (comprehensive analysis)"
                    echo "3. Alerts only (recent security incidents)"
                    read -p "Select report type (1-3): " report_choice
                    
                    report_type="summary"
                    case $report_choice in
                        1) report_type="summary" ;;
                        2) report_type="full" ;;
                        3) report_type="alerts" ;;
                    esac
                    
                    echo -e "${CYAN}Generating $report_type security report...${NC}"
                    $SHARED_UTILITIES_PATH/security_reports.sh report "$report_type"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Security Reporting Setup Required ===${NC}"
                    echo ""
                    echo "Security reporting generates comprehensive reports including:"
                    echo "• Executive security health summaries"
                    echo "• Detailed compliance and risk assessments"
                    echo "• Security incident and alert analysis"
                    echo "• Trend analysis and recommendations"
                    echo ""
                    echo -e "${GREEN}Setup security_reports.sh to enable this functionality.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            14)
                if [[ "$backup_tools_available" == "true" ]]; then
                    $SHARED_UTILITIES_PATH/backup_tools.sh status
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Backup Tools Setup Required ===${NC}"
                    echo ""
                    echo "The backup tools integration provides enhanced functionality for:"
                    echo "• Gmail backup and restore with GYB (Got Your Back)"
                    echo "• Cloud storage operations with rclone"
                    echo "• Automated backup workflows for suspended users"
                    echo ""
                    echo -e "${CYAN}To enable backup tools:${NC}"
                    echo "1. Ensure backup_tools.sh exists in shared-utilities/"
                    echo "2. Install GYB: pip install gyb"
                    echo "3. Install rclone: https://rclone.org/install/"
                    echo "4. Configure cloud remotes with 'rclone config'"
                    echo ""
                    echo -e "${GREEN}Once installed, these features will be automatically available.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                if [[ "$gyb_available" == "true" ]]; then
                    echo -e "${CYAN}Gmail Backup Operations${NC}"
                    read -p "Enter user email for Gmail backup: " user_email
                    if [[ -n "$user_email" ]]; then
                        echo "Backup type:"
                        echo "1. Full backup"
                        echo "2. Incremental backup"
                        read -p "Select backup type (1-2): " backup_type_choice
                        
                        case $backup_type_choice in
                            1) backup_type="full" ;;
                            2) backup_type="incremental" ;;
                            *) backup_type="full" ;;
                        esac
                        
                        echo -e "${CYAN}Starting Gmail backup for $user_email (type: $backup_type)...${NC}"
                        $SHARED_UTILITIES_PATH/backup_tools.sh gmail-backup "$user_email" "$backup_type"
                    else
                        echo -e "${RED}User email cannot be empty${NC}"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== GYB (Got Your Back) Setup Required ===${NC}"
                    echo ""
                    echo "GYB enables comprehensive Gmail backup and restore capabilities."
                    echo ""
                    echo -e "${CYAN}To install GYB:${NC}"
                    echo "• Install with pip: ${WHITE}pip install gyb${NC}"
                    echo "• Or download from: https://github.com/GAM-team/got-your-back"
                    echo ""
                    echo -e "${CYAN}GYB Features:${NC}"
                    echo "• Full Gmail mailbox backup (emails, labels, filters)"
                    echo "• Incremental backups for efficiency"
                    echo "• Backup verification and integrity checking"
                    echo "• Cross-platform support (Windows, Mac, Linux)"
                    echo ""
                    echo -e "${GREEN}Once installed, Gmail backup operations will be available here.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                if [[ "$rclone_available" == "true" ]]; then
                    echo -e "${CYAN}Cloud Storage Operations${NC}"
                    read -p "Enter source path: " source_path
                    read -p "Enter remote name (e.g. gdrive, s3): " remote_name
                    read -p "Enter destination path: " dest_path
                    if [[ -n "$source_path" && -n "$remote_name" && -n "$dest_path" ]]; then
                        echo "Operation type:"
                        echo "1. Copy"
                        echo "2. Sync"
                        echo "3. Move"
                        read -p "Select operation (1-3): " op_choice
                        
                        case $op_choice in
                            1) operation="copy" ;;
                            2) operation="sync" ;;
                            3) operation="move" ;;
                            *) operation="copy" ;;
                        esac
                        
                        echo -e "${CYAN}Starting cloud operation: $operation...${NC}"
                        $SHARED_UTILITIES_PATH/backup_tools.sh cloud-backup "$source_path" "$remote_name" "$dest_path" "$operation"
                    else
                        echo -e "${RED}All fields are required${NC}"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== rclone Setup Required ===${NC}"
                    echo ""
                    echo "rclone enables powerful cloud storage operations with 40+ providers."
                    echo ""
                    echo -e "${CYAN}To install rclone:${NC}"
                    echo "• Download from: ${WHITE}https://rclone.org/install/${NC}"
                    echo "• Or via package manager (brew, apt, etc.)"
                    echo ""
                    echo -e "${CYAN}Supported Cloud Providers:${NC}"
                    echo "• Google Drive, Google Cloud Storage"
                    echo "• Amazon S3, Microsoft OneDrive"
                    echo "• Dropbox, Box, Azure Blob Storage"
                    echo "• And 40+ more providers"
                    echo ""
                    echo -e "${CYAN}After installation:${NC}"
                    echo "• Configure remotes: ${WHITE}rclone config${NC}"
                    echo "• Test connection: ${WHITE}rclone lsd remotename:${NC}"
                    echo ""
                    echo -e "${GREEN}Once configured, cloud operations will be available here.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            14)
                if [[ "$backup_tools_available" == "true" ]]; then
                    echo -e "${CYAN}Backup User on Suspension${NC}"
                    read -p "Enter user email to backup: " user_email
                    if [[ -n "$user_email" ]]; then
                        echo "Backup options:"
                        echo "1. Gmail only"
                        echo "2. Gmail + Drive"
                        echo "3. Gmail + Drive + Cloud upload"
                        read -p "Select backup scope (1-3): " backup_scope
                        
                        case $backup_scope in
                            1) gmail=1; drive=0; cloud=0 ;;
                            2) gmail=1; drive=1; cloud=0 ;;
                            3) gmail=1; drive=1; cloud=1 ;;
                            *) gmail=1; drive=0; cloud=0 ;;
                        esac
                        
                        echo -e "${CYAN}Starting comprehensive backup for $user_email...${NC}"
                        $SHARED_UTILITIES_PATH/backup_tools.sh backup-user "$user_email" "$gmail" "$drive" "$cloud"
                    else
                        echo -e "${RED}User email cannot be empty${NC}"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Automated User Backup Setup Required ===${NC}"
                    echo ""
                    echo "This feature provides comprehensive backup workflows when users are suspended."
                    echo ""
                    echo -e "${CYAN}Automated Backup Features:${NC}"
                    echo "• Gmail backup with GYB (full mailbox preservation)"
                    echo "• Google Drive file backup and organization"
                    echo "• Cloud storage upload for long-term retention"
                    echo "• Verification and integrity checking"
                    echo "• Automated cleanup and organization"
                    echo ""
                    echo -e "${CYAN}Requirements:${NC}"
                    echo "• GYB installed (pip install gyb)"
                    echo "• rclone configured with cloud storage"
                    echo "• backup_tools.sh in shared-utilities/"
                    echo ""
                    echo -e "${GREEN}Once setup is complete, automated backups will be available here.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                # Configuration Management
                if [[ -x "$SHARED_UTILITIES_PATH/config_manager.sh" ]]; then
                    source "$SHARED_UTILITIES_PATH/config_manager.sh"
                    show_config_menu
                else
                    echo -e "${YELLOW}=== Configuration Management Setup Required ===${NC}"
                    echo ""
                    echo "Configuration Management provides centralized control over:"
                    echo "• Dashboard refresh intervals and caching settings"
                    echo "• Security scan schedules and alert thresholds"
                    echo "• Backup automation policies and retention settings"
                    echo "• Scheduling preferences with user opt-out capabilities"
                    echo "• System-wide settings and performance tuning"
                    echo ""
                    echo -e "${CYAN}Features:${NC}"
                    echo "• Web-style configuration interface"
                    echo "• Complete audit trail of all setting changes"
                    echo "• User preference management with privacy controls"
                    echo "• Import/export configuration for backup and migration"
                    echo "• Granular opt-out controls for automated tasks"
                    echo ""
                    echo -e "${GREEN}Setup config_manager.sh to enable centralized configuration.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                # Scheduler Management
                if [[ -x "$SHARED_UTILITIES_PATH/scheduler.sh" ]]; then
                    echo -e "${CYAN}🕐 Scheduler Management${NC}"
                    echo ""
                    echo "1. Show scheduler status"
                    echo "2. Start scheduler daemon"
                    echo "3. Stop scheduler daemon" 
                    echo "4. Restart scheduler daemon"
                    echo "5. Test task execution (run-once)"
                    echo "6. Return to dashboard menu"
                    echo ""
                    read -p "Select option (1-6): " scheduler_choice
                    
                    case $scheduler_choice in
                        1) $SHARED_UTILITIES_PATH/scheduler.sh status ;;
                        2) $SHARED_UTILITIES_PATH/scheduler.sh start ;;
                        3) $SHARED_UTILITIES_PATH/scheduler.sh stop ;;
                        4) $SHARED_UTILITIES_PATH/scheduler.sh restart ;;
                        5) $SHARED_UTILITIES_PATH/scheduler.sh run-once ;;
                        15) ;; # Return to menu
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}=== Background Scheduler Setup Required ===${NC}"
                    echo ""
                    echo "The Background Scheduler enables automated execution of:"
                    echo "• Dashboard statistics refresh (every 30 minutes)"
                    echo "• Security compliance scans (daily/weekly schedules)"
                    echo "• Backup operations for suspended users"
                    echo "• Cleanup tasks for logs and temporary files"
                    echo "• Custom maintenance and monitoring tasks"
                    echo ""
                    echo -e "${CYAN}Key Features:${NC}"
                    echo "• Complete opt-out capabilities - users can disable any/all tasks"
                    echo "• Cron-like scheduling with intelligent next-run calculation"
                    echo "• Concurrent task execution with configurable limits"
                    echo "• Comprehensive logging and error handling"
                    echo "• Real-time status monitoring and performance tracking"
                    echo "• Automatic failure alerts and retry mechanisms"
                    echo ""
                    echo -e "${GREEN}⚠️  PRIVACY FOCUS: All scheduling is OPT-IN by default${NC}"
                    echo "• Master scheduler starts DISABLED"
                    echo "• Individual task types can be opted out separately"
                    echo "• Global opt-out overrides all task execution"
                    echo "• No tasks run without explicit user consent"
                    echo ""
                    echo -e "${CYAN}Setup scheduler.sh to enable background automation.${NC}"
                    echo ""
                    read -p "Press Enter to continue..."
                fi
                ;;
            14)
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}Initializing dashboard database...${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh init
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                if [[ -x "$SHARED_UTILITIES_PATH/backup_tools.sh" ]]; then
                    echo -e "${CYAN}Initializing backup tools database...${NC}"
                    $SHARED_UTILITIES_PATH/backup_tools.sh init
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Backup tools not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                if [[ -x "$SHARED_UTILITIES_PATH/security_reports.sh" ]]; then
                    echo -e "${CYAN}Initializing security reports database...${NC}"
                    $SHARED_UTILITIES_PATH/security_reports.sh init
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Security reports not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            17)
                if [[ -x "$SHARED_UTILITIES_PATH/config_manager.sh" ]]; then
                    echo -e "${CYAN}Initializing configuration management database...${NC}"
                    $SHARED_UTILITIES_PATH/config_manager.sh init
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Configuration manager not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            18|p|P|m|M)
                return
                ;;
            r|R)
                # Refresh option - force refresh and show dashboard
                if [[ -x "$SHARED_UTILITIES_PATH/dashboard_functions.sh" ]]; then
                    echo -e "${CYAN}Refreshing statistics...${NC}"
                    $SHARED_UTILITIES_PATH/dashboard_functions.sh scan
                    clear
                    echo -e "${GREEN}Statistics refreshed!${NC}"
                    continue
                else
                    echo -e "${RED}Dashboard functions not available${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            x|X)
                echo -e "${BLUE}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-18, r, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to let user choose between database or fresh GAM data
choose_data_source() {
    local operation_name="$1"
    
    # Check when domain data was last synced
    local last_sync=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='last_domain_sync';" 2>/dev/null)
    local db_user_count=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "0")
    
    if [[ -n "$last_sync" && "$db_user_count" -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}📊 Database contains $db_user_count accounts${NC}"
        echo -e "${CYAN}🕐 Last synced: $last_sync${NC}"
        echo ""
        echo "Data source for $operation_name:"
        echo "1. Use database data (faster, from $last_sync)"
        echo "2. Get fresh data from GAM (slower, current)"
        echo ""
        read -p "Select data source (1-2): " data_source_choice
        
        case $data_source_choice in
            1)
                echo -e "${CYAN}Using database data from $last_sync${NC}"
                return 1  # Use database
                ;;
            2)
                echo -e "${CYAN}Getting fresh data from GAM...${NC}"
                return 0  # Use GAM
                ;;
            *)
                echo -e "${RED}Invalid choice. Using fresh GAM data.${NC}"
                return 0  # Default to GAM
                ;;
        esac
    else
        echo -e "${YELLOW}No database data available. Getting fresh data from GAM...${NC}"
        return 0  # Use GAM
    fi
}

# Function to mark stats as dirty (needs recalculation)
# Call this function whenever you perform operations that could affect user/group/drive counts:
# - Creating/deleting users or groups
# - Suspending/unsuspending users  
# - Moving users between OUs
# - Creating/deleting shared drives
# - Importing account data from CSV
# - Any operation that changes domain membership
mark_stats_dirty() {
    sqlite3 local-config/account_lifecycle.db "
        INSERT OR REPLACE INTO config (key, value) VALUES ('stats_dirty', 'true');
    " 2>/dev/null
}

# Function to force refresh of stats (useful for manual operations)
refresh_stats() {
    mark_stats_dirty
    echo "Stats marked for refresh. They will be recalculated on next main menu display."
}

# Function to sync domain users to database
sync_domain_to_database() {
    if [[ ! -x "$GAM" ]]; then
        echo "  ⚠️  GAM not available - cannot sync domain data"
        return 1
    fi
    
    echo "  📥 Syncing domain users to database..."
    
    # Get all users from domain with key fields
    local temp_users=$(mktemp)
    $GAM print users fields primaryemail,suspended,orgunitpath 2>/dev/null > "$temp_users"
    
    if [[ ! -s "$temp_users" ]]; then
        echo "  ❌ Failed to retrieve domain users"
        rm -f "$temp_users"
        return 1
    fi
    
    # Process each user and update database
    local processed=0
    local updated=0
    
    tail -n +2 "$temp_users" | while IFS=',' read -r email suspended orgunit; do
        # Clean up fields (remove quotes if present)
        email=$(echo "$email" | tr -d '"')
        suspended=$(echo "$suspended" | tr -d '"')
        orgunit=$(echo "$orgunit" | tr -d '"')
        
        # Determine current stage based on OU and suspension status
        local stage="active"  # Default to active
        
        # Only change stage if user is actually suspended
        if [[ "$suspended" == "True" || "$suspended" == "true" ]]; then
            # User is suspended - determine which stage based on OU
            case "$orgunit" in
                *"Pending Deletion"*) stage="pending_deletion" ;;
                *"Temporary Hold"*) stage="temporary_hold" ;;
                *"Exit Row"*) stage="exit_row" ;;
                *"Suspended"*) stage="recently_suspended" ;;
                *) stage="recently_suspended" ;;  # Default for suspended users
            esac
        else
            # User is not suspended - they are active regardless of OU
            stage="active"
        fi
        
        # Insert or update user in database
        sqlite3 local-config/account_lifecycle.db "
            INSERT OR REPLACE INTO accounts (
                email, 
                current_stage, 
                updated_at, 
                ou_path
            ) VALUES (
                '$email', 
                '$stage', 
                datetime('now'), 
                '$orgunit'
            );
        " 2>/dev/null
        
        ((processed++))
        if [[ $? -eq 0 ]]; then
            ((updated++))
        fi
    done
    
    rm -f "$temp_users"
    echo "  ✅ Synced $processed users to database"
    
    # Update last sync timestamp and mark stats as dirty since we've changed account data
    sqlite3 local-config/account_lifecycle.db "
        INSERT OR REPLACE INTO config (key, value) VALUES ('last_domain_sync', datetime('now'));
    " 2>/dev/null
    
    # Mark stats as dirty since we've just updated account data
    mark_stats_dirty
}

# Function to show quick domain statistics
show_quick_stats() {
    echo -e "${CYAN}📊 Quick Stats:${NC}"
    echo -e "${GRAY}   Generated: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    
    # Check if database exists
    if [[ ! -f "local-config/account_lifecycle.db" ]]; then
        echo "  🔍 Database not initialized - run setup first"
        echo ""
        return
    fi
    
    # Get database-based statistics (fast and reliable)
    local db_accounts
    local db_suspended
    local db_active
    db_accounts=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "0")
    db_suspended=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row');" 2>/dev/null || echo "0")
    db_active=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage = 'active';" 2>/dev/null || echo "0")
    
    # Try to get cached domain stats from database (GAM-based stats)
    local cached_stats
    cached_stats=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='domain_stats_cache'" 2>/dev/null || echo "")
    local cache_timestamp
    cache_timestamp=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='domain_stats_timestamp'" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    
    # Initialize domain counters
    local total_users="?"
    local total_groups="?"
    local shared_drives="?"
    
    # Check if stats need recalculation (dirty flag, no cache, or empty database)
    local stats_dirty
    stats_dirty=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='stats_dirty'" 2>/dev/null || echo "true")
    
    # Use cached stats if they exist, stats are not dirty, AND database has data
    if [[ -n "$cached_stats" && "$stats_dirty" != "true" && "$db_accounts" -gt 0 ]]; then
        # Parse cached domain stats
        IFS=',' read -r total_users total_groups shared_drives <<< "$cached_stats"
    else
        # Get fresh domain stats if GAM is available and we don't have recent cache
        if [[ -x "$GAM" ]]; then
            echo "  🔍 Updating domain statistics..."
            
            # Sync domain data to database (this populates/updates the accounts table)
            sync_domain_to_database
            
            # Now get counts from database (more reliable than GAM direct counts)
            total_users=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "?")
            db_active=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage = 'active';" 2>/dev/null || echo "0")
            db_suspended=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row');" 2>/dev/null || echo "0")
            db_accounts="$total_users"
            
            # Get groups and shared drives counts (these don't change often, so direct GAM is OK)
            total_groups=$($GAM print groups fields email 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
            if [[ -z "$total_groups" || "$total_groups" == "0" ]]; then
                total_groups="?"
            fi
            
            shared_drives=$($GAM print teamdrives fields id 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
            if [[ -z "$shared_drives" || "$shared_drives" == "0" ]]; then
                shared_drives="0"
            fi
            
            # Cache the results and clear dirty flag (only if we got valid data)
            if [[ "$total_users" != "?" ]]; then
                local cache_data="$total_users,$total_groups,$shared_drives"
                sqlite3 local-config/account_lifecycle.db "
                    INSERT OR REPLACE INTO config (key, value) VALUES ('domain_stats_cache', '$cache_data');
                    INSERT OR REPLACE INTO config (key, value) VALUES ('domain_stats_timestamp', '$current_time');
                    INSERT OR REPLACE INTO config (key, value) VALUES ('stats_dirty', 'false');
                " 2>/dev/null
            fi
        fi
    fi
    
    # Display stats using database counts for accuracy
    echo -e "  👥 Users: ${BOLD}$total_users${NC} total, ${GREEN}$db_active${NC} active, ${YELLOW}$db_suspended${NC} suspended"
    echo -e "  👬 Groups: ${BOLD}$total_groups${NC}  |  📁 Shared Drives: ${BOLD}$shared_drives${NC}"
    echo -e "  🗄️  Database: ${BOLD}$db_accounts${NC} accounts tracked"
    
    # Show when database was last synced
    local last_sync=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='last_domain_sync';" 2>/dev/null)
    if [[ -n "$last_sync" ]]; then
        echo -e "${GRAY}   Database synced: $last_sync${NC}"
    fi
    echo ""
}


# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${BLUE}=== GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner ===${NC}"
    echo ""
    
    # Show domain configuration
    if [[ -n "$DOMAIN" ]]; then
        echo -e "${GREEN}🌐 Domain: ${BOLD}$DOMAIN${NC}"
        if [[ -n "$ADMIN_USER" ]]; then
            echo -e "${GREEN}👤 Admin: $ADMIN_USER${NC}"
        fi
        echo ""
        
        # Show quick stats if GAM is available
        show_quick_stats
        
    else
        echo -e "${YELLOW}⚠️  No domain configured - run Configuration Management to set up${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}Organized by Function Type for Easy Navigation${NC}"
    echo ""
    echo -e "${GREEN}=== ACCOUNT MANAGEMENT ===${NC}"
    echo "1. 👥 User & Group Management"
    echo ""
    echo -e "${BLUE}=== DATA & FILE OPERATIONS ===${NC}"
    echo "2. 💾 File & Drive Operations"
    echo "3. 🔍 Analysis & Discovery"
    echo "4. 📋 Account List Management"
    echo ""
    echo -e "${PURPLE}=== MONITORING & SYSTEM ===${NC}"
    echo "5. 🎯 Dashboard & Statistics"
    echo "6. 📈 Reports & Monitoring"
    echo "7. ⚙️  System Administration"
    echo ""
    echo -e "${RED}=== SECURITY & COMPLIANCE ===${NC}"
    echo "8. 🔐 SCuBA Compliance Management"
    echo ""
    echo -e "${CYAN}=== CONFIGURATION ===${NC}"
    echo "c. ⚙️  Configuration Management (Setup & Settings)"
    echo ""
    echo -e "${GRAY}=== NAVIGATION ===${NC}"
    echo "s. 🔍 Search Menu Options"
    echo "i. 📋 Menu Index (Alphabetical)"
    echo ""
    echo "x. ❌ Exit"
    echo ""
    read -p "Select an option (1-9, c, s, i, x): " choice
    echo ""
    
    # Convert letters to numbers for case handling
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then
        choice=10  # Exit
    elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
        choice=99  # Configuration
    elif [[ "$choice" == "s" || "$choice" == "S" ]]; then
        choice=98  # Search
    elif [[ "$choice" == "i" || "$choice" == "I" ]]; then
        choice=97  # Index
    fi
    
    return $choice
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    
    if [[ "$PROGRESS_ENABLED" == "true" ]]; then
        local percentage=$((current * 100 / total))
        local filled=$((percentage / 2))
        local bar=""
        
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=filled; i<50; i++)); do bar+="░"; done
        
        printf "\r${CYAN}Progress: [%s] %d%% (%d/%d) %s${NC}" "$bar" "$percentage" "$current" "$total" "$description"
        
        if [[ $current -eq $total ]]; then
            echo ""
        fi
    fi
}

# Function to execute command with dry-run support
execute_command() {
    local command="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would execute: $description${NC}"
        echo -e "${CYAN}[DRY-RUN] Command: $command${NC}"
        return 0
    else
        echo -e "${GREEN}Executing: $description${NC}"
        eval "$command"
        return $?
    fi
}

# Function to create backup before changes
create_backup() {
    local user="$1"
    local operation="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would create backup for $user ($operation)${NC}"
        return 0
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="${SCRIPTPATH}/backups/${timestamp}_${user}_${operation}"
    
    mkdir -p "$backup_dir"
    echo "$user,$operation,$(date '+%Y-%m-%d %H:%M:%S')" >> "$backup_dir/backup_info.txt"
    echo -e "${GREEN}Backup created at: $backup_dir${NC}"
}

# Function for enhanced confirmation with different levels
enhanced_confirm() {
    local operation="$1"
    local user_count="${2:-1}"
    local confirmation_level="${3:-normal}"
    
    echo ""
    case $confirmation_level in
        "high")
            echo -e "${YELLOW}⚠️  HIGH RISK OPERATION ⚠️${NC}"
            echo "This operation will affect $user_count user(s) and could impact many files."
            echo "Type 'CONFIRM' in all caps to proceed:"
            read -p "> " response
            [[ "$response" == "CONFIRM" ]] && return 0 || return 1
            ;;
        "batch")
            if [[ $user_count -gt 10 ]]; then
                echo -e "${YELLOW}⚠️  LARGE BATCH OPERATION ⚠️${NC}"
                echo "You are about to process $user_count users."
                echo "Type 'YES' to proceed:"
                read -p "> " response
                [[ "$response" == "YES" ]] && return 0 || return 1
            else
                return $(confirm_action)
            fi
            ;;
        *)
            return $(confirm_action)
            ;;
    esac
}

# Function to get operation choice
get_operation_choice() {
    echo ""
    echo "Select operation:"
    echo "1. Add temporary hold"
    echo "2. Remove temporary hold"
    echo "3. Mark for pending deletion"
    echo "4. Remove pending deletion"
    echo ""
    while true; do
        read -p "Choose operation (1-4): " op_choice
        case $op_choice in
            1) echo "add_gwombat_hold"; break ;;
            2) echo "remove_gwombat_hold"; break ;;
            3) echo "add_pending"; break ;;
            4) echo "remove_pending"; break ;;
            *) echo -e "${RED}Please select 1, 2, 3, or 4.${NC}" ;;
        esac
    done
}

# Function to validate user exists
validate_user_exists() {
    local user="$1"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo "true"  # Always valid in dry-run mode
        return 0
    fi
    
    # Check if user exists using GAM
    local user_info=$($GAM info user "$user" 2>&1)
    if echo "$user_info" | grep -q "Does not exist"; then
        echo "false"
        return 1
    else
        echo "true"
        return 0
    fi
}

# Function to get enhanced user status information
get_user_status() {
    local user="$1"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}Email:${NC} $user"
        echo -e "${CYAN}Name:${NC} Sample User"
        echo -e "${CYAN}Department:${NC} Student (simulated)"
        echo -e "${CYAN}Status:${NC} ${GREEN}Active (simulated)${NC}"
        echo -e "${CYAN}Org Unit:${NC} /${DOMAIN:-yourdomain.edu} (simulated)"
        echo -e "${CYAN}Pending Deletion:${NC} ${GREEN}No (simulated)${NC}"
        echo ""
        echo -e "${CYAN}Group Memberships:${NC}"
        echo "group1@domain.com, group2@domain.com (simulated)"
        echo -e "${CYAN}Total Groups:${NC} 2 (simulated)"
        echo ""
        echo -e "${CYAN}File Analysis:${NC}"
        echo "Estimated file count: 150 (simulated)"
        echo -e "${GREEN}No files with pending deletion marker (simulated)${NC}"
        return 0
    fi
    
    local user_info=$($GAM info user "$user" 2>&1)
    if echo "$user_info" | grep -q "Does not exist"; then
        echo -e "${RED}User does not exist${NC}"
        return 1
    fi
    
    # Extract key information
    local email=$(echo "$user_info" | grep "Email:" | awk -F': ' '{print $2}')
    local firstname=$(echo "$user_info" | grep "First Name:" | awk -F': ' '{print $2}')
    local lastname=$(echo "$user_info" | grep "Last Name:" | awk -F': ' '{print $2}')
    local suspended=$(echo "$user_info" | grep "Account Suspended:" | awk -F': ' '{print $2}')
    local orgunit=$(echo "$user_info" | grep "Org Unit Path:" | awk -F': ' '{print $2}')
    local department=$(echo "$user_info" | grep "Department:" | awk -F': ' '{print $2}')
    local creation=$(echo "$user_info" | grep "Creation Time:" | awk -F': ' '{print $2}')
    
    # Display formatted information
    echo -e "${CYAN}Email:${NC} ${email:-$user}"
    echo -e "${CYAN}Name:${NC} $firstname $lastname"
    echo -e "${CYAN}Department:${NC} ${department:-'Not specified'}"
    echo -e "${CYAN}Created:${NC} ${creation:-'Not specified'}"
    
    # Show suspension status with color
    if [[ "$suspended" == "True" ]]; then
        echo -e "${CYAN}Status:${NC} ${RED}Suspended${NC}"
    else
        echo -e "${CYAN}Status:${NC} ${GREEN}Active${NC}"
    fi
    
    echo -e "${CYAN}Org Unit:${NC} ${orgunit:-'Not specified'}"
    
    # Check for pending deletion marker
    if [[ "$lastname" == *"(PENDING DELETION - CONTACT OIT)"* ]]; then
        echo -e "${CYAN}Pending Deletion:${NC} ${YELLOW}YES - Marked for deletion${NC}"
    else
        echo -e "${CYAN}Pending Deletion:${NC} ${GREEN}No${NC}"
    fi
    
    # Show group memberships
    echo ""
    echo -e "${CYAN}Group Memberships:${NC}"
    local groups=$($GAM print groups member "$user" 2>/dev/null | tail -n +2)
    local group_count=$(echo "$groups" | wc -l)
    
    if [[ -n "$groups" && "$groups" != "" ]]; then
        echo "$groups" | head -5
        if [[ $group_count -gt 5 ]]; then
            echo "... (and $((group_count - 5)) more groups)"
        fi
        echo -e "${CYAN}Total Groups:${NC} $group_count"
    else
        echo "None"
    fi
    
    # Show file count estimate
    echo ""
    echo -e "${CYAN}File Analysis:${NC}"
    local file_count=$($GAM user "$user" show filelist | wc -l 2>/dev/null || echo "0")
    echo "Estimated file count: $file_count"
    
    # Check for pending deletion files
    local pending_files=$($GAM user "$user" show filelist id name 2>/dev/null | grep "(PENDING DELETION - CONTACT OIT)" | wc -l || echo "0")
    if [[ $pending_files -gt 0 ]]; then
        echo -e "${YELLOW}Files with pending deletion marker: $pending_files${NC}"
    else
        echo -e "${GREEN}No files with pending deletion marker${NC}"
    fi
}

# Function to get enhanced user input with validation
get_user_input() {
    while true; do
        read -p "Enter username or email address: " user_input
        if [[ -z "$user_input" ]]; then
            echo -e "${RED}Please enter a valid username or email.${NC}"
            continue
        fi
        
        # Add @${DOMAIN:-yourdomain.edu} if just username provided
        if [[ "$user_input" != *"@"* ]]; then
            user_input="${user_input}@${DOMAIN:-yourdomain.edu}"
            echo "Assuming: $user_input"
        fi
        
        # Validate user exists
        echo "Validating user..."
        if [[ $(validate_user_exists "$user_input") == "true" ]]; then
            # Show user status
            echo ""
            echo -e "${CYAN}=== USER STATUS ===${NC}"
            get_user_status "$user_input"
            echo ""
            
            read -p "Is this the correct user? (y/n): " confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                echo "$user_input"
                break
            else
                echo "Please try again."
            fi
        else
            echo -e "${RED}User '$user_input' does not exist. Please try again.${NC}"
        fi
    done
}

# Function to get multiple user input with validation
get_multiple_user_input() {
    echo "Enter usernames/emails (one per line, empty line to finish):"
    local users=()
    local user_input
    
    while true; do
        read -p "> " user_input
        if [[ -z "$user_input" ]]; then
            break
        fi
        
        # Add @${DOMAIN:-yourdomain.edu} if just username provided
        if [[ "$user_input" != *"@"* ]]; then
            user_input="${user_input}@${DOMAIN:-yourdomain.edu}"
        fi
        
        # Validate user exists
        if [[ $(validate_user_exists "$user_input") == "true" ]]; then
            users+=("$user_input")
            echo "✓ Added: $user_input"
        else
            echo -e "${RED}✗ User '$user_input' does not exist. Skipping.${NC}"
        fi
    done
    
    if [[ ${#users[@]} -eq 0 ]]; then
        echo -e "${RED}No valid users entered.${NC}"
        return 1
    fi
    
    echo ""
    echo "Valid users entered: ${#users[@]}"
    for user in "${users[@]}"; do
        echo "  - $user"
    done
    
    # Save to temporary file
    local temp_file="/tmp/bulk_users_$$.txt"
    printf '%s\n' "${users[@]}" > "$temp_file"
    echo "$temp_file"
}

# Function to check prerequisites before operations
check_operation_prerequisites() {
    local user="$1"
    local operation="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0  # Skip checks in dry-run mode
    fi
    
    local user_info=$($GAM info user "$user" 2>/dev/null)
    if [[ -z "$user_info" ]]; then
        echo -e "${RED}Error: User $user does not exist.${NC}"
        return 1
    fi
    
    local suspended=$(echo "$user_info" | awk -F': ' '/Account Suspended:/ {print $2}')
    local lastname=$(echo "$user_info" | awk -F': ' '/Last Name:/ {print $2}')
    local ou=$(echo "$user_info" | awk -F': ' '/Org Unit Path:/ {print $2}')
    
    case $operation in
        "add_pending")
            if [[ "$suspended" != "True" ]]; then
                echo -e "${YELLOW}Warning: User $user is not suspended. Proceed anyway? (y/n)${NC}"
                read -p "> " proceed
                [[ "$proceed" =~ ^[Yy] ]] || return 1
            fi
            if [[ "$lastname" == *"(PENDING DELETION - CONTACT OIT)"* ]]; then
                echo -e "${YELLOW}Warning: User $user already has pending deletion marker. Skip? (y/n)${NC}"
                read -p "> " skip
                [[ "$skip" =~ ^[Yy] ]] && return 2  # Return 2 for skip
            fi
            ;;
        "remove_pending")
            if [[ "$lastname" != *"(PENDING DELETION - CONTACT OIT)"* ]]; then
                echo -e "${YELLOW}Warning: User $user does not have pending deletion marker. Proceed anyway? (y/n)${NC}"
                read -p "> " proceed
                [[ "$proceed" =~ ^[Yy] ]] || return 1
            fi
            ;;
        "add_gwombat_hold")
            if [[ "$lastname" == *"(Suspended Account - Temporary Hold)"* ]]; then
                echo -e "${YELLOW}Warning: User $user already has temporary hold marker. Skip? (y/n)${NC}"
                read -p "> " skip
                [[ "$skip" =~ ^[Yy] ]] && return 2  # Return 2 for skip
            fi
            ;;
        "remove_gwombat_hold")
            if [[ "$lastname" != *"(Suspended Account - Temporary Hold)"* ]]; then
                echo -e "${YELLOW}Warning: User $user does not have temporary hold marker. Proceed anyway? (y/n)${NC}"
                read -p "> " proceed
                [[ "$proceed" =~ ^[Yy] ]] || return 1
            fi
            ;;
    esac
    
    return 0
}

# Function to load users from file
load_users_from_file() {
    while true; do
        read -p "Enter the full path to the file containing usernames: " file_path
        if [[ -f "$file_path" ]]; then
            echo "$file_path"
            break
        else
            echo -e "${RED}File not found. Please enter a valid file path.${NC}"
        fi
    done
}

# Function to show what actions will be performed for adding temporary hold
show_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Restore Last Name:${NC}"
    echo "   - Remove '(PENDING DELETION - CONTACT OIT)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Fix Filenames:${NC}"
    echo "   - Find all files with '(PENDING DELETION - CONTACT OIT)' in name"
    echo "   - Rename them to include '(Suspended Account - Temporary Hold)'"
    echo "   - Log changes to tmp/${user}-fixed.txt"
    echo ""
    echo -e "${GREEN}3. Rename Shared Files:${NC}"
    echo "   - Generate file list using list-users-files.sh"
    echo "   - Filter for files shared with active ${DOMAIN:-yourdomain.edu} accounts ONLY"
    echo "   - Add '(Suspended Account - Temporary Hold)' to shared file names"
    echo "   - Skip files already having this suffix or shared externally"
    echo ""
    echo -e "${GREEN}4. Update User Last Name:${NC}"
    echo "   - Add '(Suspended Account - Temporary Hold)' to user's last name"
    echo "   - Skip if already present"
    echo ""
    echo -e "${GREEN}5. Move to Temporary Hold OU:${NC}"
    echo "   - Move user to '$OU_TEMPHOLD' organizational unit"
    echo "   - Remove user from all groups (with backup)"
    echo ""
    echo -e "${GREEN}6. Logging:${NC}"
    echo "   - Add user to gwombat-done.log"
    echo "   - Add timestamp to file-rename-done.txt"
    echo "   - Create group membership backup"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for removing temporary hold
show_removal_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF REMOVAL ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Remove Temporary Hold from Last Name:${NC}"
    echo "   - Remove '(Suspended Account - Temporary Hold)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Remove Temporary Hold from All Files:${NC}"
    echo "   - Find all files with '(Suspended Account - Temporary Hold)' in name"
    echo "   - Remove the suffix from file names"
    echo "   - Log changes to tmp/${user}-removal.txt"
    echo ""
    echo -e "${GREEN}3. Move User to Destination OU:${NC}"
    echo "   - Choose destination: Pending Deletion, Suspended, or ${DOMAIN:-yourdomain.edu}"
    echo "   - Move user to selected organizational unit"
    echo "   - If moving to ${DOMAIN:-yourdomain.edu}, offer to restore groups from backup"
    echo ""
    echo -e "${GREEN}4. Logging:${NC}"
    echo "   - Add user to gwombat-removed.log"
    echo "   - Add timestamp to file-removal-done.txt"
    echo "   - Log any group restoration activity"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for adding pending deletion
show_pending_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF PENDING DELETION ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Add Pending Deletion to Last Name:${NC}"
    echo "   - Add '(PENDING DELETION - CONTACT OIT)' to user's last name"
    echo "   - Skip if already present"
    echo ""
    echo -e "${GREEN}2. Add Pending Deletion to All Files:${NC}"
    echo "   - Generate file list using list-users-files.sh"
    echo "   - Add '(PENDING DELETION - CONTACT OIT)' to all file names"
    echo "   - Skip files already having this suffix"
    echo ""
    echo -e "${GREEN}3. Add Drive Labels to Files:${NC}"
    echo "   - Temporarily add Education Plus license"
    echo "   - Add pending deletion labels to all files"
    echo "   - Remove Education Plus license"
    echo ""
    echo -e "${GREEN}4. Remove User from All Groups:${NC}"
    echo "   - Query user's group memberships"
    echo "   - Remove user from all groups"
    echo "   - Log group removals"
    echo ""
    echo -e "${GREEN}5. Move to Pending Deletion OU:${NC}"
    echo "   - Move user to '$OU_PENDING_DELETION' organizational unit"
    echo ""
    echo -e "${GREEN}6. Logging:${NC}"
    echo "   - Add user to pending-deletion-done.log"
    echo "   - Add timestamp to logs"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for removing pending deletion
show_pending_removal_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF PENDING DELETION REMOVAL ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Remove Pending Deletion from Last Name:${NC}"
    echo "   - Remove '(PENDING DELETION - CONTACT OIT)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Remove Pending Deletion from All Files:${NC}"
    echo "   - Find all files with '(PENDING DELETION - CONTACT OIT)' in name"
    echo "   - Remove the suffix from file names"
    echo "   - Remove drive labels from files"
    echo "   - Log changes to tmp/${user}-pending-removed.txt"
    echo ""
    echo -e "${GREEN}3. Move User to Destination OU:${NC}"
    echo "   - Choose destination: Pending Deletion, Suspended, or ${DOMAIN:-yourdomain.edu}"
    echo "   - Move user to selected organizational unit"
    echo ""
    echo -e "${GREEN}4. Logging:${NC}"
    echo "   - Add user to pending-deletion-removed.log"
    echo "   - Add timestamp to pending-removal-done.txt"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to handle dry-run mode
dry_run_mode() {
    DRY_RUN=true
    echo -e "${CYAN}=== DRY-RUN MODE ACTIVATED ===${NC}"
    echo ""
    echo "In dry-run mode, you can:"
    echo "1. Preview changes for a single user"
    echo "2. Preview changes for users from a file" 
    echo "3. Return to main menu"
    echo ""
    read -p "Select an option (1-3): " dry_choice
    
    case $dry_choice in
        1)
            user=$(get_user_input)
            operation=$(get_operation_choice)
            echo ""
            echo -e "${MAGENTA}🔍 DRY-RUN PREVIEW FOR: $user${NC}"
            
            case $operation in
                "add_gwombat_hold")
                    show_summary "$user"
                    process_user "$user"
                    ;;
                "remove_gwombat_hold")
                    show_removal_summary "$user"
                    remove_gwombat_hold_user "$user"
                    ;;
                "add_pending")
                    show_pending_summary "$user"
                    process_pending_user "$user"
                    ;;
                "remove_pending")
                    show_pending_removal_summary "$user"
                    remove_pending_user "$user"
                    ;;
            esac
            ;;
        2)
            file_path=$(load_users_from_file)
            user_count=$(wc -l < "$file_path")
            operation=$(get_operation_choice)
            echo ""
            echo -e "${MAGENTA}🔍 DRY-RUN PREVIEW FOR $user_count USERS${NC}"
            
            case $operation in
                "add_gwombat_hold")
                    process_users_from_file "$file_path"
                    ;;
                "remove_gwombat_hold")
                    remove_gwombat_hold_users_from_file "$file_path"
                    ;;
                "add_pending")
                    process_pending_users_from_file "$file_path"
                    ;;
                "remove_pending")
                    remove_pending_users_from_file "$file_path"
                    ;;
            esac
            ;;
        3)
            DRY_RUN=false
            return
            ;;
    esac
    
    DRY_RUN=false
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Function to handle discovery mode
# Shared drive cleanup functions
cleanup_shared_drive() {
    local drive_id="$1"
    local dry_run="${2:-false}"
    
    if [[ -z "$drive_id" ]]; then
        echo -e "${RED}Error: Drive ID is required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Shared Drive Cleanup: $drive_id ===${NC}"
    echo ""
    
    # Grant admin user editor access to the shared drive
    local admin_user="${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}}"
    echo -e "${CYAN}Adding admin access to shared drive...${NC}"
    if ! $GAM user "$admin_user" add drivefileacl "$drive_id" user "$admin_user" role editor asadmin 2>/dev/null; then
        echo -e "${RED}Error: Failed to add admin access to shared drive${NC}"
        return 1
    fi
    
    # Create temporary file for file list
    local tempfile=$(mktemp)
    local logfile="local-config/logs/${drive_id}-cleanup.txt"
    
    echo -e "${CYAN}Scanning shared drive for files with pending deletion markers...${NC}"
    
    # Get all files in the shared drive with pending deletion markers
    if ! $GAM user "$admin_user" show filelist select teamdriveid "$drive_id" fields "id,name" > "$tempfile" 2>/dev/null; then
        echo -e "${RED}Error: Failed to retrieve file list from shared drive${NC}"
        rm -f "$tempfile"
        $GAM user "$admin_user" delete drivefileacl "$drive_id" "$admin_user" asadmin 2>/dev/null
        return 1
    fi
    
    # Filter files with pending deletion markers
    local files_with_markers=$(grep -v "Owner,id" "$tempfile" | grep "(PENDING DELETION - CONTACT OIT)" || true)
    local total_files=$(echo "$files_with_markers" | wc -l)
    
    if [[ -z "$files_with_markers" || $total_files -eq 0 ]]; then
        echo -e "${GREEN}No files with pending deletion markers found in this shared drive${NC}"
        rm -f "$tempfile"
        $GAM user "$admin_user" delete drivefileacl "$drive_id" "$admin_user" asadmin 2>/dev/null
        return 0
    fi
    
    echo -e "${YELLOW}Found $total_files files with pending deletion markers${NC}"
    echo ""
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${CYAN}=== DRY RUN - Files that would be renamed: ===${NC}"
        local count=0
        echo "$files_with_markers" | while IFS=, read -r owner fileid filename; do
            ((count++))
            local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            if [[ "$new_filename" != "$filename" ]]; then
                echo "$count. $filename -> $new_filename"
            fi
        done
    else
        echo -e "${CYAN}Renaming files (removing pending deletion markers)...${NC}"
        
        # Create logs directory if it doesn't exist
        mkdir -p logs
        
        local count=0
        local success_count=0
        local skip_count=0
        
        # Use process substitution to avoid subshell issues
        while IFS=, read -r owner fileid filename; do
            ((count++))
            local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            
            if [[ "$new_filename" != "$filename" ]]; then
                echo -e "${CYAN}[$count/$total_files] Processing: $filename${NC}"
                
                # Show GAM command being executed
                echo -e "${YELLOW}Executing: $GAM user \"$owner\" update drivefile \"$fileid\" newfilename \"$new_filename\"${NC}"
                
                if $GAM user "$owner" update drivefile "$fileid" newfilename "$new_filename" 2>/dev/null; then
                    echo -e "${GREEN}Renamed: $filename -> $new_filename${NC}"
                    echo "SUCCESS: $fileid,$filename,$new_filename" >> "$logfile"
                    ((success_count++))
                    
                    # Remove pending deletion label if it exists
                    if [[ -n "$fileid" ]]; then
                        echo -e "${YELLOW}Executing: $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} process filedrivelabels \"$fileid\" deletelabelfield xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb 62BB395EC6${NC}"
                        $GAM user "${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}}" process filedrivelabels "$fileid" deletelabelfield xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb 62BB395EC6 2>/dev/null | grep -q "Deleted" && echo "Label removed" || true
                    fi
                else
                    echo -e "${RED}Failed to rename: $filename${NC}"
                    echo "ERROR: $fileid,$filename,Failed to rename" >> "$logfile"
                fi
            else
                ((skip_count++))
            fi
        done < <(echo "$files_with_markers")
        
        echo ""
        echo -e "${GREEN}Cleanup completed${NC}"
        echo -e "${CYAN}Files processed: $count${NC}"
        echo -e "${GREEN}Successfully renamed: $success_count${NC}"
        echo -e "${YELLOW}Skipped: $skip_count${NC}"
        echo -e "${CYAN}Log file: $logfile${NC}"
    fi
    
    # Clean up
    rm -f "$tempfile"
    echo -e "${CYAN}Removing admin access from shared drive...${NC}"
    $GAM user "$admin_user" delete drivefileacl "$drive_id" "$admin_user" asadmin 2>/dev/null
    
    log_info "Shared drive cleanup completed for $drive_id: $total_files files processed"
}

remove_pending_from_shared_drive() {
    local drive_id="$1"
    local dry_run="${2:-false}"
    
    if [[ -z "$drive_id" ]]; then
        echo -e "${RED}Error: Drive ID is required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Remove Pending Deletion from Shared Drive: $drive_id ===${NC}"
    echo ""
    
    # Use a service account for access
    local service_account="mjb9-ga"
    
    echo -e "${CYAN}Adding service account access to shared drive...${NC}"
    if ! $GAM add drivefileacl "$drive_id" user "$service_account" role organizer asadmin 2>/dev/null; then
        echo -e "${RED}Error: Failed to add service account access${NC}"
        return 1
    fi
    
    # Create temporary file for processing
    local tempfile=$(mktemp)
    
    echo -e "${CYAN}Scanning for files with pending deletion markers...${NC}"
    
    # Get files with pending deletion markers
    if ! $GAM user "$service_account" print filelist select "$drive_id" fields id,title | grep "(PENDING DELETION - CONTACT OIT)" > "$tempfile" 2>/dev/null; then
        echo -e "${YELLOW}No files found with pending deletion markers${NC}"
        rm -f "$tempfile"
        $GAM user "$service_account" delete drivefileacl "$drive_id" "$service_account" 2>/dev/null
        return 0
    fi
    
    local total_files=$(wc -l < "$tempfile")
    echo -e "${YELLOW}Found $total_files files with pending deletion markers${NC}"
    echo ""
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${CYAN}=== DRY RUN - Files that would be renamed: ===${NC}"
        awk -F, 'NR>1{print $2 "," substr($0, index($0,$3))}' "$tempfile" | while IFS=, read -r fileid filename; do
            local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            if [[ "$new_filename" != "$filename" ]]; then
                echo "Will rename: $filename -> $new_filename"
            fi
        done
    else
        echo -e "${YELLOW}The following files will be renamed:${NC}"
        awk -F, 'NR>1{print $2 "," substr($0, index($0,$3))}' "$tempfile" | while IFS=, read -r fileid filename; do
            local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            if [[ "$new_filename" != "$filename" ]]; then
                echo "Will rename: $filename -> $new_filename"
            fi
        done
        
        echo ""
        read -p "Do you wish to proceed with renaming these files? (y/n): " confirm
        
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            echo -e "${CYAN}Renaming files...${NC}"
            
            awk -F, 'NR>1{print $2 "," substr($0, index($0,$3))}' "$tempfile" | while IFS=, read -r fileid filename; do
                local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
                if [[ "$new_filename" != "$filename" ]]; then
                    echo "Debug: File ID: $fileid, Filename: $filename"
                    if $GAM user "$service_account" update drivefile "$fileid" newfilename "$new_filename" 2>/dev/null; then
                        echo -e "${GREEN}Renamed file: $filename -> $new_filename${NC}"
                    else
                        echo -e "${RED}Failed to rename: $filename${NC}"
                    fi
                fi
            done
            
            echo -e "${GREEN}Renaming operation completed${NC}"
        else
            echo -e "${YELLOW}Renaming operation cancelled${NC}"
        fi
    fi
    
    # Clean up
    rm -f "$tempfile"
    echo -e "${CYAN}Revoking service account permissions...${NC}"
    $GAM user "$service_account" delete drivefileacl "$drive_id" "$service_account" 2>/dev/null
    
    echo -e "${GREEN}Operation finished${NC}"
    
    log_info "Remove pending deletion completed for shared drive $drive_id"
}

# Function to get shared drive ID with URL parsing and search options
get_shared_drive_id() {
    local prompt="${1:-Enter shared drive ID or URL}"
    local drive_id=""
    
    while [[ -z "$drive_id" ]]; do
        echo ""
        echo -e "${CYAN}Options:${NC}"
        echo "1. Enter drive ID or paste drive URL"
        echo "2. Search for drive by name" 
        echo "x. Cancel"
        echo ""
        read -p "Select option (1-2, x): " input_option
        
        case $input_option in
            1)
                read -p "$prompt: " user_input
                if [[ -n "$user_input" ]]; then
                    # Check if it's a URL and extract ID
                    if [[ "$user_input" =~ https://drive\.google\.com/drive/folders/([a-zA-Z0-9_-]+) ]]; then
                        drive_id="${BASH_REMATCH[1]}"
                        echo -e "${GREEN}Extracted drive ID from URL: $drive_id${NC}"
                    elif [[ "$user_input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                        drive_id="$user_input"
                        echo -e "${GREEN}Using drive ID: $drive_id${NC}"
                    else
                        echo -e "${RED}Invalid format. Please enter a valid drive ID or URL.${NC}"
                        read -p "Press Enter to try again..."
                    fi
                fi
                ;;
            2)
                read -p "Enter drive name to search: " search_name
                if [[ -n "$search_name" ]]; then
                    echo -e "${CYAN}Searching for drives containing '$search_name'...${NC}"
                    # Show GAM command being executed
                    echo -e "${YELLOW}Executing: $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} print shareddrives name query name contains '$search_name'${NC}"
                    
                    local search_results
                    search_results=$($GAM user "${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}}" print shareddrives name query "name contains '$search_name'" 2>/dev/null | tail -n +2)
                    
                    if [[ -n "$search_results" ]]; then
                        echo -e "${GREEN}Found drives:${NC}"
                        echo "$search_results" | nl -w2 -s'. '
                        echo ""
                        read -p "Enter the number of the drive to select (or press Enter to cancel): " selection
                        
                        if [[ "$selection" =~ ^[0-9]+$ ]]; then
                            local selected_line=$(echo "$search_results" | sed -n "${selection}p")
                            if [[ -n "$selected_line" ]]; then
                                drive_id=$(echo "$selected_line" | cut -d',' -f1)
                                local drive_name=$(echo "$selected_line" | cut -d',' -f2)
                                echo -e "${GREEN}Selected: $drive_name (ID: $drive_id)${NC}"
                            else
                                echo -e "${RED}Invalid selection${NC}"
                                read -p "Press Enter to try again..."
                            fi
                        fi
                    else
                        echo -e "${RED}No drives found containing '$search_name'${NC}"
                        read -p "Press Enter to try again..."
                    fi
                fi
                ;;
            x|X)
                return 1  # User cancelled
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                read -p "Press Enter to try again..."
                ;;
        esac
    done
    
    echo "$drive_id"
    return 0
}

shared_drive_cleanup_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Shared Drive & Account Management Operations ===${NC}"
        echo ""
        echo -e "${GREEN}=== SHARED DRIVE OPERATIONS ===${NC}"
        echo "1. Clean shared drive (remove all pending deletion markers)"
        echo "2. Remove pending deletion markers (interactive)"
        echo "3. Grant gwombat access to shared drive files"
        echo "4. Create archived shared drive for user"
        echo ""
        echo -e "${GREEN}=== ACCOUNT ANALYSIS ===${NC}"
        echo "5. Analyze accounts with no file sharing"
        echo "6. File activity analysis (recent vs old files)"
        echo "7. Transfer file ownership to gwombat"
        echo ""
        echo -e "${GREEN}=== GROUP & DATE MANAGEMENT ===${NC}"
        echo "8. Backup/restore user group memberships"
        echo "9. Add members to group (bulk operations)"
        echo "10. Remove user from all groups"
        echo "11. Restore file modification dates"
        echo ""
        echo "12. Dry-run: Preview cleanup operations"
        echo "13. Return to administrative tools menu"
        echo ""
        echo "m. Return to main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-13, m, x): " cleanup_choice
        echo ""
        
        case $cleanup_choice in
            1)
                drive_id=$(get_shared_drive_id "Enter shared drive ID or URL")
                if [[ $? -eq 0 && -n "$drive_id" ]]; then
                    cleanup_shared_drive "$drive_id" false
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                drive_id=$(get_shared_drive_id "Enter shared drive ID or URL")
                if [[ $? -eq 0 && -n "$drive_id" ]]; then
                    remove_pending_from_shared_drive "$drive_id" false
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                drive_id=$(get_shared_drive_id "Enter shared drive ID or URL for preview")
                if [[ $? -eq 0 && -n "$drive_id" ]]; then
                    echo ""
                    echo -e "${CYAN}Choose preview type:${NC}"
                    echo "1. Full cleanup preview"
                    echo "2. Interactive cleanup preview"
                    read -p "Select (1-2): " preview_type
                    
                    case $preview_type in
                        1)
                            cleanup_shared_drive "$drive_id" true
                            ;;
                        2)
                            remove_pending_from_shared_drive "$drive_id" true
                            ;;
                        *)
                            echo -e "${RED}Invalid option${NC}"
                            ;;
                    esac
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                drive_id=$(get_shared_drive_id "Enter shared drive ID or URL")
                if [[ $? -eq 0 && -n "$drive_id" ]]; then
                    shared_drive_operations "grant_admin_access" "$drive_id"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    drive_id=$(shared_drive_operations "create_user_drive" "" "$user_email")
                    echo "Shared drive created: $drive_id"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                echo -e "${CYAN}Select scope for analysis:${NC}"
                echo "1. All suspended accounts"
                echo "2. Suspended Accounts OU"
                read -p "Select (1-2): " scope_choice
                case $scope_choice in
                    1) analyze_accounts_no_sharing "suspended" ;;
                    2) analyze_accounts_no_sharing "ou" ;;
                    *) echo -e "${RED}Invalid option${NC}" ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            15)
                read -p "Enter user email: " user_email
                read -p "Enter days threshold (default 90): " days_threshold
                days_threshold="${days_threshold:-90}"
                if [[ -n "$user_email" ]]; then
                    analyze_file_activity "$user_email" "$days_threshold"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    echo -e "${YELLOW}This will transfer ALL files from $user_email to gwombat${NC}"
                    read -p "Are you sure? (yes/no): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        transfer_ownership_to_gwombat "$user_email"
                    else
                        echo "Operation cancelled"
                    fi
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            14)
                read -p "Enter user email: " user_email
                echo -e "${CYAN}Select operation:${NC}"
                echo "1. Backup and remove group memberships"
                echo "2. Restore group memberships"
                read -p "Select (1-2): " group_op
                if [[ -n "$user_email" ]]; then
                    case $group_op in
                        1) manage_suspension_groups "$user_email" "backup" ;;
                        2) manage_suspension_groups "$user_email" "restore" ;;
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                read -p "Enter group name: " group_name
                read -p "Enter path to file containing member emails (one per line): " members_file
                if [[ -n "$group_name" && -n "$members_file" ]]; then
                    if [[ -f "$members_file" ]]; then
                        bulk_add_to_group "$group_name" "$members_file"
                        read -p "Press Enter to continue..."
                    else
                        echo -e "${RED}File not found: $members_file${NC}"
                        read -p "Press Enter to continue..."
                    fi
                else
                    echo -e "${RED}Group name and members file path cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    echo -e "${YELLOW}This will remove $user_email from ALL groups${NC}"
                    read -p "Are you sure? (yes/no): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        remove_user_from_all_groups "$user_email"
                    else
                        echo "Operation cancelled"
                    fi
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            14)
                read -p "Enter user email: " user_email
                read -p "Enter target date (YYYY-MM-DD, default 2023-05-01): " target_date
                target_date="${target_date:-2023-05-01}"
                if [[ -n "$user_email" ]]; then
                    restore_file_dates "$user_email" "$target_date"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                drive_id=$(get_shared_drive_id "Enter shared drive ID or URL for preview")
                if [[ $? -eq 0 && -n "$drive_id" ]]; then
                    echo ""
                    echo -e "${CYAN}Choose preview type:${NC}"
                    echo "1. Full cleanup preview"
                    echo "2. Interactive cleanup preview"
                    read -p "Select (1-2): " preview_type
                    case $preview_type in
                        1)
                            cleanup_shared_drive "$drive_id" true
                            ;;
                        2)
                            remove_pending_from_shared_drive "$drive_id" true
                            ;;
                        *)
                            echo -e "${RED}Invalid option${NC}"
                            ;;
                    esac
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            16)
                return
                ;;
            m|M)
                clear
                show_main_menu
                return
                ;;
            x|X)
                echo -e "${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-13, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# License management functions
manage_user_license() {
    local username="$1"
    local action="$2"
    local license_type="${3:-Google Workspace for Education Plus}"
    
    if [[ -z "$username" || -z "$action" ]]; then
        echo -e "${RED}Error: Username and action are required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== License Management: $username ===${NC}"
    echo ""
    
    case "$action" in
        "add")
            echo -e "${CYAN}Adding license '$license_type' to $username...${NC}"
            if $GAM user "$username" add license "$license_type" 2>/dev/null; then
                echo -e "${GREEN}Successfully added license '$license_type' to $username${NC}"
                log_info "Added license '$license_type' to user $username"
            else
                echo -e "${RED}Failed to add license '$license_type' to $username${NC}"
                log_error "Failed to add license '$license_type' to user $username"
                return 1
            fi
            ;;
        "remove")
            echo -e "${CYAN}Removing license '$license_type' from $username...${NC}"
            if $GAM user "$username" delete license "$license_type" 2>/dev/null; then
                echo -e "${GREEN}Successfully removed license '$license_type' from $username${NC}"
                log_info "Removed license '$license_type' from user $username"
            else
                echo -e "${RED}Failed to remove license '$license_type' from $username${NC}"
                log_error "Failed to remove license '$license_type' from user $username"
                return 1
            fi
            ;;
        "show")
            echo -e "${CYAN}Current licenses for $username:${NC}"
            $GAM user "$username" print licenses 2>/dev/null || echo -e "${RED}Failed to retrieve licenses for $username${NC}"
            ;;
        *)
            echo -e "${RED}Invalid action: $action. Use 'add', 'remove', or 'show'${NC}"
            return 1
            ;;
    esac
}

license_management_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== License Management ===${NC}"
        echo ""
        echo "Manage Google Workspace licenses for users."
        echo ""
        echo "1. Add license to user"
        echo "2. Remove license from user"
        echo "3. Show user licenses"
        echo "4. Batch license operations"
        echo "5. Return to discovery menu"
        echo ""
        read -p "Select an option (1-5): " license_choice
        echo ""
        
        case $license_choice in
            1)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    echo "Available license types:"
                    echo "1. Google Workspace for Education Plus (default)"
                    echo "2. Google Workspace for Education Standard"
                    echo "3. Custom license name"
                    read -p "Select license type (1-3): " license_type_choice
                    
                    case $license_type_choice in
                        1) license_type="Google Workspace for Education Plus" ;;
                        2) license_type="Google Workspace for Education Standard" ;;
                        3) 
                            read -p "Enter custom license name: " license_type
                            [[ -z "$license_type" ]] && license_type="Google Workspace for Education Plus"
                            ;;
                        *) license_type="Google Workspace for Education Plus" ;;
                    esac
                    
                    manage_user_license "$username" "add" "$license_type"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    echo "Available license types:"
                    echo "1. Google Workspace for Education Plus (default)"
                    echo "2. Google Workspace for Education Standard"
                    echo "3. Custom license name"
                    read -p "Select license type (1-3): " license_type_choice
                    
                    case $license_type_choice in
                        1) license_type="Google Workspace for Education Plus" ;;
                        2) license_type="Google Workspace for Education Standard" ;;
                        3) 
                            read -p "Enter custom license name: " license_type
                            [[ -z "$license_type" ]] && license_type="Google Workspace for Education Plus"
                            ;;
                        *) license_type="Google Workspace for Education Plus" ;;
                    esac
                    
                    manage_user_license "$username" "remove" "$license_type"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    manage_user_license "$username" "show"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                echo -e "${CYAN}Batch License Operations${NC}"
                echo ""
                read -p "Enter path to file containing usernames (one per line): " user_file
                if [[ -f "$user_file" ]]; then
                    echo "1. Add license to all users"
                    echo "2. Remove license from all users"
                    echo "3. Show licenses for all users"
                    read -p "Select operation (1-3): " batch_operation
                    
                    case $batch_operation in
                        1) batch_action="add" ;;
                        2) batch_action="remove" ;;
                        3) batch_action="show" ;;
                        *) 
                            echo -e "${RED}Invalid operation${NC}"
                            read -p "Press Enter to continue..."
                            continue
                            ;;
                    esac
                    
                    if [[ "$batch_action" != "show" ]]; then
                        echo "Available license types:"
                        echo "1. Google Workspace for Education Plus (default)"
                        echo "2. Google Workspace for Education Standard"
                        echo "3. Custom license name"
                        read -p "Select license type (1-3): " license_type_choice
                        
                        case $license_type_choice in
                            1) license_type="Google Workspace for Education Plus" ;;
                            2) license_type="Google Workspace for Education Standard" ;;
                            3) 
                                read -p "Enter custom license name: " license_type
                                [[ -z "$license_type" ]] && license_type="Google Workspace for Education Plus"
                                ;;
                            *) license_type="Google Workspace for Education Plus" ;;
                        esac
                    fi
                    
                    echo -e "${CYAN}Processing users from file...${NC}"
                    local total_users=$(wc -l < "$user_file")
                    local current_user=0
                    local success_count=0
                    local error_count=0
                    
                    while read -r username; do
                        [[ -z "$username" ]] && continue
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of $total_users: $username ===${NC}"
                        
                        if manage_user_license "$username" "$batch_action" "$license_type"; then
                            ((success_count++))
                        else
                            ((error_count++))
                        fi
                    done < "$user_file"
                    
                    echo ""
                    echo -e "${GREEN}Batch operation completed${NC}"
                    echo -e "${CYAN}Total users processed: $current_user${NC}"
                    echo -e "${GREEN}Successful operations: $success_count${NC}"
                    echo -e "${RED}Failed operations: $error_count${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}File not found: $user_file${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-5.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Orphaned file collection functions
collect_orphaned_files() {
    local username="$1"
    local target_folder="${2:-Orphans - #user#}"
    local use_shortcuts="${3:-true}"
    
    if [[ -z "$username" ]]; then
        echo -e "${RED}Error: Username is required${NC}"
        return 1
    fi
    
    # Sanitize inputs to prevent command injection
    username=$(sanitize_gam_input "$username")
    target_folder=$(sanitize_gam_input "$target_folder")
    
    if [[ -z "$username" ]]; then
        echo -e "${RED}Error: Username became empty after sanitization${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Collecting Orphaned Files for: $username ===${NC}"
    echo ""
    
    # Validate user exists
    if ! $GAM info user "$username" >/dev/null 2>&1; then
        echo -e "${RED}Error: User $username not found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Collecting orphaned files...${NC}"
    echo "Target folder: $target_folder"
    echo "Use shortcuts: $use_shortcuts"
    echo ""
    
    local gam_command="$GAM user \"$username\" collect orphans targetuserfoldername \"$target_folder\""
    if [[ "$use_shortcuts" == "true" ]]; then
        gam_command="$gam_command useshortcuts"
    fi
    
    echo -e "${YELLOW}Running: $gam_command${NC}"
    echo ""
    
    if eval "$gam_command" 2>&1; then
        echo ""
        echo -e "${GREEN}Successfully collected orphaned files for $username${NC}"
        log_info "Collected orphaned files for user $username into folder '$target_folder'"
    else
        echo ""
        echo -e "${RED}Failed to collect orphaned files for $username${NC}"
        log_error "Failed to collect orphaned files for user $username"
        return 1
    fi
}

orphaned_file_collection_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Orphaned File Collection ===${NC}"
        echo ""
        echo "This tool collects files owned by a user that are located"
        echo "in folders owned by other users into a designated folder."
        echo ""
        echo "1. Collect orphaned files for single user"
        echo "2. Collect orphaned files for multiple users"
        echo "3. Batch collection from file"
        echo "4. Return to discovery menu"
        echo ""
        read -p "Select an option (1-4): " orphan_choice
        echo ""
        
        case $orphan_choice in
            1)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    read -p "Target folder name (default: Orphans - #user#): " target_folder
                    [[ -z "$target_folder" ]] && target_folder="Orphans - #user#"
                    
                    echo "Use shortcuts instead of moving files?"
                    echo "1. Yes (create shortcuts, faster)"
                    echo "2. No (move actual files)"
                    read -p "Select (1-2): " shortcut_choice
                    
                    case $shortcut_choice in
                        1) use_shortcuts="true" ;;
                        2) use_shortcuts="false" ;;
                        *) use_shortcuts="true" ;;
                    esac
                    
                    collect_orphaned_files "$username" "$target_folder" "$use_shortcuts"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                echo -e "${CYAN}Enter usernames (one per line, empty line to finish):${NC}"
                local usernames=()
                while true; do
                    read -p "Username: " username
                    [[ -z "$username" ]] && break
                    usernames+=("$username")
                done
                
                if [[ ${#usernames[@]} -gt 0 ]]; then
                    read -p "Target folder name (default: Orphans - #user#): " target_folder
                    [[ -z "$target_folder" ]] && target_folder="Orphans - #user#"
                    
                    echo "Use shortcuts instead of moving files?"
                    echo "1. Yes (create shortcuts, faster)"
                    echo "2. No (move actual files)"
                    read -p "Select (1-2): " shortcut_choice
                    
                    case $shortcut_choice in
                        1) use_shortcuts="true" ;;
                        2) use_shortcuts="false" ;;
                        *) use_shortcuts="true" ;;
                    esac
                    
                    echo -e "${CYAN}Processing ${#usernames[@]} users...${NC}"
                    local current_user=0
                    local success_count=0
                    local error_count=0
                    
                    for username in "${usernames[@]}"; do
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of ${#usernames[@]} ===${NC}"
                        
                        if collect_orphaned_files "$username" "$target_folder" "$use_shortcuts"; then
                            ((success_count++))
                        else
                            ((error_count++))
                        fi
                    done
                    
                    echo ""
                    echo -e "${GREEN}Batch collection completed${NC}"
                    echo -e "${CYAN}Total users processed: $current_user${NC}"
                    echo -e "${GREEN}Successful collections: $success_count${NC}"
                    echo -e "${RED}Failed collections: $error_count${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}No usernames provided${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                read -p "Enter path to file containing usernames (one per line): " user_file
                if [[ -f "$user_file" ]]; then
                    read -p "Target folder name (default: Orphans - #user#): " target_folder
                    [[ -z "$target_folder" ]] && target_folder="Orphans - #user#"
                    
                    echo "Use shortcuts instead of moving files?"
                    echo "1. Yes (create shortcuts, faster)"
                    echo "2. No (move actual files)"
                    read -p "Select (1-2): " shortcut_choice
                    
                    case $shortcut_choice in
                        1) use_shortcuts="true" ;;
                        2) use_shortcuts="false" ;;
                        *) use_shortcuts="true" ;;
                    esac
                    
                    echo -e "${CYAN}Processing users from file...${NC}"
                    local total_users=$(wc -l < "$user_file")
                    local current_user=0
                    local success_count=0
                    local error_count=0
                    
                    while read -r username; do
                        [[ -z "$username" ]] && continue
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of $total_users ===${NC}"
                        
                        if collect_orphaned_files "$username" "$target_folder" "$use_shortcuts"; then
                            ((success_count++))
                        else
                            ((error_count++))
                        fi
                    done < "$user_file"
                    
                    echo ""
                    echo -e "${GREEN}Batch collection completed${NC}"
                    echo -e "${CYAN}Total users processed: $current_user${NC}"
                    echo -e "${GREEN}Successful collections: $success_count${NC}"
                    echo -e "${RED}Failed collections: $error_count${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}File not found: $user_file${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-4.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# File sharing analysis functions
analyze_user_file_sharing() {
    local username="$1"
    local force_mode="${2:-false}"
    local pending_mode="${3:-false}"
    local make_report="${4:-true}"
    
    if [[ -z "$username" ]]; then
        echo -e "${RED}Error: Username is required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== File Sharing Analysis: $username ===${NC}"
    echo ""
    
    # Validate user exists
    if ! $GAM info user "$username" >/dev/null 2>&1; then
        echo -e "${RED}Error: User $username not found${NC}"
        return 1
    fi
    
    # Check if user is suspended
    local user_suspended=$($GAM info user "$username" | grep -c "Account Suspended: True" || echo "0")
    if [[ $user_suspended -eq 0 ]] && [[ "$force_mode" != "true" ]]; then
        echo -e "${YELLOW}Warning: User $username is not suspended. Use force mode to proceed anyway.${NC}"
        read -p "Continue anyway? (y/n): " continue_anyway
        [[ "$continue_anyway" != "y" ]] && [[ "$continue_anyway" != "Y" ]] && return 1
    fi
    
    # Create analysis directory structure
    local analysis_dir="listshared"
    local cache_dir="$analysis_dir/cache"
    local temp_dir="$analysis_dir/temp"
    
    mkdir -p "$cache_dir" "$temp_dir"
    
    # Also ensure reports directory exists for output
    mkdir -p "reports"
    
    echo -e "${CYAN}Step 1: Analyzing all files for $username...${NC}"
    
    # Get all files for the user
    local all_files_csv="$analysis_dir/${username}_all_files.csv"
    if [[ "$force_mode" == "true" ]] || [[ ! -f "$all_files_csv" ]]; then
        echo -e "${CYAN}Retrieving complete file list...${NC}"
        if ! $GAM user "$username" print filelist id title mimeType owners.emailAddress size shared webViewLink modifiedTime > "$all_files_csv" 2>/dev/null; then
            echo -e "${RED}Failed to retrieve file list for $username${NC}"
            return 1
        fi
        echo -e "${GREEN}Retrieved $(wc -l < "$all_files_csv") files${NC}"
    else
        echo -e "${YELLOW}Using existing file list ($(wc -l < "$all_files_csv") files)${NC}"
    fi
    
    echo -e "${CYAN}Step 2: Filtering shared files...${NC}"
    
    # Filter to only shared files
    local shared_files_csv="$analysis_dir/${username}_shared_files.csv"
    head -n 1 "$all_files_csv" > "$shared_files_csv"
    awk -F, 'NR>1 && $6=="True" {print}' "$all_files_csv" >> "$shared_files_csv"
    
    local shared_count=$(tail -n +2 "$shared_files_csv" | wc -l)
    echo -e "${GREEN}Found $shared_count shared files${NC}"
    
    if [[ $shared_count -eq 0 ]]; then
        echo -e "${YELLOW}No shared files found for $username${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Step 3: Analyzing file sharing permissions...${NC}"
    
    # Get detailed sharing information
    local shared_with_emails_csv="$analysis_dir/${username}_shared_files_with_emails.csv"
    analyze_file_permissions "$username" "$shared_files_csv" "$shared_with_emails_csv"
    
    echo -e "${CYAN}Step 4: Identifying active recipient accounts...${NC}"
    
    # Check which shared recipients are active
    local active_shares_csv="$analysis_dir/${username}_active-shares.csv"
    identify_active_recipients "$username" "$shared_with_emails_csv" "$active_shares_csv"
    
    local active_count=$(tail -n +2 "$active_shares_csv" | wc -l 2>/dev/null || echo "0")
    echo -e "${GREEN}Found $active_count files shared with active ${DOMAIN:-yourdomain.edu} accounts${NC}"
    
    if [[ $active_count -gt 0 ]]; then
        echo -e "${CYAN}Step 5: Adding file path information...${NC}"
        
        # Add paths to the analysis
        local with_paths_csv="$analysis_dir/${username}_shared-files-with-path.csv"
        add_file_paths "$username" "$active_shares_csv" "$with_paths_csv"
        
        if [[ "$make_report" == "true" ]]; then
            echo -e "${CYAN}Step 6: Generating sharing reports...${NC}"
            generate_sharing_reports "$username" "$with_paths_csv"
        fi
        
        if [[ "$pending_mode" == "true" ]]; then
            echo -e "${CYAN}Step 7: Updating filenames with pending deletion labels...${NC}"
            update_pending_deletion_filenames "$username" "$active_shares_csv"
        fi
    fi
    
    # Store analysis results in database for future reference
    if [[ -f "$active_shares_csv" ]]; then
        local analysis_id="${username}_$(date +%Y%m%d_%H%M%S)"
        echo -e "${CYAN}Storing analysis results in database...${NC}"
        
        # Create table if it doesn't exist
        sqlite3 local-config/account_lifecycle.db "
            CREATE TABLE IF NOT EXISTS sharing_analysis_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                analysis_id TEXT,
                email TEXT,
                total_files INTEGER,
                shared_files INTEGER,
                active_recipients INTEGER,
                csv_files_path TEXT,
                analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        " 2>/dev/null
        
        # Store summary
        sqlite3 local-config/account_lifecycle.db "
            INSERT INTO sharing_analysis_results (
                analysis_id, email, total_files, shared_files, active_recipients, csv_files_path
            ) VALUES (
                '$analysis_id', '$username', 
                $(tail -n +2 "$all_files_csv" 2>/dev/null | wc -l || echo "0"),
                $shared_count, $active_count, '$analysis_dir'
            );
        " 2>/dev/null
        
        echo -e "${GREEN}Analysis results stored in database (ID: $analysis_id)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}File sharing analysis completed for $username${NC}"
    echo -e "${CYAN}Results saved in: $analysis_dir/${NC}"
    echo -e "${CYAN}- All files: $all_files_csv${NC}"
    echo -e "${CYAN}- Shared files: $shared_files_csv${NC}"
    echo -e "${CYAN}- Active shares: $active_shares_csv${NC}"
    if [[ -f "$with_paths_csv" ]]; then
        echo -e "${CYAN}- With paths: $with_paths_csv${NC}"
    fi
    
    log_info "File sharing analysis completed for $username: $shared_count shared files, $active_count active recipients"
}

# Function to export database analysis results to CSV
export_analysis_to_csv() {
    local analysis_id="$1"
    local output_dir="${2:-exports}"
    
    mkdir -p "$output_dir"
    
    if [[ -z "$analysis_id" ]]; then
        echo -e "${RED}Error: Analysis ID required${NC}"
        echo "Available analyses:"
        sqlite3 local-config/account_lifecycle.db "SELECT analysis_id, email, analyzed_at FROM sharing_analysis_results ORDER BY analyzed_at DESC LIMIT 10;" 2>/dev/null
        return 1
    fi
    
    local export_file="$output_dir/analysis_${analysis_id}.csv"
    
    echo -e "${CYAN}Exporting analysis $analysis_id to CSV...${NC}"
    
    sqlite3 local-config/account_lifecycle.db -header -csv "
        SELECT 
            analysis_id,
            email,
            total_files,
            shared_files,
            active_recipients,
            analyzed_at
        FROM sharing_analysis_results 
        WHERE analysis_id='$analysis_id';
    " > "$export_file" 2>/dev/null
    
    if [[ -f "$export_file" && -s "$export_file" ]]; then
        echo -e "${GREEN}Analysis exported to: $export_file${NC}"
        return 0
    else
        echo -e "${RED}Failed to export analysis or no data found${NC}"
        return 1
    fi
}

# Function to import CSV data into database
import_csv_to_database() {
    local csv_file="$1"
    local import_type="${2:-analysis}"  # analysis, accounts, etc.
    
    if [[ ! -f "$csv_file" ]]; then
        echo -e "${RED}Error: CSV file not found: $csv_file${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Importing $csv_file into database...${NC}"
    
    case "$import_type" in
        "analysis")
            # Import sharing analysis results
            local import_id="import_$(date +%Y%m%d_%H%M%S)"
            local imported=0
            
            tail -n +2 "$csv_file" | while IFS=',' read -r analysis_id email total_files shared_files active_recipients analyzed_at; do
                sqlite3 local-config/account_lifecycle.db "
                    INSERT INTO sharing_analysis_results (
                        analysis_id, email, total_files, shared_files, active_recipients, analyzed_at
                    ) VALUES (
                        '$analysis_id', '$email', '$total_files', '$shared_files', '$active_recipients', '$analyzed_at'
                    );
                " 2>/dev/null && ((imported++))
            done
            
            echo -e "${GREEN}Imported $imported records into database${NC}"
            ;;
        *)
            echo -e "${RED}Unknown import type: $import_type${NC}"
            return 1
            ;;
    esac
}

analyze_file_permissions() {
    local username="$1"
    local shared_files_csv="$2" 
    local output_csv="$3"
    
    # Create header for output file
    echo "owner,id,filename,mimeType,size,webViewLink,modifiedTime,sharedWithEmail" > "$output_csv"
    
    local temp_permissions=$(mktemp)
    local processed=0
    local total=$(tail -n +2 "$shared_files_csv" | wc -l)
    
    # Process each shared file to extract permissions
    tail -n +2 "$shared_files_csv" | while IFS=, read -r owner fileid filename mimetype size shared webviewlink modifiedtime; do
        ((processed++))
        
        if [[ $((processed % 10)) -eq 0 ]]; then
            echo -e "${CYAN}Processing permissions: $processed/$total files...${NC}"
        fi
        
        # Get sharing permissions for this file
        $GAM user "$username" print drivefileacl "$fileid" 2>/dev/null | tail -n +2 | while IFS=, read -r aclid aclrole acltype aclemail aclname acldomain; do
            # Only include user permissions with email addresses
            if [[ "$acltype" == "user" ]] && [[ -n "$aclemail" ]] && [[ "$aclemail" != "$username" ]]; then
                # Clean up filename for CSV
                clean_filename=$(echo "$filename" | tr ',' ';')
                echo "$owner,$fileid,$clean_filename,$mimetype,$size,$webviewlink,$modifiedtime,$aclemail" >> "$output_csv"
            fi
        done
    done
    
    echo -e "${GREEN}Extracted sharing permissions for $total files${NC}"
}

identify_active_recipients() {
    local username="$1"
    local shared_with_emails_csv="$2"
    local output_csv="$3"
    
    if [[ ! -f "$shared_with_emails_csv" ]]; then
        echo -e "${RED}Error: Shared files with emails CSV not found${NC}"
        return 1
    fi
    
    # Extract unique email addresses
    local temp_emails=$(mktemp)
    tail -n +2 "$shared_with_emails_csv" | cut -d, -f8 | grep "@${DOMAIN:-yourdomain.edu}" | sort -u > "$temp_emails"
    
    local total_emails=$(wc -l < "$temp_emails")
    echo -e "${CYAN}Checking suspension status for $total_emails unique email addresses...${NC}"
    
    # Check suspension status for each email
    local active_emails=$(mktemp)
    local processed=0
    
    while read -r email; do
        ((processed++))
        if [[ $((processed % 5)) -eq 0 ]]; then
            echo -e "${CYAN}Checking: $processed/$total_emails emails...${NC}"
        fi
        
        # Check if user exists and is not suspended
        local user_info=$($GAM info user "$email" 2>/dev/null)
        if [[ $? -eq 0 ]] && echo "$user_info" | grep -q "Account Suspended: False"; then
            echo "$email" >> "$active_emails"
        fi
    done < "$temp_emails"
    
    local active_count=$(wc -l < "$active_emails")
    echo -e "${GREEN}Found $active_count active ${DOMAIN:-yourdomain.edu} recipients${NC}"
    
    # Filter shared files to only include those shared with active users
    head -n 1 "$shared_with_emails_csv" > "$output_csv"
    
    while read -r active_email; do
        grep ",$active_email$" "$shared_with_emails_csv" >> "$output_csv"
    done < "$active_emails"
    
    # Clean up temp files
    rm -f "$temp_emails" "$active_emails"
}

add_file_paths() {
    local username="$1"
    local input_csv="$2"
    local output_csv="$3"
    
    if [[ ! -f "$input_csv" ]]; then
        echo -e "${RED}Error: Input CSV not found${NC}"
        return 1
    fi
    
    # Add path column to header
    head -n 1 "$input_csv" | sed 's/$/,path/' > "$output_csv"
    
    local processed=0
    local total=$(tail -n +2 "$input_csv" | wc -l)
    
    echo -e "${CYAN}Adding file paths for $total files...${NC}"
    
    # Process each file to get its path
    tail -n +2 "$input_csv" | while IFS=, read -r owner fileid filename mimetype size webviewlink modifiedtime email; do
        ((processed++))
        
        if [[ $((processed % 5)) -eq 0 ]]; then
            echo -e "${CYAN}Processing paths: $processed/$total files...${NC}"
        fi
        
        # Get file path using GAM
        local file_path=""
        local file_info=$($GAM user "$username" show fileinfo "$fileid" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            # Extract parent folder information and build path
            local parent_id=$(echo "$file_info" | grep "Parent ID" | head -n 1 | cut -d' ' -f3)
            if [[ -n "$parent_id" && "$parent_id" != "None" ]]; then
                file_path=$(build_file_path "$username" "$parent_id")
            else
                file_path="/ (Root)"
            fi
        else
            file_path="Unknown"
        fi
        
        # Clean path for CSV
        clean_path=$(echo "$file_path" | tr ',' ';')
        echo "$owner,$fileid,$filename,$mimetype,$size,$webviewlink,$modifiedtime,$email,$clean_path" >> "$output_csv"
    done
    
    echo -e "${GREEN}Added path information for $total files${NC}"
}

build_file_path() {
    local username="$1"
    local folder_id="$2"
    local cache_dir="listshared/cache"
    local path_cache="$cache_dir/paths_cache.txt"
    
    mkdir -p "$cache_dir"
    
    # Check cache first
    if [[ -f "$path_cache" ]]; then
        local cached_path=$(grep "^$folder_id," "$path_cache" 2>/dev/null | cut -d, -f2-)
        if [[ -n "$cached_path" ]]; then
            echo "$cached_path"
            return
        fi
    fi
    
    # Build path by traversing parents
    local path_components=()
    local current_id="$folder_id"
    local max_depth=20  # Prevent infinite loops
    local depth=0
    
    while [[ -n "$current_id" && "$current_id" != "None" && $depth -lt $max_depth ]]; do
        local folder_info=$($GAM user "$username" show fileinfo "$current_id" 2>/dev/null)
        
        if [[ $? -ne 0 ]]; then
            break
        fi
        
        local folder_name=$(echo "$folder_info" | grep "Title" | head -n 1 | cut -d' ' -f2-)
        local parent_id=$(echo "$folder_info" | grep "Parent ID" | head -n 1 | cut -d' ' -f3)
        
        # Clean up folder name (remove pending deletion markers for path display)
        clean_folder_name=$(echo "$folder_name" | sed 's/ (PENDING DELETION - CONTACT OIT)//g')
        path_components=("$clean_folder_name" "${path_components[@]}")
        
        current_id="$parent_id"
        ((depth++))
    done
    
    # Build final path
    local final_path="/"
    if [[ ${#path_components[@]} -gt 0 ]]; then
        final_path="/${path_components[*]}"
        final_path=${final_path// /\/}  # Replace spaces with slashes
    fi
    
    # Cache the result
    echo "$folder_id,$final_path" >> "$path_cache"
    
    echo "$final_path"
}

generate_sharing_reports() {
    local username="$1"
    local input_csv="$2"
    
    if [[ ! -f "$input_csv" ]]; then
        echo -e "${RED}Error: Input CSV not found for report generation${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Generating sharing reports...${NC}"
    
    # Get user's real name for reports
    local user_info=$($GAM info user "$username" 2>/dev/null)
    local first_name=$(echo "$user_info" | grep "First Name" | cut -d' ' -f3- | tr -d '"')
    local last_name=$(echo "$user_info" | grep "Last Name" | cut -d' ' -f3- | tr -d '"')
    
    [[ -z "$first_name" ]] && first_name="Unknown"
    [[ -z "$last_name" ]] && last_name="User"
    
    # Create report directory
    local report_dir="reports"
    mkdir -p "$report_dir"
    
    # Generate summary report
    local summary_report="$report_dir/${username}_sharing_summary.txt"
    {
        echo "=== FILE SHARING ANALYSIS SUMMARY ==="
        echo "User: $first_name $last_name ($username)"
        echo "Generated: $(date)"
        echo ""
        
        local total_shared=$(tail -n +2 "$input_csv" | wc -l)
        local unique_recipients=$(tail -n +2 "$input_csv" | cut -d, -f8 | sort -u | wc -l)
        
        echo "Total files shared with active ${DOMAIN:-yourdomain.edu} accounts: $total_shared"
        echo "Number of unique active recipients: $unique_recipients"
        echo ""
        
        echo "=== RECIPIENTS ==="
        tail -n +2 "$input_csv" | cut -d, -f8 | sort | uniq -c | sort -nr | while read count email; do
            echo "$email: $count files"
        done
        
        echo ""
        echo "=== FILES BY TYPE ==="
        tail -n +2 "$input_csv" | cut -d, -f4 | sort | uniq -c | sort -nr | while read count mimetype; do
            echo "$mimetype: $count files"
        done
        
    } > "$summary_report"
    
    echo -e "${GREEN}Generated summary report: $summary_report${NC}"
    
    # Generate individual recipient reports
    tail -n +2 "$input_csv" | cut -d, -f8 | sort -u | while read recipient_email; do
        local recipient_report="$report_dir/${recipient_email}_files_from_${username}.csv"
        
        # Create header
        echo "sharerFirstName,sharerLastName,filename,mimeType,size,webViewLink,modifiedTime,sharedwith,path" > "$recipient_report"
        
        # Add files shared with this recipient
        grep ",$recipient_email$" "$input_csv" | while IFS=, read -r owner fileid filename mimetype size webviewlink modifiedtime email path; do
            echo "$first_name,$last_name,$filename,$mimetype,$size,$webviewlink,$modifiedtime,$email,$path" >> "$recipient_report"
        done
        
        local file_count=$(tail -n +2 "$recipient_report" | wc -l)
        echo -e "${CYAN}Generated report for $recipient_email: $file_count files${NC}"
    done
    
    log_info "Generated sharing reports for $username"
}

update_pending_deletion_filenames() {
    local username="$1"
    local active_shares_csv="$2"
    
    if [[ ! -f "$active_shares_csv" ]]; then
        echo -e "${RED}Error: Active shares CSV not found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Updating filenames with PENDING DELETION labels...${NC}"
    
    local updated_count=0
    local total=$(tail -n +2 "$active_shares_csv" | wc -l)
    
    tail -n +2 "$active_shares_csv" | while IFS=, read -r owner fileid filename mimetype size webviewlink modifiedtime email; do
        # Check if filename already has pending deletion marker
        if [[ "$filename" != *"(PENDING DELETION - CONTACT OIT)"* ]]; then
            local new_filename="$filename (PENDING DELETION - CONTACT OIT)"
            
            if $GAM user "$username" update drivefile "$fileid" newfilename "$new_filename" 2>/dev/null; then
                echo -e "${GREEN}Updated: $filename${NC}"
                ((updated_count++))
            else
                echo -e "${RED}Failed to update: $filename${NC}"
            fi
        fi
    done
    
    echo -e "${GREEN}Updated $updated_count of $total filenames${NC}"
    log_info "Updated $updated_count filenames with pending deletion labels for $username"
}

generate_recipient_report() {
    local recipient_email="$1"
    
    if [[ -z "$recipient_email" ]]; then
        echo -e "${RED}Error: Recipient email is required${NC}"
        return 1
    fi
    
    echo -e "${BLUE}=== Generating Report for Recipient: $recipient_email ===${NC}"
    echo ""
    
    # Check if recipient exists and is active
    if ! $GAM info user "$recipient_email" >/dev/null 2>&1; then
        echo -e "${RED}Error: Recipient $recipient_email not found${NC}"
        return 1
    fi
    
    local recipient_suspended=$($GAM info user "$recipient_email" | grep -c "Account Suspended: True" || echo "0")
    if [[ $recipient_suspended -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Recipient $recipient_email is suspended${NC}"
    fi
    
    # Search through existing analysis files
    local report_files=()
    for report in local-config/reports/*_files_from_*.csv; do
        if [[ -f "$report" ]] && [[ "$report" == *"${recipient_email}_files_from_"* ]]; then
            report_files+=("$report")
        fi
    done
    
    if [[ ${#report_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No sharing reports found for $recipient_email${NC}"
        echo -e "${CYAN}You may need to run file sharing analysis for suspended users first${NC}"
        return 0
    fi
    
    # Combine all reports for this recipient
    local combined_report="local-config/reports/${recipient_email}_combined_pending_files.csv"
    local temp_combined=$(mktemp)
    
    echo "sharerFirstName,sharerLastName,filename,mimeType,size,webViewLink,modifiedTime,sharedwith,path" > "$combined_report"
    
    local total_files=0
    local total_sharers=0
    
    for report_file in "${report_files[@]}"; do
        if [[ -f "$report_file" ]]; then
            tail -n +2 "$report_file" >> "$temp_combined"
            ((total_sharers++))
        fi
    done
    
    # Sort by sharer name and add to final report
    sort "$temp_combined" >> "$combined_report"
    total_files=$(tail -n +2 "$combined_report" | wc -l)
    
    rm -f "$temp_combined"
    
    echo -e "${GREEN}Generated combined report: $combined_report${NC}"
    echo -e "${CYAN}Total files shared with $recipient_email: $total_files${NC}"
    echo -e "${CYAN}Number of different sharers: $total_sharers${NC}"
    
    # Generate summary
    local summary_file="local-config/reports/${recipient_email}_summary.txt"
    {
        echo "=== PENDING DELETION FILES SHARED WITH $recipient_email ==="
        echo "Generated: $(date)"
        echo ""
        echo "Total files: $total_files"
        echo "Number of different sharers: $total_sharers"
        echo ""
        echo "=== FILES BY SHARER ==="
        tail -n +2 "$combined_report" | cut -d, -f1,2 | sort | uniq -c | sort -nr | while read count first_last; do
            echo "$first_last: $count files"
        done
        echo ""
        echo "=== FILES BY TYPE ==="
        tail -n +2 "$combined_report" | cut -d, -f4 | sort | uniq -c | sort -nr | while read count mimetype; do
            echo "$mimetype: $count files"
        done
    } > "$summary_file"
    
    echo -e "${GREEN}Generated summary: $summary_file${NC}"
    
    log_info "Generated recipient report for $recipient_email: $total_files files from $total_sharers sharers"
}

file_sharing_analysis_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== File Sharing Analysis and Reports ===${NC}"
        echo ""
        echo "This tool analyzes file sharing between suspended accounts and"
        echo "active ${DOMAIN:-yourdomain.edu} users, generating detailed reports."
        echo ""
        echo "1. Analyze single user's file sharing"
        echo "2. Analyze multiple users (batch processing)"
        echo "3. Generate report for active user (what they're receiving)"
        echo "4. Update pending deletion filenames for shared files"
        echo "5. Bulk analysis of all suspended users"
        echo "6. Clean up analysis files"
        echo "7. View analysis statistics"
        echo "8. Return to discovery menu"
        echo ""
        read -p "Select an option (1-8): " sharing_choice
        echo ""
        
        case $sharing_choice in
            1)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    echo ""
                    echo "Analysis options:"
                    echo "1. Standard analysis"
                    echo "2. Force analysis (skip suspension check)"
                    echo "3. Analysis with pending deletion filename updates"
                    echo "4. Analysis without report generation"
                    read -p "Select analysis type (1-4): " analysis_type
                    
                    case $analysis_type in
                        1) analyze_user_file_sharing "$username" false false true ;;
                        2) analyze_user_file_sharing "$username" true false true ;;
                        3) analyze_user_file_sharing "$username" false true true ;;
                        4) analyze_user_file_sharing "$username" false false false ;;
                        *) analyze_user_file_sharing "$username" false false true ;;
                    esac
                    
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                echo -e "${CYAN}Batch File Sharing Analysis${NC}"
                echo ""
                read -p "Enter path to file containing usernames (one per line): " user_file
                if [[ -f "$user_file" ]]; then
                    echo "Analysis options:"
                    echo "1. Standard analysis for all users"
                    echo "2. Force analysis for all users"
                    echo "3. Analysis with pending deletion updates"
                    read -p "Select analysis type (1-3): " batch_type
                    
                    local force_mode=false
                    local pending_mode=false
                    
                    case $batch_type in
                        2) force_mode=true ;;
                        3) pending_mode=true ;;
                    esac
                    
                    echo -e "${CYAN}Processing users from file...${NC}"
                    local total_users=$(wc -l < "$user_file")
                    local current_user=0
                    local success_count=0
                    local error_count=0
                    
                    while read -r username; do
                        [[ -z "$username" ]] && continue
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of $total_users: $username ===${NC}"
                        
                        if analyze_user_file_sharing "$username" "$force_mode" "$pending_mode" true; then
                            ((success_count++))
                        else
                            ((error_count++))
                        fi
                    done < "$user_file"
                    
                    echo ""
                    echo -e "${GREEN}Batch analysis completed${NC}"
                    echo -e "${CYAN}Total users processed: $current_user${NC}"
                    echo -e "${GREEN}Successful analyses: $success_count${NC}"
                    echo -e "${RED}Failed analyses: $error_count${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}File not found: $user_file${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                read -p "Enter active user email to generate report for: " recipient_email
                if [[ -n "$recipient_email" ]]; then
                    generate_recipient_report "$recipient_email"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                read -p "Enter username to update filenames for: " username
                if [[ -n "$username" ]]; then
                    local active_shares_csv="listshared/${username}_active-shares.csv"
                    if [[ -f "$active_shares_csv" ]]; then
                        update_pending_deletion_filenames "$username" "$active_shares_csv"
                    else
                        echo -e "${RED}No active shares analysis found for $username${NC}"
                        echo -e "${CYAN}Please run file sharing analysis first${NC}"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                echo -e "${CYAN}Bulk Analysis of All Suspended Users${NC}"
                echo ""
                echo "This will analyze all users in suspended OUs."
                read -p "Continue? (y/n): " confirm_bulk
                
                if [[ "$confirm_bulk" == "y" || "$confirm_bulk" == "Y" ]]; then
                    # Get all suspended users
                    local suspended_users=$(mktemp)
                    $GAM print users query "orgUnitPath:'/Suspended Accounts'" fields primaryemail > "$suspended_users" 2>/dev/null
                    
                    local total=$(tail -n +2 "$suspended_users" | wc -l)
                    echo -e "${CYAN}Found $total suspended users to analyze${NC}"
                    
                    local processed=0
                    local success=0
                    
                    tail -n +2 "$suspended_users" | while read -r email rest; do
                        ((processed++))
                        echo ""
                        echo -e "${BLUE}=== Processing $processed/$total: $email ===${NC}"
                        
                        if analyze_user_file_sharing "$email" false false true; then
                            ((success++))
                        fi
                    done
                    
                    rm -f "$suspended_users"
                    echo -e "${GREEN}Bulk analysis completed${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}Bulk analysis cancelled${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                echo -e "${CYAN}Clean Up Analysis Files${NC}"
                echo ""
                echo "This will clean up temporary and cache files from analysis."
                echo "Analysis results and reports will be preserved."
                echo ""
                read -p "Continue? (y/n): " confirm_cleanup
                
                if [[ "$confirm_cleanup" == "y" || "$confirm_cleanup" == "Y" ]]; then
                    # Clean up temp and cache files
                    rm -rf listshared/temp/* listshared/cache/*
                    
                    # Clean up old temporary files
                    find listshared/ -name "*.tmp" -delete 2>/dev/null
                    find listshared/ -name "temp-*" -delete 2>/dev/null
                    
                    echo -e "${GREEN}Cleanup completed${NC}"
                else
                    echo -e "${YELLOW}Cleanup cancelled${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${CYAN}File Sharing Analysis Statistics${NC}"
                echo ""
                
                # Count analysis files
                local user_analyses=$(ls listshared/*_all_files.csv 2>/dev/null | wc -l)
                local sharing_analyses=$(ls listshared/*_shared_files.csv 2>/dev/null | wc -l)
                local active_analyses=$(ls listshared/*_active-shares.csv 2>/dev/null | wc -l)
                local recipient_reports=$(ls local-config/reports/*_files_from_*.csv 2>/dev/null | wc -l)
                
                echo "Analysis Files:"
                echo "- User file analyses: $user_analyses"
                echo "- Sharing analyses: $sharing_analyses"  
                echo "- Active share analyses: $active_analyses"
                echo "- Recipient reports: $recipient_reports"
                echo ""
                
                if [[ $active_analyses -gt 0 ]]; then
                    echo "Active Sharing Summary:"
                    local total_active_files=0
                    for file in listshared/*_active-shares.csv; do
                        if [[ -f "$file" ]]; then
                            local count=$(tail -n +2 "$file" | wc -l 2>/dev/null || echo "0")
                            total_active_files=$((total_active_files + count))
                        fi
                    done
                    echo "- Total files shared with active users: $total_active_files"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            14)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-8.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

discovery_mode() {
    DISCOVERY_MODE=true
    echo -e "${MAGENTA}=== DISCOVERY MODE ===${NC}"
    echo ""
    echo "Discovery options:"
    echo "1. Query users in Temporary Hold OU"
    echo "2. Query users in Pending Deletion OU"
    echo "3. Query all suspended users (all OUs)"
    echo "4. Scan active accounts for orphaned pending deletion files"
    echo "5. Query users by department/type"
    echo "6. Diagnose specific account consistency"
    echo "7. Check for incomplete operations"
    echo "8. Shared Drive cleanup operations"
    echo "9. License management operations"
    echo "10. Orphaned file collection"
    echo "11. File sharing analysis and reports"
    echo ""
    echo "12. Return to main menu"
    echo "m. Main menu"
    echo "x. Exit"
    echo ""
    read -p "Select an option (1-12, m, x): " discovery_choice
    
    case $discovery_choice in
        1) 
            query_gwombat_hold_users
            ;;
        2) 
            query_pending_users
            ;;
        3) 
            query_all_suspended_users
            ;;
        4) 
            scan_active_accounts
            ;;
        5) 
            query_users_by_filter
            ;;
        6) 
            user=$(get_user_input)
            diagnose_account "$user"
            ;;
        7) 
            check_incomplete_operations
            ;;
        8) 
            shared_drive_cleanup_menu
            ;;
        9) 
            license_management_menu
            ;;
        10) 
            orphaned_file_collection_menu
            ;;
        11) 
            file_sharing_analysis_menu
            ;;
        12) 
            DISCOVERY_MODE=false
            return
            ;;
        m|M)
            DISCOVERY_MODE=false
            return
            ;;
        x|X)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please select 1-12, m, or x.${NC}"
            echo ""
            read -p "Press Enter to continue..."
            return
            ;;
    esac
    
    DISCOVERY_MODE=false
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Function to check for incomplete operations
check_incomplete_operations() {
    echo -e "${YELLOW}Checking for incomplete operations...${NC}"
    
    # Check for partial log entries
    if [[ -f "${SCRIPTPATH}/gwombat-done.log" ]]; then
        echo "Users in gwombat-done.log: $(wc -l < "${SCRIPTPATH}/gwombat-done.log")"
    fi
    
    if [[ -f "${SCRIPTPATH}/gwombat-removed.log" ]]; then
        echo "Users in gwombat-removed.log: $(wc -l < "${SCRIPTPATH}/gwombat-removed.log")"
    fi
    
    # Check for orphaned tmp files
    if [[ -d "${SCRIPTPATH}/tmp" ]]; then
        tmp_files=$(find "${SCRIPTPATH}/tmp" -name "*-fixed.txt" -o -name "*-removal.txt" | wc -l)
        echo "Temporary operation files found: $tmp_files"
        
        if [[ $tmp_files -gt 0 ]]; then
            echo ""
            echo "Recent operation files:"
            find "${SCRIPTPATH}/tmp" -name "*-fixed.txt" -o -name "*-removal.txt" -exec ls -la {} \; | head -5
        fi
    fi
}

# Function to resume failed operations
resume_failed_operations() {
    echo -e "${YELLOW}Resume functionality - Check for failed operations...${NC}"
    echo "This feature would analyze log files and resume incomplete batch operations."
    echo "(Implementation would require analyzing specific failure points)"
}

# Function to generate comprehensive file list for a user
generate_user_file_list() {
    local user_email="$1"
    local csv_dir="${SCRIPTPATH}/csv-files"
    local output_file="${csv_dir}/${user_email}_shared-files-with-path.csv"
    
    # Create CSV directory if it doesn't exist
    mkdir -p "$csv_dir"
    
    echo "Generating comprehensive file list for $user_email..."
    
    # Get all files owned by the user with sharing details
    $GAM user "$user_email" print filelist \
        fields id,name,owners,permissions,mimeType,size,webViewLink,modifiedTime \
        showownedby me \
        > "${csv_dir}/${user_email}_all_files.csv"
    
    # Create the shared files report with path information
    echo "owner,filename,id,mimeType,size,webViewLink,modifiedTime,sharedwith,path" > "$output_file"
    
    # Process files and add path information
    local counter=0
    local total_files=$(tail -n +2 "${csv_dir}/${user_email}_all_files.csv" | wc -l)
    
    tail -n +2 "${csv_dir}/${user_email}_all_files.csv" | while IFS=',' read -r id name owners permissions mimeType size webViewLink modifiedTime; do
        ((counter++))
        show_progress $counter $total_files "Processing file $counter"
        
        # Check if file has external sharing
        if [[ "$permissions" == *"@${DOMAIN:-yourdomain.edu}"* ]] || [[ "$permissions" == *"anyone"* ]]; then
            # Get path information using build_file_path function
            local path=$(build_file_path "$id")
            echo "$owners,$name,$id,$mimeType,$size,$webViewLink,$modifiedTime,$permissions,$path" >> "$output_file"
        fi
    done
    
    echo "Generated file list at: $output_file"
}

# Function to build file path from Google Drive API
build_file_path() {
    local file_id="$1"
    local path_cache="${SCRIPTPATH}/cache/paths"
    local cache_file="${path_cache}/${file_id}.path"
    
    # Create cache directory
    mkdir -p "$path_cache"
    
    # Check if path is cached
    if [[ -f "$cache_file" ]]; then
        cat "$cache_file"
        return
    fi
    
    # Build path by traversing parent hierarchy
    local current_id="$file_id"
    local path_components=()
    
    while [[ -n "$current_id" && "$current_id" != "root" ]]; do
        # Get file name and parent
        local file_info=$($GAM user "${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}}" show fileinfo "$current_id" fields name,parents 2>/dev/null)
        local name=$(echo "$file_info" | grep "name:" | cut -d' ' -f2-)
        local parent=$(echo "$file_info" | grep "parents:" | cut -d' ' -f2)
        
        if [[ -n "$name" ]]; then
            path_components=("$name" "${path_components[@]}")
        fi
        
        current_id="$parent"
        
        # Prevent infinite loops
        [[ ${#path_components[@]} -gt 20 ]] && break
    done
    
    # Join path components
    local full_path=$(IFS='/'; echo "${path_components[*]}")
    
    # Cache the result
    echo "$full_path" > "$cache_file"
    echo "$full_path"
}

# Function to identify active recipients of shared files
identify_active_recipients() {
    local user_email="$1"
    local csv_dir="${SCRIPTPATH}/csv-files"
    local input_file="${csv_dir}/${user_email}_shared-files-with-path.csv"
    local output_file="${csv_dir}/${user_email}_active-shares.csv"
    
    if [[ ! -f "$input_file" ]]; then
        echo "Error: Input file $input_file not found"
        return 1
    fi
    
    echo "Filtering for files shared with active ${DOMAIN:-yourdomain.edu} accounts..."
    
    # Create header for output file
    head -n 1 "$input_file" > "$output_file"
    
    # Process each line and check if shared with active users
    tail -n +2 "$input_file" | while IFS=',' read -r line; do
        local shared_with=$(echo "$line" | cut -d',' -f8)
        local has_active_share=false
        
        # Extract email addresses from sharing permissions
        local emails=$(echo "$shared_with" | grep -oE '[a-zA-Z0-9._%+-]+@'"${DOMAIN:-your-domain.edu}")
        
        for email in $emails; do
            if [[ "$email" != "$user_email" ]]; then
                # Check if the recipient is active
                local user_status=$($GAM info user "$email" 2>/dev/null | grep "Account Suspended:" | cut -d' ' -f3)
                if [[ "$user_status" != "True" ]]; then
                    has_active_share=true
                    break
                fi
            fi
        done
        
        # Include file if it has active shares
        if [[ "$has_active_share" == true ]]; then
            echo "$line" >> "$output_file"
        fi
    done
    
    local active_count=$(tail -n +2 "$output_file" | wc -l)
    echo "Found $active_count files shared with active ${DOMAIN:-yourdomain.edu} accounts"
}

# Function to analyze user file sharing comprehensively
analyze_user_file_sharing() {
    local user_email="$1"
    local csv_dir="${SCRIPTPATH}/csv-files"
    
    echo -e "${GREEN}Analyzing file sharing for $user_email...${NC}"
    
    # Step 1: Generate comprehensive file list
    generate_user_file_list "$user_email"
    
    # Step 2: Identify files shared with active users only
    identify_active_recipients "$user_email"
    
    # Step 3: Create summary report
    local active_file="${csv_dir}/${user_email}_active-shares.csv"
    local total_shared=$(tail -n +2 "${csv_dir}/${user_email}_shared-files-with-path.csv" 2>/dev/null | wc -l)
    local active_shared=$(tail -n +2 "$active_file" 2>/dev/null | wc -l)
    
    echo -e "${GREEN}File sharing analysis complete:${NC}"
    echo "- Total shared files: $total_shared"
    echo "- Files shared with active users: $active_shared"
    echo "- Report saved to: $active_file"
}

# =====================================
# OWNERSHIP TRANSFER AND ACCOUNT MANAGEMENT FUNCTIONS
# =====================================

# Function to transfer ownership of files to gwombat
transfer_ownership_to_gwombat() {
    local user_email="$1"
    local dry_run="${2:-false}"
    
    echo -e "${GREEN}Transferring file ownership from $user_email to gwombat...${NC}"
    
    # Check if user account is suspended - temporarily unsuspend if needed
    local was_suspended=false
    local user_status=$($GAM info user "$user_email" 2>/dev/null | grep "Account Suspended:" | cut -d' ' -f3)
    
    if [[ "$user_status" == "True" ]]; then
        was_suspended=true
        if [[ "$dry_run" == "false" ]]; then
            echo "User is suspended. Temporarily unsuspending for file transfer..."
            $GAM update user "$user_email" suspended off
            sleep 5
        else
            echo -e "${CYAN}[DRY-RUN] Would temporarily unsuspend $user_email for file transfer${NC}"
        fi
    fi
    
    # Get list of files owned by user
    local temp_file="${SCRIPTPATH}/tmp/${user_email}_ownership_transfer.csv"
    if [[ "$dry_run" == "false" ]]; then
        $GAM user "$user_email" print filelist fields id,name,owners > "$temp_file"
        local file_count=$(tail -n +2 "$temp_file" | wc -l)
        echo "Found $file_count files to transfer ownership"
        
        local counter=0
        tail -n +2 "$temp_file" | while IFS=',' read -r file_id file_name owner_email; do
            ((counter++))
            show_progress $counter $file_count "Transferring file: $file_name"
            
            # Check if file is owned by external account
            if [[ "$owner_email" != *"@${DOMAIN:-yourdomain.edu}" ]]; then
                echo "  External file detected - copying instead of transferring: $file_name"
                $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} add drivefile copy "$file_id" parentname "Copied Files from External Accounts"
            else
                $GAM user "$user_email" add drivefileacl "$file_id" user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} role owner transferownership true
            fi
        done
    else
        echo -e "${CYAN}[DRY-RUN] Would transfer ownership of all files from $user_email to gwombat${NC}"
    fi
    
    # Re-suspend user if they were originally suspended
    if [[ "$was_suspended" == true ]]; then
        if [[ "$dry_run" == "false" ]]; then
            echo "Re-suspending user account..."
            $GAM update user "$user_email" suspended on
        else
            echo -e "${CYAN}[DRY-RUN] Would re-suspend $user_email${NC}"
        fi
    fi
    
    echo -e "${GREEN}Ownership transfer completed for $user_email${NC}"
}

# Function to analyze accounts with no sharing
analyze_accounts_no_sharing() {
    local scope="$1"  # "suspended" or "ou"
    
    echo -e "${GREEN}Analyzing accounts with no file sharing...${NC}"
    
    # Check when domain data was last synced
    local last_sync=$(sqlite3 local-config/account_lifecycle.db "SELECT value FROM config WHERE key='last_domain_sync';" 2>/dev/null)
    local db_user_count=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "0")
    
    local user_list=""
    local data_source=""
    
    if [[ -n "$last_sync" && "$db_user_count" -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}📊 Database contains $db_user_count accounts${NC}"
        echo -e "${CYAN}🕐 Last synced: $last_sync${NC}"
        echo ""
        echo "Data source options:"
        echo "1. Use database data (faster, may be outdated)"
        echo "2. Get fresh data from GAM (slower, current)"
        echo "3. Sync database with GAM first, then use database"
        echo ""
        read -p "Select data source (1-3): " data_source_choice
        
        case $data_source_choice in
            1)
                data_source="database"
                echo -e "${CYAN}Using database data from $last_sync${NC}"
                ;;
            2)
                data_source="gam"
                echo -e "${CYAN}Getting fresh data from GAM...${NC}"
                ;;
            3)
                echo -e "${CYAN}Syncing database with GAM first...${NC}"
                sync_domain_to_database
                data_source="database"
                echo -e "${CYAN}Using freshly synced database data${NC}"
                ;;
            *)
                echo -e "${RED}Invalid choice. Using fresh GAM data.${NC}"
                data_source="gam"
                ;;
        esac
    else
        echo -e "${YELLOW}No database data available. Getting fresh data from GAM...${NC}"
        data_source="gam"
    fi
    
    # Get user list based on chosen data source
    case $data_source in
        "database")
            case $scope in
                "suspended")
                    user_list=$(sqlite3 local-config/account_lifecycle.db "SELECT email FROM accounts WHERE current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row');" 2>/dev/null)
                    ;;
                "ou")
                    user_list=$(sqlite3 local-config/account_lifecycle.db "SELECT email FROM accounts WHERE ou_path LIKE '%Suspended%';" 2>/dev/null)
                    ;;
            esac
            ;;
        "gam")
            case $scope in
                "suspended")
                    user_list=$($GAM print users query "isSuspended=true" fields email 2>/dev/null | tail -n +2 | cut -d',' -f1)
                    ;;
                "ou")
                    user_list=$($GAM print users query "orgUnitPath='/Suspended Accounts'" fields email 2>/dev/null | tail -n +2 | cut -d',' -f1)
                    ;;
            esac
            ;;
    esac
    
    if [[ -z "$user_list" ]]; then
        echo -e "${YELLOW}No suspended accounts found with the selected data source.${NC}"
        if [[ "$data_source" == "database" ]]; then
            echo -e "${CYAN}Try running a fresh GAM sync or use option 2 for fresh data.${NC}"
        fi
        return 1
    fi
    
    local counter=0
    local total_users=$(echo "$user_list" | wc -l)
    local analysis_id=$(date +%Y%m%d_%H%M)
    
    # Create analysis session in database
    sqlite3 local-config/account_lifecycle.db "
        CREATE TABLE IF NOT EXISTS file_sharing_analysis (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            analysis_id TEXT,
            email TEXT,
            has_shared_files BOOLEAN,
            total_files INTEGER,
            storage_used TEXT,
            analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    " 2>/dev/null
    
    echo "$user_list" | while read user_email; do
        [[ -z "$user_email" ]] && continue
        
        ((counter++))
        show_progress $counter $total_users "Analyzing: $user_email"
        
        # Check if user has any shared files
        local shared_files=$($GAM user "$user_email" print filelist query "shared=true" fields id 2>/dev/null | tail -n +2 | wc -l)
        local total_files=$($GAM user "$user_email" print filelist fields id 2>/dev/null | tail -n +2 | wc -l)
        local storage_used=$($GAM info user "$user_email" 2>/dev/null | grep "Storage Used:" | cut -d' ' -f3 || echo "0")
        
        local has_sharing=0
        [[ $shared_files -gt 0 ]] && has_sharing=1
        
        # Store results in database
        sqlite3 local-config/account_lifecycle.db "
            INSERT INTO file_sharing_analysis (
                analysis_id, email, has_shared_files, total_files, storage_used
            ) VALUES (
                '$analysis_id', '$user_email', $has_sharing, $total_files, '$storage_used'
            );
        " 2>/dev/null
    done
    
    # Show summary results
    local total_analyzed=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM file_sharing_analysis WHERE analysis_id='$analysis_id';" 2>/dev/null)
    local no_sharing=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM file_sharing_analysis WHERE analysis_id='$analysis_id' AND has_shared_files=0;" 2>/dev/null)
    local with_sharing=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM file_sharing_analysis WHERE analysis_id='$analysis_id' AND has_shared_files=1;" 2>/dev/null)
    
    echo ""
    echo -e "${GREEN}Analysis complete (ID: $analysis_id):${NC}"
    echo "  📊 Total accounts analyzed: $total_analyzed"
    echo "  📁 Accounts with shared files: $with_sharing"
    echo "  🗑️  Candidates for deletion: $no_sharing"
    echo ""
    echo "View detailed results: select * from file_sharing_analysis where analysis_id='$analysis_id';"
}

# Function to perform file activity analysis
analyze_file_activity() {
    local user_email="$1"
    local days_threshold="${2:-90}"
    local csv_dir="${SCRIPTPATH}/csv-files"
    
    echo -e "${GREEN}Analyzing file activity for $user_email (threshold: $days_threshold days)...${NC}"
    
    local all_files_csv="${csv_dir}/${user_email}_files.csv"
    local recent_files_csv="${csv_dir}/${user_email}_recent_files.csv" 
    local old_files_csv="${csv_dir}/${user_email}_old_files.csv"
    
    # Get all files (excluding Google Apps formats)
    $GAM user "$user_email" print filelist query "not mimeType contains 'application/vnd.google-apps'" \
        fields size,id,name,mimeType,modifiedTime > "$all_files_csv"
    
    # Calculate threshold date
    local threshold_date=$(date -d "$days_threshold days ago" +%Y-%m-%d)
    
    # Process files and categorize by date
    echo "size,id,name,mimeType,modifiedTime" > "$recent_files_csv"
    echo "size,id,name,mimeType,modifiedTime" > "$old_files_csv"
    
    local recent_count=0
    local old_count=0
    local recent_size=0
    local old_size=0
    
    tail -n +2 "$all_files_csv" | while IFS=',' read -r size id name mimeType modifiedTime; do
        local file_date=$(echo "$modifiedTime" | cut -d'T' -f1)
        
        if [[ "$file_date" > "$threshold_date" ]]; then
            echo "$size,$id,$name,$mimeType,$modifiedTime" >> "$recent_files_csv"
            ((recent_count++))
            recent_size=$((recent_size + size))
        else
            echo "$size,$id,$name,$mimeType,$modifiedTime" >> "$old_files_csv"
            ((old_count++))
            old_size=$((old_size + size))
        fi
    done
    
    echo -e "${GREEN}File activity analysis complete:${NC}"
    echo "- Recent files (< $days_threshold days): $recent_count files ($(($recent_size / 1024 / 1024)) MB)"
    echo "- Old files (> $days_threshold days): $old_count files ($(($old_size / 1024 / 1024)) MB)"
    echo "- Reports saved to: $csv_dir/"
}

# Function to manage group memberships during suspension
manage_suspension_groups() {
    local user_email="$1"
    local operation="$2"  # "backup" or "restore"
    local groups_file="${SCRIPTPATH}/tmp/${user_email}_groups_backup.txt"
    
    case $operation in
        "backup")
            echo -e "${GREEN}Backing up group memberships for $user_email...${NC}"
            $GAM info user "$user_email" groups | grep "Member of" | cut -d' ' -f3 > "$groups_file"
            local group_count=$(cat "$groups_file" | wc -l)
            echo "Backed up $group_count group memberships"
            
            # Remove user from all groups
            cat "$groups_file" | while read group; do
                echo "  Removing from $group..."
                $GAM update group "$group" remove member "$user_email"
            done
            ;;
        "restore")
            if [[ -f "$groups_file" ]]; then
                echo -e "${GREEN}Restoring group memberships for $user_email...${NC}"
                cat "$groups_file" | while read group; do
                    echo "  Adding to $group..."
                    $GAM update group "$group" add member "$user_email"
                done
            else
                echo -e "${YELLOW}No backup file found for $user_email${NC}"
            fi
            ;;
    esac
}

# Function to fix file modification dates
restore_file_dates() {
    local user_email="$1"
    local target_date="${2:-2023-05-01}"  # Default to pre-May 2023
    
    echo -e "${GREEN}Restoring file modification dates for $user_email...${NC}"
    
    # Get files that were modified after the target date
    local files_to_fix="${SCRIPTPATH}/tmp/${user_email}_date_fix.csv"
    $GAM user "$user_email" print filelist \
        query "modifiedTime>'$target_date'" \
        fields id,name,modifiedTime > "$files_to_fix"
    
    local file_count=$(tail -n +2 "$files_to_fix" | wc -l)
    echo "Found $file_count files to fix dates"
    
    local counter=0
    tail -n +2 "$files_to_fix" | while IFS=',' read -r file_id file_name current_date; do
        ((counter++))
        show_progress $counter $file_count "Fixing date: $file_name"
        
        # Try to find appropriate date from file activity
        local activity_date=$($GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} show driveactivity "$file_id" 2>/dev/null | \
                              grep -E "time.*$(date -d "$target_date" +%Y)" | head -1 | \
                              grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "$target_date")
        
        # Update the file with the restored date
        $GAM user "$user_email" update drivefile "$file_id" modifiedtime "$activity_date"
    done
    
    echo -e "${GREEN}Date restoration completed${NC}"
}

# Function to add members to group in bulk
bulk_add_to_group() {
    local group_name="$1"
    local members_file="$2"
    
    if [[ ! -f "$members_file" ]]; then
        echo -e "${RED}Members file not found: $members_file${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Adding members from $members_file to group $group_name...${NC}"
    
    local counter=0
    local total_members=$(cat "$members_file" | wc -l)
    
    while IFS= read -r username || [[ -n "$username" ]]; do
        # Skip empty lines
        [[ -z "$username" ]] && continue
        
        ((counter++))
        show_progress $counter $total_members "Adding: $username"
        
        if $GAM update group "$group_name" add member allmail user "$username" 2>/dev/null; then
            echo "  ✓ Added $username to $group_name"
        else
            echo "  ✗ Failed to add $username to $group_name"
        fi
    done < "$members_file"
    
    echo -e "${GREEN}Bulk add operation completed${NC}"
}

# Function to remove user from all their groups
remove_user_from_all_groups() {
    local user_email="$1"
    local log_file="${SCRIPTPATH}/tmp/${user_email}_groups_removed.log"
    
    echo -e "${GREEN}Removing $user_email from all groups...${NC}"
    
    # Get list of groups user belongs to
    local groups=$($GAM print groups member "$user_email" | grep "${DOMAIN:-yourdomain.edu}" | awk '{print $1}')
    local group_count=$(echo "$groups" | wc -l)
    
    if [[ -z "$groups" ]]; then
        echo "User $user_email is not a member of any groups"
        return 0
    fi
    
    echo "Found $group_count groups for removal"
    echo "Groups to remove from: $groups"
    echo ""
    
    local counter=0
    echo "$groups" | while read group; do
        [[ -z "$group" ]] && continue
        
        ((counter++))
        show_progress $counter $group_count "Removing from: $group"
        
        echo "Removing user: $user_email from group: $group"
        if $GAM update group "$group" remove member "$user_email" 2>/dev/null; then
            echo "$user_email removed from $group at $(date)" >> "$log_file"
            echo "  ✓ Removed from $group"
        else
            echo "  ✗ Failed to remove from $group"
        fi
    done
    
    echo -e "${GREEN}User removed from all groups. Log: $log_file${NC}"
}

# Function to manage shared drives operations
shared_drive_operations() {
    local operation="$1"
    local drive_id="$2"
    local user_email="$3"
    
    case $operation in
        "remove_pending_labels")
            echo -e "${GREEN}Removing pending deletion labels from shared drive...${NC}"
            $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} print filelist query "parents in '$drive_id'" \
                fields id,name | tail -n +2 | while IFS=',' read -r file_id file_name; do
                if [[ "$file_name" == *"PENDING DELETION"* ]] || [[ "$file_name" == *"Suspended Account - Temporary Hold"* ]]; then
                    local new_name=$(echo "$file_name" | sed -E 's/ \(PENDING DELETION - CONTACT OIT\)//g' | \
                                    sed -E 's/ \(Suspended Account - Temporary Hold\)//g')
                    echo "  Cleaning: $file_name -> $new_name"
                    $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} update drivefile "$file_id" name "$new_name"
                fi
            done
            ;;
        "grant_admin_access")
            echo -e "${GREEN}Granting gamadmin access to all files in shared drive...${NC}"
            $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} print filelist query "parents in '$drive_id'" \
                fields id | tail -n +2 | while read file_id; do
                $GAM user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} add drivefileacl "$file_id" user ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}} role writer
            done
            ;;
        "create_user_drive")
            echo -e "${GREEN}Creating shared drive for user: $user_email${NC}"
            local drive_name="${user_email} - Archived Files"
            local new_drive_id=$($GAM create shareddrive "$drive_name" adminmanaged)
            echo "Created shared drive: $new_drive_id"
            
            # Grant access to gwombat
            $GAM update shareddrive "$new_drive_id" add organizer ${ADMIN_USER:-gwombat@${DOMAIN:-yourdomain.edu}}
            echo "$new_drive_id"
            ;;
    esac
}

# Function to get destination OU choice
get_destination_ou() {
    echo ""
    echo "Select destination Organizational Unit:"
    echo "1. Suspended Accounts/Suspended - Pending Deletion"
    echo "2. Suspended Accounts (general suspended)"
    echo "3. ${DOMAIN:-yourdomain.edu} (reactivate account)"
    echo ""
    while true; do
        read -p "Choose destination OU (1-3): " ou_choice
        case $ou_choice in
            1) echo "$OU_PENDING_DELETION"; break ;;
            2) echo "$OU_SUSPENDED"; break ;;
            3) echo "$OU_ACTIVE"; break ;;
            *) echo -e "${RED}Please select 1, 2, or 3.${NC}" ;;
        esac
    done
}

# Function to move user to OU
move_user_to_ou() {
    local user="$1"
    local target_ou="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would move user $user to OU: $target_ou${NC}"
        
        # Check if this is a suspension operation that would trigger group removal
        if [[ "$target_ou" == *"Suspended"* ]]; then
            echo -e "${CYAN}[DRY-RUN] Would also remove user from all groups${NC}"
        fi
        return 0
    fi
    
    echo -e "${GREEN}Moving user $user to OU: $target_ou${NC}"
    execute_command "$GAM update user \"$user\" ou \"$target_ou\"" "Move user to OU"
    
    # Automatically remove from groups when moving to any suspended OU
    if [[ "$target_ou" == *"Suspended"* ]]; then
        echo -e "${YELLOW}User is being moved to a suspended OU. Removing from all groups...${NC}"
        remove_user_from_all_groups "$user"
    fi
    
    # Offer to restore groups when moving back to active OU
    if [[ "$target_ou" == "$OU_ACTIVE" ]]; then
        echo -e "${CYAN}User is being reactivated. Checking for group backup...${NC}"
        # Look for the most recent group backup for this user
        local latest_backup=$(ls -t "${BACKUP_DIR}/${user}-groups-"*.txt 2>/dev/null | head -1)
        if [[ -n "$latest_backup" ]]; then
            echo -e "${YELLOW}Found group backup: $(basename "$latest_backup")${NC}"
            echo -e "${YELLOW}Would you like to restore the user's previous group memberships? (y/n)${NC}"
            read -p "> " restore_groups
            if [[ "$restore_groups" =~ ^[Yy] ]]; then
                restore_user_to_groups "$user" "$latest_backup"
            else
                echo -e "${CYAN}Skipped group restoration. Groups can be manually restored later.${NC}"
                log_info "User chose to skip group restoration for $user"
            fi
        else
            echo -e "${YELLOW}No group backup found for user $user${NC}"
            echo -e "${YELLOW}Groups will need to be manually restored if needed.${NC}"
            log_warning "No group backup found for reactivated user $user"
        fi
    fi
}

# Function to remove user from all groups
remove_user_from_all_groups() {
    local user="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would remove $user from all groups${NC}"
        return 0
    fi
    
    log_info "Removing user $user from all groups"
    echo -e "${CYAN}Fetching group memberships for $user...${NC}"
    
    # Get all groups the user is a member of
    local groups=$($GAM print groups member "$user" 2>/dev/null | tail -n +2 | grep ${DOMAIN:-yourdomain.edu} || true)
    
    if [[ -z "$groups" ]]; then
        echo -e "${GREEN}User $user is not a member of any groups${NC}"
        log_info "User $user has no group memberships to remove"
        return 0
    fi
    
    local group_count=$(echo "$groups" | wc -l)
    echo -e "${YELLOW}Removing user from $group_count groups...${NC}"
    
    local removed_count=0
    local failed_count=0
    
    # Create backup of group memberships
    local group_backup_file="${BACKUP_DIR}/${user}-groups-$(date +%Y%m%d_%H%M%S).txt"
    echo "$groups" > "$group_backup_file"
    log_info "Group membership backup created: $group_backup_file"
    
    while IFS= read -r group; do
        if [[ -n "$group" ]]; then
            echo -n "  Removing from $group... "
            if $GAM update group "$group" remove member "$user" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
                ((removed_count++))
                log_operation "remove_from_group" "$user" "SUCCESS" "Removed from group: $group"
                
                # Log to the same file format as the original script
                echo "$(date '+%Y-%m-%d %H:%M:%S'),$user,$group" >> "${SCRIPTPATH}/users-removed-from-groups.txt"
            else
                echo -e "${RED}✗${NC}"
                ((failed_count++))
                log_operation "remove_from_group" "$user" "ERROR" "Failed to remove from group: $group"
                log_error "Failed to remove user $user from group $group"
            fi
        fi
    done <<< "$groups"
    
    echo ""
    if [[ $removed_count -gt 0 ]]; then
        echo -e "${GREEN}Successfully removed user from $removed_count groups${NC}"
        log_info "Successfully removed user $user from $removed_count groups"
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${YELLOW}Failed to remove user from $failed_count groups${NC}"
        log_warning "Failed to remove user $user from $failed_count groups"
    fi
    
    echo -e "${CYAN}Group removal log: ${SCRIPTPATH}/users-removed-from-groups.txt${NC}"
}

# Function to restore user to groups (for reactivation)
restore_user_to_groups() {
    local user="$1"
    local backup_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${YELLOW}No group backup file found: $backup_file${NC}"
        echo -e "${YELLOW}Skipping group restoration. You may need to manually restore group memberships.${NC}"
        log_warning "No group backup found for user $user - manual group restoration may be needed"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would restore user $user to groups from backup: $backup_file${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Restoring user $user to groups from backup...${NC}"
    log_info "Restoring user $user to groups from backup: $backup_file"
    
    local restored_count=0
    local failed_count=0
    
    while IFS= read -r group; do
        if [[ -n "$group" ]]; then
            echo -n "  Adding to $group... "
            if $GAM update group "$group" add member "$user" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
                ((restored_count++))
                log_operation "add_to_group" "$user" "SUCCESS" "Restored to group: $group"
            else
                echo -e "${RED}✗${NC}"
                ((failed_count++))
                log_operation "add_to_group" "$user" "ERROR" "Failed to restore to group: $group"
                log_error "Failed to restore user $user to group $group"
            fi
        fi
    done < "$backup_file"
    
    echo ""
    if [[ $restored_count -gt 0 ]]; then
        echo -e "${GREEN}Successfully restored user to $restored_count groups${NC}"
        log_info "Successfully restored user $user to $restored_count groups"
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        echo -e "${YELLOW}Failed to restore user to $failed_count groups${NC}"
        log_warning "Failed to restore user $user to $failed_count groups"
    fi
}

# Function to get user's current OU
get_user_ou() {
    local user="$1"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo "$OU_TEMPHOLD"  # Simulate for dry-run/discovery
        return 0
    fi
    
    local ou=$($GAM info user "$user" | awk -F': ' '/Org Unit Path:/ {print $2}')
    echo "$ou"
}

# Function to query users in temporary hold OU
query_gwombat_hold_users() {
    echo -e "${CYAN}Querying users in Temporary Hold OU...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users ou \"$OU_TEMPHOLD\"${NC}"
        echo ""
        echo "Simulated results:"
        echo "user1@domain.com,John,Doe (Suspended Account - Temporary Hold)"
        echo "user2@domain.com,Jane,Smith (Suspended Account - Temporary Hold)"
        echo "user3@domain.com,Bob,Johnson"
        return 0
    fi
    
    echo "Users in $OU_TEMPHOLD:"
    $GAM print users ou "$OU_TEMPHOLD" firstname lastname
}

# Function to query users in pending deletion OU
query_pending_users() {
    echo -e "${CYAN}Querying users in Pending Deletion OU...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users ou \"$OU_PENDING_DELETION\"${NC}"
        echo ""
        echo "Simulated results:"
        echo "user4@domain.com,Alice,Brown (PENDING DELETION - CONTACT OIT)"
        echo "user5@domain.com,David,Wilson (PENDING DELETION - CONTACT OIT)"
        echo "user6@domain.com,Carol,Davis (PENDING DELETION - CONTACT OIT)"
        return 0
    fi
    
    echo "Users in $OU_PENDING_DELETION:"
    $GAM print users ou "$OU_PENDING_DELETION" firstname lastname
}

# Function to query all suspended users
query_all_suspended_users() {
    echo -e "${CYAN}Querying all users in Suspended Accounts OUs...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query all suspended OUs${NC}"
        echo ""
        echo "Simulated results:"
        echo "OU: $OU_SUSPENDED"
        echo "  user7@domain.com,Emma,Taylor"
        echo "  user8@domain.com,Frank,Moore"
        echo ""
        echo "OU: $OU_TEMPHOLD"
        echo "  user1@domain.com,John,Doe (Suspended Account - Temporary Hold)"
        echo "  user2@domain.com,Jane,Smith (Suspended Account - Temporary Hold)"
        echo ""
        echo "OU: $OU_PENDING_DELETION"
        echo "  user4@domain.com,Alice,Brown (PENDING DELETION - CONTACT OIT)"
        echo "  user5@domain.com,David,Wilson (PENDING DELETION - CONTACT OIT)"
        return 0
    fi
    
    echo "=== Users in General Suspended OU ==="
    $GAM print users ou "$OU_SUSPENDED" firstname lastname
    echo ""
    echo "=== Users in Temporary Hold OU ==="
    $GAM print users ou "$OU_TEMPHOLD" firstname lastname
    echo ""
    echo "=== Users in Pending Deletion OU ==="
    $GAM print users ou "$OU_PENDING_DELETION" firstname lastname
}

# Function to scan active accounts for orphaned pending deletion files
scan_active_accounts() {
    echo -e "${CYAN}Scanning active accounts for orphaned pending deletion files...${NC}"
    echo ""
    
    # Create scan directory
    local scan_dir="${SCRIPTPATH}/active-account-scan"
    execute_command "mkdir -p \"$scan_dir\"" "Create scan directory"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would scan all active users for pending deletion files${NC}"
        echo "Simulated scan results:"
        echo "Found 3 active users with orphaned pending deletion files:"
        echo "  active1@domain.com - 2 files with pending deletion markers"
        echo "  active2@domain.com - 1 file with pending deletion markers"  
        echo "  active3@domain.com - 5 files with pending deletion markers"
        echo ""
        echo "Results would be saved to: $scan_dir/"
        return 0
    fi
    
    echo "Retrieving list of all active (not suspended) users..."
    # Get list of active users
    local active_users=$($GAM print users query "isSuspended=False" | awk -F, 'NR>1 {print $1}')
    local total_users=$(echo "$active_users" | wc -l)
    local current=0
    local users_with_files=0
    
    echo "Scanning $total_users active users for pending deletion files..."
    echo ""
    
    # Iterate over each active user
    for user in $active_users; do
        ((current++))
        show_progress $current $total_users "Scanning $user"
        
        # Define output file for this user's scan results
        local output_file="${scan_dir}/gam_output_${user}.txt"
        
        # Scan for files with pending deletion markers
        $GAM user "$user" show filelist id name | \
        grep "(PENDING DELETION - CONTACT OIT)" > "$output_file"
        
        # If files found, count them and keep the file
        if [[ -s "$output_file" ]]; then
            local file_count=$(wc -l < "$output_file")
            ((users_with_files++))
            echo "Found $file_count pending deletion files for $user"
        else
            # Remove empty file
            rm -f "$output_file"
        fi
    done
    
    echo ""
    echo -e "${GREEN}Scan complete!${NC}"
    echo "Users scanned: $total_users"
    echo "Users with orphaned pending deletion files: $users_with_files"
    echo "Detailed results saved to: $scan_dir/"
    
    if [[ $users_with_files -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠️  Found $users_with_files active users with orphaned pending deletion files${NC}"
        echo "These files should be cleaned up as they belong to active accounts."
        echo ""
        echo "Would you like to see a summary? (y/n)"
        read -p "> " show_summary
        if [[ "$show_summary" =~ ^[Yy] ]]; then
            echo ""
            echo "=== SUMMARY OF ORPHANED FILES ==="
            for file in "$scan_dir"/gam_output_*.txt; do
                if [[ -f "$file" ]]; then
                    local username=$(basename "$file" .txt | sed 's/gam_output_//')
                    local count=$(wc -l < "$file")
                    echo "$username: $count files"
                fi
            done
            
            echo ""
            echo "Would you like to perform bulk cleanup on these orphaned files? (y/n)"
            read -p "> " perform_cleanup
            if [[ "$perform_cleanup" =~ ^[Yy] ]]; then
                bulk_cleanup_orphaned_files "$scan_dir"
            fi
        fi
    fi
}

# Function to query users by department/type filter
query_users_by_filter() {
    echo -e "${CYAN}Query users by filter...${NC}"
    echo ""
    echo "Filter options:"
    echo "1. Students (department: Student)"
    echo "2. Faculty (department: Faculty)"
    echo "3. Staff (department: Staff)"
    echo "4. Custom query"
    echo "5. Return to discovery menu"
    echo ""
    read -p "Select filter (1-5): " filter_choice
    
    case $filter_choice in
        1) query_users_by_department "Student" ;;
        2) query_users_by_department "Faculty" ;;
        3) query_users_by_department "Staff" ;;
        4) query_users_custom ;;
        5) return ;;
    esac
}

# Function to query users by department
query_users_by_department() {
    local department="$1"
    echo -e "${CYAN}Querying $department users...${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users query \"department: $department\"${NC}"
        echo ""
        echo "Simulated results for $department:"
        case $department in
            "Student")
                echo "student1@domain.com,John,Doe,Student"
                echo "student2@domain.com,Jane,Smith,Student"
                echo "student3@domain.com,Bob,Johnson,Student"
                ;;
            "Faculty")
                echo "prof1@domain.com,Dr. Alice,Brown,Faculty"
                echo "prof2@domain.com,Dr. David,Wilson,Faculty"
                ;;
            "Staff")
                echo "staff1@domain.com,Carol,Davis,Staff"
                echo "staff2@domain.com,Frank,Moore,Staff"
                ;;
        esac
        return 0
    fi
    
    echo "=== $department Users ==="
    $GAM print users query "department: $department" fields primaryemail,firstname,lastname,department,suspended
    
    # Also show suspended users in this department
    echo ""
    echo "=== Suspended $department Users ==="
    $GAM print users query "department: $department AND isSuspended=True" fields primaryemail,firstname,lastname,department,suspended
}

# Function for custom user queries
query_users_custom() {
    echo -e "${CYAN}Custom user query...${NC}"
    echo ""
    echo "Examples:"
    echo "  - isSuspended=True"
    echo "  - department: Student AND isSuspended=True"
    echo "  - orgUnitPath: '/Suspended Accounts'"
    echo "  - creationTime>2024-01-01"
    echo ""
    read -p "Enter GAM query: " custom_query
    
    if [[ -z "$custom_query" ]]; then
        echo "No query entered."
        return
    fi
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users query \"$custom_query\"${NC}"
        echo "Simulated results for custom query would be displayed here."
        return 0
    fi
    
    echo "=== Custom Query Results ==="
    echo "Query: $custom_query"
    echo ""
    $GAM print users query "$custom_query" fields primaryemail,firstname,lastname,department,suspended,orgunitpath
}

# Function to bulk cleanup orphaned pending deletion files
bulk_cleanup_orphaned_files() {
    local scan_dir="$1"
    echo -e "${CYAN}Performing bulk cleanup of orphaned pending deletion files...${NC}"
    echo ""
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would clean up orphaned files for all users in scan results${NC}"
        echo "This would remove pending deletion suffixes and labels from files belonging to active users."
        return 0
    fi
    
    local files_processed=0
    local users_processed=0
    
    # Process each user's scan results
    for scan_file in "$scan_dir"/gam_output_*.txt; do
        if [[ -f "$scan_file" ]]; then
            local username=$(basename "$scan_file" .txt | sed 's/gam_output_//')
            local file_count=$(wc -l < "$scan_file")
            
            # Sanitize username to prevent command injection
            username=$(sanitize_gam_input "$username")
            
            if [[ -z "$username" ]]; then
                echo -e "${RED}Error: Username became empty after sanitization, skipping file: $scan_file${NC}"
                continue
            fi
            
            ((users_processed++))
            echo "Processing $username ($file_count files)..."
            
            # Read each file ID and clean it up
            while IFS=, read -r owner fileid filename; do
                if [[ -n "$fileid" && "$fileid" != "id" ]]; then
                    ((files_processed++))
                    
                    # Sanitize fileid to prevent command injection
                    fileid=$(sanitize_gam_input "$fileid")
                    filename=$(sanitize_gam_input "$filename")
                    
                    if [[ -z "$fileid" ]]; then
                        echo -e "${RED}Warning: File ID became empty after sanitization, skipping${NC}"
                        continue
                    fi
                    
                    # Remove pending deletion suffix from filename
                    local new_filename=${filename//" (PENDING DELETION - CONTACT OIT)"/}
                    if [[ "$new_filename" != "$filename" ]]; then
                        execute_command "$GAM user \"$username\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Clean filename: $filename"
                    fi
                    
                    # Remove drive label
                    execute_command "$GAM user \"$username\" process filedrivelabels \"$fileid\" deletelabelfield \"$LABEL_ID\" \"$FIELD_ID\"" "Remove drive label"
                    
                    echo "Cleaned: $fileid" >> "${SCRIPTPATH}/local-config/logs/orphaned-files-cleaned.txt"
                fi
            done < "$scan_file"
        fi
    done
    
    echo ""
    echo -e "${GREEN}Bulk cleanup complete!${NC}"
    echo "Users processed: $users_processed"
    echo "Files cleaned: $files_processed"
    echo "Log saved to: ${SCRIPTPATH}/local-config/logs/orphaned-files-cleaned.txt"
}

# Function to offer bulk operations on query results
offer_bulk_operations() {
    local result_file="$1"
    local operation_context="$2"
    
    if [[ ! -f "$result_file" || ! -s "$result_file" ]]; then
        return 0
    fi
    
    local user_count=$(wc -l < "$result_file")
    echo ""
    echo "Found $user_count users. Would you like to perform bulk operations on these users? (y/n)"
    read -p "> " perform_bulk
    
    if [[ "$perform_bulk" =~ ^[Yy] ]]; then
        echo ""
        echo "Select bulk operation:"
        echo "1. Add temporary hold to all users"
        echo "2. Remove temporary hold from all users"
        echo "3. Mark all users for pending deletion"
        echo "4. Remove pending deletion from all users"
        echo "5. Diagnose all users"
        echo "6. Cancel"
        echo ""
        read -p "Select operation (1-6): " bulk_op
        
        case $bulk_op in
            1) bulk_process_users "$result_file" "add_gwombat_hold" ;;
            2) bulk_process_users "$result_file" "remove_gwombat_hold" ;;
            3) bulk_process_users "$result_file" "add_pending" ;;
            4) bulk_process_users "$result_file" "remove_pending" ;;
            5) bulk_diagnose_users "$result_file" ;;
            15) echo "Bulk operation cancelled." ;;
        esac
    fi
}

# Function to process bulk operations on users
bulk_process_users() {
    local user_file="$1"
    local operation="$2"
    local user_count=$(wc -l < "$user_file")
    
    echo ""
    echo -e "${YELLOW}⚠️  BULK OPERATION WARNING ⚠️${NC}"
    echo "You are about to perform '$operation' on $user_count users."
    echo ""
    
    if ! enhanced_confirm "bulk $operation" "$user_count" "high"; then
        echo "Bulk operation cancelled."
        return
    fi
    
    echo ""
    echo "Processing $user_count users..."
    local current=0
    
    while IFS= read -r user; do
        ((current++))
        echo -e "${YELLOW}Progress: $current/$user_count${NC}"
        
        case $operation in
            "add_gwombat_hold") process_user "$user" ;;
            "remove_gwombat_hold") remove_gwombat_hold_user "$user" ;;
            "add_pending") process_pending_user "$user" ;;
            "remove_pending") remove_pending_user "$user" ;;
        esac
        
        echo "----------------------------------------"
    done < "$user_file"
    
    echo -e "${GREEN}Bulk operation completed for $user_count users.${NC}"
}

# Function to bulk diagnose users
bulk_diagnose_users() {
    local user_file="$1"
    local user_count=$(wc -l < "$user_file")
    
    echo ""
    echo "Diagnosing $user_count users..."
    echo ""
    
    local current=0
    local consistent_users=0
    local inconsistent_users=0
    
    while IFS= read -r user; do
        ((current++))
        show_progress $current $user_count "Diagnosing users"
        
        # Quick diagnosis without full output
        diagnose_account "$user" > /tmp/diagnosis_$user.txt 2>&1
        if grep -q "✅ Account appears to be in consistent" /tmp/diagnosis_$user.txt; then
            ((consistent_users++))
        else
            ((inconsistent_users++))
            echo "$user" >> "${SCRIPTPATH}/local-config/logs/inconsistent-users.txt"
        fi
        rm -f /tmp/diagnosis_$user.txt
    done < "$user_file"
    
    echo ""
    echo -e "${GREEN}Bulk diagnosis complete!${NC}"
    echo "Users diagnosed: $user_count"
    echo "Consistent accounts: $consistent_users"
    echo "Inconsistent accounts: $inconsistent_users"
    
    if [[ $inconsistent_users -gt 0 ]]; then
        echo "Inconsistent users logged to: ${SCRIPTPATH}/local-config/logs/inconsistent-users.txt"
    fi
}

# Function to diagnose account consistency
diagnose_account() {
    local user="$1"
    echo -e "${CYAN}=== DIAGNOSING ACCOUNT: $user ===${NC}"
    echo ""
    
    # Check user's current OU
    echo -e "${YELLOW}1. Checking Organizational Unit...${NC}"
    current_ou=$(get_user_ou "$user")
    echo "Current OU: $current_ou"
    
    # Check user's last name
    echo -e "${YELLOW}2. Checking user last name...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        lastname="Sample User (Suspended Account - Temporary Hold)"
        echo -e "${CYAN}[DISCOVERY] Would query user info for: $user${NC}"
    else
        lastname=$($GAM info user "$user" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    echo "Last name: $lastname"
    
    # Check files with temporary hold suffix
    echo -e "${YELLOW}3. Checking files with temporary hold suffix...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query files for user: $user${NC}"
        echo "Simulated: Found 15 files with '(Suspended Account - Temporary Hold)' suffix"
        files_with_suffix=15
    else
        gamadmin_hold_files=$($GAM user "$user" show filelist id name | grep -c "(Suspended Account - Temporary Hold)")
        echo "Files with suffix: $gamadmin_hold_files"
        files_with_suffix=$gamadmin_hold_files
    fi
    
    # Check files without suffix (should be 0 for consistent account)
    echo -e "${YELLOW}4. Checking files without temporary hold suffix...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo "Simulated: Found 2 files without required suffix"
        files_without_suffix=2
    else
        # This would need more complex logic to count all files vs suffixed files
        echo "Manual verification recommended for file consistency"
        files_without_suffix=0
    fi
    
    # Summary
    echo ""
    echo -e "${MAGENTA}=== DIAGNOSIS SUMMARY ===${NC}"
    echo "OU Status: $([ "$current_ou" == "$OU_TEMPHOLD" ] && echo "✅ Correct" || echo "❌ Incorrect")"
    echo "Name Status: $([ "$lastname" == *"(Suspended Account - Temporary Hold)" ] && echo "✅ Correct" || echo "❌ Missing suffix")"
    echo "Files with suffix: $files_with_suffix"
    echo "Files without suffix: $files_without_suffix"
    
    if [[ "$current_ou" == "$OU_TEMPHOLD" && "$lastname" == *"(Suspended Account - Temporary Hold)" && $files_without_suffix -eq 0 ]]; then
        echo -e "${GREEN}✅ Account appears to be in consistent temporary hold state${NC}"
    else
        echo -e "${RED}❌ Account has inconsistencies that may need attention${NC}"
    fi
}

# Function to add pending deletion to user's last name
add_pending_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Adding pending deletion to last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name already has pending deletion
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        echo "No change needed for $email, already has pending deletion: '$current_lastname'"
    else
        # Add the "(PENDING DELETION - CONTACT OIT)" suffix to the current last name
        new_lastname="$current_lastname (PENDING DELETION - CONTACT OIT)"
        
        # Update the last name
        echo "Updating $email from '$current_lastname' to '$new_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$new_lastname\"" "Update user lastname"
    fi
}

# Function to add pending deletion to all files
add_pending_to_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Adding pending deletion to all files for $user_email_full${NC}"
    
    # Define files
    CSV_DIR="${SCRIPTPATH}/csv-files"
    INPUT_FILE="${CSV_DIR}/${user_email}_active-shares.csv"
    UNIQUE_FILE="${CSV_DIR}/${user_email}_unique_files.csv"
    TEMP_FILE="${CSV_DIR}/${user_email}_temp.csv"
    ALL_FILE="${CSV_DIR}/${user_email}_all_files.csv"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would run file listing and renaming for: $user_email_full${NC}"
        echo "Simulated: Found 25 files to rename with pending deletion"
        
        # Simulate file processing
        for ((counter=1; counter<=5; counter++)); do
            show_progress $counter 5 "Processing file $counter"
            filename="Sample File $counter.pdf"
            new_filename="Sample File $counter.pdf (PENDING DELETION - CONTACT OIT)"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename${NC}"
            sleep 0.1
        done
        return 0
    fi
    
    # Generate file sharing analysis using integrated functions
    analyze_user_file_sharing "$user_email_full"
    
    # Generate the master list of all files owned by this account
    $GAM user ${user_email_full} show filelist id title > "$ALL_FILE"
    cat "$INPUT_FILE" | awk -F, '{print $1","$2","$3","$4","$5","$6","$7}' | sort | uniq > "$UNIQUE_FILE"
    
    # Create temp file with updated filenames
    rm -f "$TEMP_FILE"
    touch "$TEMP_FILE"
    counter=0
    total=$(cat "$UNIQUE_FILE" | sort | uniq | wc -l)
    
    for file_id in $(cat "$UNIQUE_FILE" | sort | uniq | egrep -v mimeType | awk -F, '{print $2}'); do
        ((counter++))
        show_progress $counter $total "Collecting file info"
        grep $file_id "$ALL_FILE" >> "$TEMP_FILE"
    done
    
    echo "Total shared files: $(cat $TEMP_FILE | wc -l)"
    
    # Initialize the counter for renaming
    counter=0
    total=$(cat "$TEMP_FILE" | egrep -v "Owner,id,name" | egrep -v "PENDING DELETION" | wc -l)
    echo "$total files need pending deletion suffix"
    
    if [[ $total -eq 0 ]]; then
        echo "All files already have the pending deletion suffix."
        return
    fi
    
    # Read in the temporary file and extract the relevant information
    while IFS=, read -r fileid filename; do
        ((counter++))
        show_progress $counter $total "Adding pending deletion"
        
        if [[ $fileid != *"http"* ]]; then
            # Get the current filename directly from Google Drive
            current_filename=$($GAM user "$user_email_full" show fileinfo "$fileid" fields name | grep 'name:' | sed 's/name: //')
            
            # Only rename if the filename does not already contain "PENDING DELETION"
            if [[ $current_filename != *"PENDING DELETION - CONTACT OIT"* ]]; then
                # Construct the new filename
                new_filename="${current_filename} (PENDING DELETION - CONTACT OIT)"
                # Update the filename in Google Drive
                execute_command "$GAM user \"$user_email_full\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Rename file: $current_filename"
                echo "Renamed file: $fileid, $current_filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-pending-added.txt"
            fi
        fi
    done < <(cat "$TEMP_FILE" | egrep -v "PENDING DELETION" | egrep -v "Owner,id,name" | awk -F, '{print $2","$3}')
    
    echo "Completed adding pending deletion to files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-pending-added.txt for details"
}

# Function to add drive labels to files
add_drive_labels() {
    local user_email_full="$1"
    
    # Sanitize input to prevent command injection
    user_email_full=$(sanitize_gam_input "$user_email_full")
    
    if [[ -z "$user_email_full" ]]; then
        echo -e "${RED}Error: User email became empty after sanitization${NC}"
        return 1
    fi
    
    local user_email=$(echo "$user_email_full" | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 3: Adding drive labels to files for $user_email_full${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would add Education Plus license temporarily${NC}"
        echo -e "${CYAN}[DRY-RUN] Would add drive labels to all files${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove Education Plus license${NC}"
        return 0
    fi
    
    # Add Education Plus license temporarily for drive labels
    execute_command "$GAM user \"$user_email_full\" add license \"Google Workspace for Education Plus\"" "Add temporary license"
    echo "Waiting 30 seconds for license to take effect..."
    sleep 30
    
    CSV_DIR="${SCRIPTPATH}/csv-files"
    UNIQUE_FILE="${CSV_DIR}/${user_email}_unique_files.csv"
    LOG_FILE="${SCRIPTPATH}/local-config/logs/${user_email}_drive-labels.txt"
    
    if [[ ! -f "$UNIQUE_FILE" ]]; then
        echo "No unique files CSV found, skipping drive labels"
        return
    fi
    
    # Add labels to all files
    counter=0
    total=$(cat "$UNIQUE_FILE" | egrep -v "vnd.google-apps.folder" | egrep -v "mimeType" | wc -l)
    echo "Adding drive labels to $total files"
    
    while IFS=, read -r owner file_id filename; do
        if [[ "$file_id" != "id" && "$file_id" != *"mimeType"* ]]; then
            ((counter++))
            show_progress $counter $total "Adding drive labels"
            
            # Sanitize file_id to prevent command injection
            file_id=$(sanitize_gam_input "$file_id")
            
            if [[ -z "$file_id" ]]; then
                echo -e "${RED}Warning: File ID became empty after sanitization, skipping${NC}"
                continue
            fi
            
            execute_command "$GAM user \"$user_email_full\" process filedrivelabels \"$file_id\" addlabelfield \"$LABEL_ID\" \"$FIELD_ID\" selection \"$SELECTION_ID\"" "Add label to file"
        fi
    done < "$UNIQUE_FILE"
    
    # Remove the temporary license
    execute_command "$GAM user \"$user_email_full\" delete license \"Google Workspace for Education Plus\"" "Remove temporary license"
    
    echo "Completed adding drive labels for $user_email"
}

# Function to remove pending deletion from user's last name
remove_pending_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Removing pending deletion from last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User (PENDING DELETION - CONTACT OIT)"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name ends with "(PENDING DELETION - CONTACT OIT)"
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        # Remove the "(PENDING DELETION - CONTACT OIT)" suffix from the current last name
        original_lastname="${current_lastname% (PENDING DELETION - CONTACT OIT)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$original_lastname\"" "Update user lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to remove pending deletion from all files
remove_pending_from_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Removing pending deletion from all files for $user_email_full${NC}"
    
    # Create tmp directory if it doesn't exist
    execute_command "mkdir -p \"${SCRIPTPATH}/tmp\"" "Create tmp directory"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query files for user: $user_email_full${NC}"
        TOTAL=4  # Simulate some files for dry-run
        echo "Found $TOTAL files to process (simulated)"
        
        # Simulate file processing
        for ((counter=1; counter<=TOTAL; counter++)); do
            show_progress $counter $TOTAL "Processing file $counter"
            filename="Sample File $counter (PENDING DELETION - CONTACT OIT).pdf"
            new_filename="Sample File $counter.pdf"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename${NC}"
            echo -e "${CYAN}[DRY-RUN] Would remove drive label from file${NC}"
            sleep 0.1
        done
        return 0
    fi
    
    # Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
    $GAM user "$user_email_full" show filelist id name | grep "(PENDING DELETION - CONTACT OIT)" > "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt"
    TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt" | wc -l)
    counter=0
    
    if [[ $TOTAL -eq 0 ]]; then
        echo "No files found with '(PENDING DELETION - CONTACT OIT)' in the name."
        return
    fi
    
    echo "Found $TOTAL files to process"
    
    # Read in the temporary file and extract the relevant information, skipping the header line
    while IFS=, read -r owner fileid filename; do
        ((counter++))
        show_progress $counter $TOTAL "Processing files"
        
        # Remove the "(PENDING DELETION - CONTACT OIT)" string from filename
        new_filename=${filename//" (PENDING DELETION - CONTACT OIT)"/}
        if [[ "$new_filename" != "$filename" ]]; then
            # Rename the file
            execute_command "$GAM user \"$owner\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Rename file: $filename"
            echo "Renamed file: $fileid, $filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-pending-removed.txt"
        fi
        
        # Remove drive label from file
        if [[ -n "$fileid" ]]; then
            execute_command "$GAM user $owner process filedrivelabels $fileid deletelabelfield $LABEL_ID $FIELD_ID" "Remove drive label"
        fi
    done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt") # Skip the first line (header)
    
    echo "Completed removing pending deletion from files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-pending-removed.txt for details"
}

# Function to remove user from all groups
remove_from_groups() {
    local user="$1"
    
    # Sanitize input to prevent command injection
    user=$(sanitize_gam_input "$user")
    
    if [[ -z "$user" ]]; then
        echo -e "${RED}Error: User became empty after sanitization${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Step 4: Removing user from all groups for $user${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query user groups for: $user${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove user from all groups${NC}"
        echo "Simulated: User would be removed from 8 groups"
        return 0
    fi
    
    # Get list of groups user is a member of
    groups=$($GAM print groups member "$user" 2>/dev/null | grep ${DOMAIN:-yourdomain.edu})
    
    if [[ -z "$groups" ]]; then
        echo "User $user is not a member of any groups"
        return
    fi
    
    echo "Removing user from groups..."
    for group in $groups; do
        echo "Removing user: $user from group: $group"
        execute_command "$GAM update group \"$group\" remove member \"$user\"" "Remove from group: $group"
        echo "Removed $user from $group" >> "${SCRIPTPATH}/users-removed-from-groups.txt"
    done
    
    echo "Completed removing user from groups"
}

# Function to confirm action
confirm_action() {
    while true; do
        read -p "Do you want to proceed with these changes? (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to restore last name (from restore-lastname.sh)
restore_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Restoring last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User (PENDING DELETION - CONTACT OIT)"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name ends with "(PENDING DELETION - CONTACT OIT)"
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        # Remove the "(PENDING DELETION - CONTACT OIT)" suffix from the current last name
        original_lastname="${current_lastname% (PENDING DELETION - CONTACT OIT)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$original_lastname\"" "Update user lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to fix filenames (from gamadmin-filesfix.sh)
fix_filenames() {
    local user="$1"
    echo -e "${GREEN}Step 2: Fixing filenames for $user${NC}"
    
    # Create tmp directory if it doesn't exist
    execute_command "mkdir -p \"${SCRIPTPATH}/tmp\"" "Create tmp directory"
    
    # Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query files for user: $user${NC}"
        TOTAL=3  # Simulate some files for dry-run
        echo "Found $TOTAL files to rename (simulated)"
        
        # Simulate file processing
        for ((counter=1; counter<=TOTAL; counter++)); do
            show_progress $counter $TOTAL "Processing file $counter"
            filename="Sample File $counter (PENDING DELETION - CONTACT OIT).pdf"
            new_filename="Sample File $counter.pdf"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename (Suspended Account - Temporary Hold)${NC}"
            sleep 0.1  # Brief pause for visual effect
        done
    else
        $GAM user "$user" show filelist id name | grep "(PENDING DELETION - CONTACT OIT)" > "${SCRIPTPATH}/tmp/gam_output_$user.txt"
        TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_$user.txt" | wc -l)
        counter=0
        
        if [[ $TOTAL -eq 0 ]]; then
            echo "No files found with '(PENDING DELETION - CONTACT OIT)' in the name."
            return
        fi
        
        echo "Found $TOTAL files to rename"
        
        # Read in the temporary file and extract the relevant information, skipping the header line
        while IFS=, read -r owner fileid filename; do
            ((counter++))
            show_progress $counter $TOTAL "Processing files"
            
            # Rename the file by removing the "(PENDING DELETION - CONTACT OIT)" string
            new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            if [[ "$new_filename" != "$filename" ]]; then
                # If the filename has been changed, rename the file and print a message
                execute_command "$GAM user \"$owner\" update drivefile \"$fileid\" newfilename \"$new_filename (Suspended Account - Temporary Hold)\"" "Rename file: $filename"
                echo "Renamed file: $fileid, $filename -> $new_filename (Suspended Account - Temporary Hold)" >> "${SCRIPTPATH}/tmp/$user-fixed.txt"
            fi
        done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_$user.txt") # Skip the first line (header)
    fi
    
    echo "Completed renaming files for $user"
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "See ${SCRIPTPATH}/tmp/$user-fixed.txt for details"
    fi
}

# Function to rename all files (from gamadmin-file-rename.sh)
rename_all_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 3: Renaming all files for $user_email_full${NC}"
    
    # Define files
    CSV_DIR="${SCRIPTPATH}/csv-files"
    INPUT_FILE="${CSV_DIR}/${user_email}_active-shares.csv"
    UNIQUE_FILE="${CSV_DIR}/${user_email}_unique_files.csv"
    TEMP_FILE="${CSV_DIR}/${user_email}_temp.csv"
    
    # Generate file sharing analysis using integrated functions
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would generate shared file list for $user_email${NC}"
        # Create simulated data for dry-run
        mkdir -p "$(dirname "$INPUT_FILE")"
        echo "owner,id,filename,shared_with,permission" > "$INPUT_FILE"
        echo "$user_email,123abc,Document1.pdf,activeuser1@${DOMAIN:-yourdomain.edu},reader" >> "$INPUT_FILE"
        echo "$user_email,456def,Document2.pdf,activeuser2@${DOMAIN:-yourdomain.edu},writer" >> "$INPUT_FILE"
        echo "$user_email,789ghi,Document3.pdf,externaluser@gmail.com,reader" >> "$INPUT_FILE"
    else
        analyze_user_file_sharing "$user_email_full"
    fi
    
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo -e "${YELLOW}Warning: Shared file list not found at $INPUT_FILE${NC}"
        echo -e "${YELLOW}This may indicate that list-users-files.sh is not available or failed to run${NC}"
        echo -e "${CYAN}Skipping file renaming step. Only files already marked as pending deletion were processed.${NC}"
        log_warning "Shared file list not found for user $user_email_full - skipping bulk file renaming"
        return 0
    fi
    
    # Filter for files shared with active ${DOMAIN:-yourdomain.edu} accounts ONLY
    # Exclude external domains and already suspended accounts
    echo "Filtering for files shared with active ${DOMAIN:-yourdomain.edu} accounts..."
    
    # Generate list of files shared ONLY with active ${DOMAIN:-yourdomain.edu} accounts
    # This excludes files shared with external domains or already suspended users
    awk -F, '
    NR==1 {next}  # Skip header
    $4 ~ /@'"${DOMAIN:-your-domain.edu}"'$/ && $4 !~ /suspended|pending|temporary/ {
        print $1","$2","$3
    }' "$INPUT_FILE" | sort | uniq > "$UNIQUE_FILE"
    
    # Create final temp file with unique shared files
    rm -f "$TEMP_FILE"
    touch "$TEMP_FILE"
    cat "$UNIQUE_FILE" > "$TEMP_FILE"
    
    local shared_count=$(cat "$TEMP_FILE" | wc -l)
    local total_files=$(awk -F, 'NR>1 {print $3}' "$INPUT_FILE" | wc -l)
    local external_files=$((total_files - shared_count))
    
    echo "Analysis of $user_email file sharing:"
    echo "  Total files owned: $total_files"
    echo "  Files shared with active ${DOMAIN:-yourdomain.edu} accounts: $shared_count"
    echo "  Files shared externally or with suspended accounts: $external_files"
    echo ""
    
    if [[ $shared_count -eq 0 ]]; then
        echo -e "${GREEN}✓ No files are shared with active ${DOMAIN:-yourdomain.edu} accounts.${NC}"
        echo -e "${CYAN}This is ideal for security - no internal sharing to protect.${NC}"
        echo -e "${CYAN}Only files already marked as pending deletion were processed.${NC}"
        log_info "User $user_email_full has no files shared with active ${DOMAIN:-yourdomain.edu} accounts - optimal security state"
        return 0
    fi
    
    if [[ $external_files -gt 0 ]]; then
        echo -e "${CYAN}Note: $external_files files shared externally/with suspended accounts will NOT be renamed${NC}"
        echo -e "${CYAN}This preserves access for external collaborators and already-processed accounts${NC}"
        log_info "User $user_email_full: $external_files files preserved (external/suspended sharing)"
    fi
    
    # Initialize the counter
    total=$(cat "$TEMP_FILE" | egrep -v "(Suspended Account - Temporary Hold)" | egrep -v "owner,id,filename" | wc -l)
    echo "$total files need to be renamed"
    
    if [[ $total -eq 0 ]]; then
        echo "All files already have the required suffix."
        return
    fi
    
    # Read in the temporary file and extract the relevant information
    while IFS=, read -r owner id filename; do
        if [[ -n "$filename" && $filename != *"(Suspended Account - Temporary Hold)"* ]]; then
            new_filename="$filename (Suspended Account - Temporary Hold)"
            echo "Renaming: $filename -> $new_filename"
            $GAM user "$user_email_full" update drivefile id "$id" newfilename "$new_filename"
        fi
    done < <(awk -F, 'NR != 1 && !/owner,id,filename/' "$TEMP_FILE" | egrep -v "(Suspended Account - Temporary Hold)" | awk -F, '{print $1","$2","$3}')
    
    echo "Completed renaming all files for $user_email"
    echo "${user_email},$(date '+%Y-%m-%d %H:%M:%S')" >> "${SCRIPTPATH}/file-rename-done.txt"
}

# Function to update user last name (from gamadmin-namechange.sh)
update_user_lastname() {
    local username="$1"
    echo -e "${GREEN}Step 4: Updating last name for $username${NC}"
    
    # Get the current last name of the user using GAM
    lastname=$($GAM info user "$username" | awk -F': ' '/Last Name:/ {print $2}')
    
    # Check if the last name already ends with "(Suspended Account - Temporary Hold)"
    if [[ "$lastname" == *"(Suspended Account - Temporary Hold)" ]]; then
        echo "Last name already updated - $lastname"
    else
        # Add "(Suspended Account - Temporary Hold)" to the last name
        new_lastname="$lastname (Suspended Account - Temporary Hold)"
        
        echo "Updating $username from '$lastname' to '$new_lastname'"
        $GAM update user "$username" lastname "$new_lastname"
    fi
}

# Function to remove temporary hold from user's last name
remove_gwombat_hold_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Removing temporary hold from last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    
    # Check if the current last name ends with "(Suspended Account - Temporary Hold)"
    if [[ "$current_lastname" == *"(Suspended Account - Temporary Hold)" ]]; then
        # Remove the "(Suspended Account - Temporary Hold)" suffix from the current last name
        original_lastname="${current_lastname% (Suspended Account - Temporary Hold)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        $GAM update user "$email" lastname "$original_lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to remove temporary hold from all files
remove_gwombat_hold_from_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Removing temporary hold from all files for $user_email_full${NC}"
    
    # Create tmp directory if it doesn't exist
    mkdir -p "${SCRIPTPATH}/tmp"
    
    # Query the user's files and output only the files with (Suspended Account - Temporary Hold) in the name
    $GAM user "$user_email_full" show filelist id name | grep "(Suspended Account - Temporary Hold)" > "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt"
    TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt" | wc -l)
    counter=0
    
    if [[ $TOTAL -eq 0 ]]; then
        echo "No files found with '(Suspended Account - Temporary Hold)' in the name."
        return
    fi
    
    echo "Found $TOTAL files to rename"
    
    # Read in the temporary file and extract the relevant information, skipping the header line
    while IFS=, read -r owner fileid filename; do
        ((counter++))
        # Remove the "(Suspended Account - Temporary Hold)" string from filename
        new_filename=${filename//" (Suspended Account - Temporary Hold)"/}
        if [[ "$new_filename" != "$filename" ]]; then
            # If the filename has been changed, rename the file and print a message
            $GAM user "$owner" update drivefile "$fileid" newfilename "$new_filename"
            echo "$counter of $TOTAL - Renamed file: $filename -> $new_filename"
            echo "Renamed file: $fileid, $filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-removal.txt"
        fi
    done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt") # Skip the first line (header)
    
    echo "Completed removing temporary hold from files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-removal.txt for details"
}

# Function to remove temporary hold from a single user
remove_gwombat_hold_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Removing temporary hold from user: $user ===${NC}"
    echo ""
    
    # Step 1: Remove temporary hold from lastname
    show_progress 1 3 "Removing temporary hold from lastname"
    remove_gwombat_hold_lastname "$user"
    echo ""
    
    # Step 2: Remove temporary hold from all files
    show_progress 2 3 "Removing temporary hold from all files"
    remove_gwombat_hold_from_files "$user"
    echo ""
    
    # Step 3: Move user to appropriate OU
    show_progress 3 3 "Moving user to destination OU"
    if [[ "$DRY_RUN" != "true" ]]; then
        destination_ou=$(get_destination_ou)
        move_user_to_ou "$user" "$destination_ou"
    else
        echo -e "${CYAN}[DRY-RUN] Would prompt for destination OU selection${NC}"
    fi
    echo ""
    
    # Step 4: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/gamadmin-removed.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$user" >> "${SCRIPTPATH}/file-removal-done.txt"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user removal${NC}"
    fi
    echo -e "${GREEN}Temporary hold removed from user $user successfully.${NC}"
    echo ""
}

# Function to remove temporary hold from multiple users from file
remove_gwombat_hold_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Removing temporary hold from $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            remove_gwombat_hold_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Temporary hold removed from all users in file.${NC}"
}

# Function to process a single user for pending deletion
process_pending_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Adding pending deletion for user: $user ===${NC}"
    echo ""
    
    # Step 1: Add pending deletion to lastname
    show_progress 1 5 "Adding pending deletion to lastname"
    add_pending_lastname "$user"
    echo ""
    
    # Step 2: Add pending deletion to all files
    show_progress 2 5 "Adding pending deletion to all files"
    add_pending_to_files "$user"
    echo ""
    
    # Step 3: Add drive labels to files
    show_progress 3 5 "Adding drive labels to files"
    add_drive_labels "$user"
    echo ""
    
    # Step 4: Remove user from all groups
    show_progress 4 5 "Removing user from all groups"
    remove_from_groups "$user"
    echo ""
    
    # Step 5: Move user to Pending Deletion OU
    show_progress 5 5 "Moving to Pending Deletion OU"
    move_user_to_ou "$user" "$OU_PENDING_DELETION"
    echo ""
    
    # Step 6: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/pending-deletion-done.log"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user to pending-deletion-done.log${NC}"
    fi
    echo -e "${GREEN}User $user has been marked for pending deletion successfully.${NC}"
    echo ""
}

# Function to remove pending deletion from a single user
remove_pending_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Removing pending deletion from user: $user ===${NC}"
    echo ""
    
    # Step 1: Remove pending deletion from lastname
    show_progress 1 3 "Removing pending deletion from lastname"
    remove_pending_lastname "$user"
    echo ""
    
    # Step 2: Remove pending deletion from all files (includes label removal)
    show_progress 2 3 "Removing pending deletion from all files"
    remove_pending_from_files "$user"
    echo ""
    
    # Step 3: Move user to appropriate OU
    show_progress 3 3 "Moving user to destination OU"
    if [[ "$DRY_RUN" != "true" ]]; then
        destination_ou=$(get_destination_ou)
        move_user_to_ou "$user" "$destination_ou"
    else
        echo -e "${CYAN}[DRY-RUN] Would prompt for destination OU selection${NC}"
    fi
    echo ""
    
    # Step 4: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/pending-deletion-removed.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$user" >> "${SCRIPTPATH}/pending-removal-done.txt"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user removal${NC}"
    fi
    echo -e "${GREEN}Pending deletion removed from user $user successfully.${NC}"
    echo ""
}

# Function to process multiple users from file for pending deletion
process_pending_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Adding pending deletion for $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            process_pending_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Pending deletion added for all users in file.${NC}"
}

# Function to remove pending deletion from multiple users from file
remove_pending_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Removing pending deletion from $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            remove_pending_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Pending deletion removed from all users in file.${NC}"
}

# Function to process a single user
process_user() {
    local user="$1"
    
    log_info "Starting add_gwombat_hold operation for user: $user" "console"
    start_operation_timer
    
    echo -e "${BLUE}=== Processing user: $user ===${NC}"
    echo ""
    
    # Step 1: Restore lastname
    show_progress 1 5 "Restoring lastname"
    restore_lastname "$user"
    echo ""
    
    # Step 2: Fix filenames
    show_progress 2 5 "Fixing filenames"
    fix_filenames "$user"
    echo ""
    
    # Step 3: Rename all files
    show_progress 3 5 "Renaming all files"
    rename_all_files "$user"
    echo ""
    
    # Step 4: Update user lastname
    show_progress 4 5 "Updating user lastname"
    update_user_lastname "$user"
    echo ""
    
    # Step 5: Move user to Temporary Hold OU
    show_progress 5 5 "Moving to Temporary Hold OU"
    move_user_to_ou "$user" "$OU_TEMPHOLD"
    echo ""
    
    # Step 6: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/gwombat-done.log"
        log_operation "add_gwombat_hold" "$user" "SUCCESS" "Temporary hold added successfully"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user to gwombat-done.log${NC}"
        log_operation "add_gwombat_hold" "$user" "DRY-RUN" "Dry-run mode - no changes made"
    fi
    
    end_operation_timer "add_gwombat_hold" 1
    log_info "Completed add_gwombat_hold operation for user: $user" "console"
    echo -e "${GREEN}User $user has been processed successfully.${NC}"
    echo ""
}

# Function to process multiple users from file
process_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Processing $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            process_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}All users from file have been processed.${NC}"
}

# Lifecycle Stage Menus

# Suspended Account Lifecycle Management Menu
lifecycle_management_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Suspended Account Lifecycle Management ===${NC}"
        echo ""
        echo -e "${CYAN}Complete account management from suspension through deletion${NC}"
        echo -e "${YELLOW}Workflow: Recently Suspended → Pending Deletion → Final Decisions → Deletion${NC}"
        echo ""
        echo "1. 🔍 Scan All Suspended Accounts (Discover & Categorize)"
        echo "2. 📝 Auto-Create Stage Lists from Current Accounts"
        echo "3. 📋 Manage Recently Suspended Accounts"
        echo "4. 🔄 Process Accounts for Pending Deletion"
        echo "5. 📊 File Sharing Analysis & Reports"
        echo "6. 🎯 Final Decisions (Temporary Hold / Exit Row)"
        echo "7. 🗑️  Account Deletion Operations"
        echo "8. 🔍 Quick Account Status Checker"
        echo ""
        echo "9. Return to main menu"
        echo ""
        echo "p. Previous menu (main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-9, p, m, x): " lifecycle_choice
        echo ""
        
        case $lifecycle_choice in
            1) 
                echo -e "${CYAN}Scanning all suspended accounts...${NC}"
                scan_suspended_accounts
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${CYAN}Auto-creating stage lists...${NC}"
                auto_create_stage_lists
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3) stage1_recently_suspended_menu ;;
            4) stage2_pending_deletion_menu ;;
            5) 
                stage3_sharing_analysis_menu
                if [[ $? -eq 99 ]]; then
                    return 99  # Pass through the main menu return code
                fi
                ;;
            15) stage4_final_decisions_menu ;;
            16) stage5_deletion_operations_menu ;;
            14) 
                read -p "Enter username to check: " username
                if [[ -n "$username" ]]; then
                    diagnose_account "$username"
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9|p|P|m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-9, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to re-scan all domain accounts
rescan_all_accounts() {
    clear
    echo -e "${GREEN}=== Re-scan All Domain Accounts ===${NC}"
    echo ""
    echo -e "${CYAN}This will sync the database with current Google Workspace accounts.${NC}"
    echo -e "${YELLOW}This may take a few minutes for large domains.${NC}"
    echo ""
    
    read -p "Continue with account re-scan? (y/n): " confirm_scan
    if [[ "$confirm_scan" != "y" && "$confirm_scan" != "Y" ]]; then
        echo "Scan cancelled."
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    sync_domain_to_database
    mark_stats_dirty  # Force stats refresh
    
    echo ""
    echo -e "${GREEN}✅ Account re-scan completed!${NC}"
    
    # Show summary
    local total_accounts=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts;" 2>/dev/null || echo "0")
    local active_accounts=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage = 'active';" 2>/dev/null || echo "0")
    local suspended_accounts=$(sqlite3 local-config/account_lifecycle.db "SELECT COUNT(*) FROM accounts WHERE current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row');" 2>/dev/null || echo "0")
    
    echo ""
    echo -e "${CYAN}📊 Updated Account Summary:${NC}"
    echo "  Total accounts: $total_accounts"
    echo "  Active accounts: $active_accounts"
    echo "  Suspended accounts: $suspended_accounts"
    echo ""
    read -p "Press Enter to continue..."
}

# Function to list all accounts with filtering
list_all_accounts_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== List All Accounts ===${NC}"
        echo ""
        echo "Filter options:"
        echo "1. All accounts"
        echo "2. Active accounts only"
        echo "3. Suspended accounts only"
        echo "4. Accounts by OU (organizational unit)"
        echo "5. Search accounts by email/name"
        echo ""
        echo "6. Return to previous menu"
        echo ""
        read -p "Select filter option (1-6): " filter_choice
        echo ""
        
        case $filter_choice in
            1) list_accounts_filtered "all" ;;
            2) list_accounts_filtered "active" ;;
            3) list_accounts_filtered "suspended" ;;
            4) list_accounts_by_ou ;;
            5) search_accounts ;;
            6) return ;;
            *) 
                echo -e "${RED}Invalid option. Please select 1-6.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Function to list accounts with filters
list_accounts_filtered() {
    local filter_type="$1"
    
    echo -e "${CYAN}=== Listing $filter_type accounts ===${NC}"
    echo ""
    
    # Check if we should use database or fresh GAM data
    if choose_data_source "account listing"; then
        # Use database
        case $filter_type in
            "all")
                sqlite3 local-config/account_lifecycle.db -header "SELECT email, current_stage, ou_path, updated_at FROM accounts ORDER BY email;"
                ;;
            "active")
                sqlite3 local-config/account_lifecycle.db -header "SELECT email, current_stage, ou_path, updated_at FROM accounts WHERE current_stage = 'active' ORDER BY email;"
                ;;
            "suspended")
                sqlite3 local-config/account_lifecycle.db -header "SELECT email, current_stage, ou_path, updated_at FROM accounts WHERE current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row') ORDER BY email;"
                ;;
        esac
    else
        # Use fresh GAM data
        case $filter_type in
            "all")
                echo "Getting fresh account list from GAM..."
                $GAM print users fields primaryemail,suspended,orgunitpath
                ;;
            "active")
                echo "Getting active accounts from GAM..."
                $GAM print users query "isSuspended=false" fields primaryemail,suspended,orgunitpath
                ;;
            "suspended")
                echo "Getting suspended accounts from GAM..."
                $GAM print users query "isSuspended=true" fields primaryemail,suspended,orgunitpath
                ;;
        esac
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Function to calculate account storage sizes
calculate_account_sizes_menu() {
    clear
    echo -e "${GREEN}=== Calculate Account Storage Sizes ===${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This operation queries storage for each account and may take considerable time.${NC}"
    echo ""
    echo "Scope options:"
    echo "1. All accounts"
    echo "2. Suspended accounts only"
    echo "3. Specific account"
    echo "4. Accounts from list/CSV"
    echo ""
    read -p "Select scope (1-4): " scope_choice
    echo ""
    
    case $scope_choice in
        1) calculate_all_account_sizes ;;
        2) calculate_suspended_account_sizes ;;
        3) calculate_single_account_size ;;
        4) calculate_account_sizes_from_list ;;
        *) 
            echo -e "${RED}Invalid option.${NC}"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Function to calculate storage for all accounts
calculate_all_account_sizes() {
    echo -e "${CYAN}Calculating storage sizes for all accounts...${NC}"
    echo ""
    
    # Choose data source for account list
    if choose_data_source "storage calculation"; then
        # Use database
        local account_list=$(sqlite3 local-config/account_lifecycle.db "SELECT email FROM accounts ORDER BY email;" 2>/dev/null)
    else
        # Use fresh GAM data
        local account_list=$($GAM print users fields primaryemail 2>/dev/null | tail -n +2 | cut -d',' -f1)
    fi
    
    if [[ -z "$account_list" ]]; then
        echo -e "${RED}No accounts found.${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Create storage analysis table
    sqlite3 local-config/account_lifecycle.db "
        CREATE TABLE IF NOT EXISTS account_storage (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            storage_used_bytes INTEGER,
            storage_used_display TEXT,
            analyzed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    " 2>/dev/null
    
    local counter=0
    local total_accounts=$(echo "$account_list" | wc -l)
    
    echo "Processing $total_accounts accounts..."
    echo ""
    
    echo "$account_list" | while read email; do
        [[ -z "$email" ]] && continue
        
        ((counter++))
        show_progress $counter $total_accounts "Analyzing: $email"
        
        # Get storage info from GAM
        local storage_info=$($GAM info user "$email" 2>/dev/null | grep "Storage Used:")
        local storage_bytes="0"
        local storage_display="0 MB"
        
        if [[ -n "$storage_info" ]]; then
            storage_display=$(echo "$storage_info" | cut -d':' -f2 | xargs)
            # Try to extract bytes (this is approximate)
            if [[ "$storage_display" =~ GB ]]; then
                local gb_value=$(echo "$storage_display" | grep -o '[0-9.]*' | head -1)
                storage_bytes=$(echo "$gb_value * 1073741824" | bc 2>/dev/null || echo "0")
            elif [[ "$storage_display" =~ MB ]]; then
                local mb_value=$(echo "$storage_display" | grep -o '[0-9.]*' | head -1)
                storage_bytes=$(echo "$mb_value * 1048576" | bc 2>/dev/null || echo "0")
            fi
        fi
        
        # Store in database
        sqlite3 local-config/account_lifecycle.db "
            INSERT OR REPLACE INTO account_storage (email, storage_used_bytes, storage_used_display)
            VALUES ('$email', '$storage_bytes', '$storage_display');
        " 2>/dev/null
    done
    
    echo ""
    echo -e "${GREEN}✅ Storage analysis completed!${NC}"
    echo ""
    echo "View results:"
    echo "  sqlite3 local-config/account_lifecycle.db 'SELECT email, storage_used_display FROM account_storage ORDER BY storage_used_bytes DESC LIMIT 10;'"
    echo ""
    read -p "Press Enter to continue..."
}

# Stub functions for menu items (to be implemented)
account_search_diagnostics_menu() {
    echo -e "${YELLOW}Account Search & Diagnostics - Coming Soon${NC}"
    echo "This will include:"
    echo "• Search accounts by email, name, or OU"
    echo "• Account diagnostics and health checks" 
    echo "• Detailed account information display"
    read -p "Press Enter to continue..."
}

individual_user_management_menu() {
    echo -e "${YELLOW}Individual User Management - Coming Soon${NC}"
    echo "This will include:"
    echo "• Modify user details and settings"
    echo "• Reset passwords and 2FA"
    echo "• Change organizational units"
    read -p "Press Enter to continue..."
}

bulk_user_operations_menu() {
    echo -e "${YELLOW}Bulk User Operations - Coming Soon${NC}"
    echo "This will include:"
    echo "• Bulk user creation from CSV"
    echo "• Bulk organizational unit moves"
    echo "• Batch user setting changes"
    read -p "Press Enter to continue..."
}

account_status_operations_menu() {
    echo -e "${YELLOW}Account Status Operations - Coming Soon${NC}"
    echo "This will include:"
    echo "• Bulk suspend/restore operations"
    echo "• Account status verification"
    echo "• Suspension reason management"
    read -p "Press Enter to continue..."
}

user_statistics_menu() {
    echo -e "${YELLOW}User Statistics - Coming Soon${NC}"
    echo "This will include:"
    echo "• Account creation trends"
    echo "• Login statistics and patterns"
    echo "• Storage usage analytics"
    read -p "Press Enter to continue..."
}

account_lifecycle_reports_menu() {
    echo -e "${YELLOW}Account Lifecycle Reports - Coming Soon${NC}"
    echo "This will include:"
    echo "• Lifecycle stage distribution"
    echo "• Account age and tenure analysis"
    echo "• Suspension/deletion timeline reports"
    read -p "Press Enter to continue..."
}

export_account_data_menu() {
    echo -e "${YELLOW}Export Account Data - Coming Soon${NC}"
    echo "This will include:"
    echo "• Export accounts to CSV with filters"
    echo "• Custom field selection"
    echo "• Scheduled export capabilities"
    read -p "Press Enter to continue..."
}

# User & Group Management Menu  
user_group_management_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== User & Group Management ===${NC}"
        echo ""
        echo -e "${CYAN}Comprehensive user and group administration tools${NC}"
        echo ""
        echo -e "${BLUE}=== ACCOUNT DISCOVERY & SCANNING ===${NC}"
        echo "1. 🔄 Re-scan all domain accounts (sync database)"
        echo "2. 📊 List all accounts (with filtering options)"
        echo "3. 📏 Calculate account storage sizes"
        echo "4. 🔍 Account search and diagnostics"
        echo ""
        echo -e "${PURPLE}=== ACCOUNT MANAGEMENT ===${NC}"
        echo "5. 👤 Individual user management"
        echo "6. 📋 Bulk user operations"
        echo "7. 🔐 Account status operations (suspend/restore)"
        echo ""
        echo -e "${GREEN}=== GROUP & LICENSE MANAGEMENT ===${NC}"
        echo "8. 👥 Group operations (add/remove members, bulk operations)"
        echo "9. 📄 License management (assign/remove/audit licenses)"
        echo ""
        echo -e "${ORANGE}=== SUSPENDED ACCOUNT LIFECYCLE ===${NC}"
        echo "10. 🔍 Scan All Suspended Accounts (Discover & Categorize)"
        echo "11. 📝 Auto-Create Stage Lists from Current Accounts"
        echo "12. 📋 Manage Recently Suspended Accounts"
        echo "13. 🔄 Process Accounts for Pending Deletion"
        echo "14. 📊 File Sharing Analysis & Reports"
        echo "15. 🎯 Final Decisions (Temporary Hold / Exit Row)"
        echo "16. 🗑️  Account Deletion Operations"
        echo "17. 🔍 Quick Account Status Checker"
        echo ""
        echo -e "${CYAN}=== REPORTS & ANALYTICS ===${NC}"
        echo "18. 📈 User statistics and summaries"
        echo "19. 📋 Account lifecycle reports"
        echo "20. 💾 Export account data to CSV"
        echo ""
        echo "p. Previous menu (Main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-20, p, m, x): " user_group_choice
        echo ""
        
        case $user_group_choice in
            1) rescan_all_accounts ;;
            2) list_all_accounts_menu ;;
            3) calculate_account_sizes_menu ;;
            4) account_search_diagnostics_menu ;;
            5) individual_user_management_menu ;;
            6) bulk_user_operations_menu ;;
            7) account_status_operations_menu ;;
            8) group_operations_menu ;;
            9) license_management_menu ;;
            10) 
                echo -e "${CYAN}Scanning all suspended accounts...${NC}"
                scan_suspended_accounts
                echo ""
                read -p "Press Enter to continue..."
                ;;
            11)
                echo -e "${CYAN}Auto-creating stage lists...${NC}"
                auto_create_stage_lists
                echo ""
                read -p "Press Enter to continue..."
                ;;
            12) stage1_recently_suspended_menu ;;
            13) stage2_pending_deletion_menu ;;
            14) 
                stage3_sharing_analysis_menu
                if [[ $? -eq 99 ]]; then
                    return 99  # Pass through the main menu return code
                fi
                ;;
            15) stage4_final_decisions_menu ;;
            16) stage5_deletion_menu ;;
            17) quick_account_status_checker ;;
            18) user_statistics_menu ;;
            19) account_lifecycle_reports_menu ;;
            20) export_account_data_menu ;;
            p|P) return ;;
            m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-20, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Group Operations Menu (extracted from buried shared drive menu)
group_operations_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Group Operations ===${NC}"
        echo ""
        echo -e "${CYAN}Comprehensive group membership management${NC}"
        echo ""
        echo "1. 📤 Add members to group (bulk operations)"
        echo "2. 📥 Remove user from all groups"  
        echo "3. 💾 Backup user group memberships"
        echo "4. 🔄 Restore user group memberships"
        echo "5. 👥 View user's group memberships"
        echo "6. 📋 List all groups in domain"
        echo ""
        echo "7. Return to user & group management"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-7, m, x): " group_choice
        echo ""
        
        case $group_choice in
            1)
                read -p "Enter group name: " group_name
                read -p "Enter path to file containing member emails (one per line): " members_file
                if [[ -n "$group_name" && -n "$members_file" ]]; then
                    if [[ -f "$members_file" ]]; then
                        bulk_add_to_group "$group_name" "$members_file"
                        read -p "Press Enter to continue..."
                    else
                        echo -e "${RED}File not found: $members_file${NC}"
                        read -p "Press Enter to continue..."
                    fi
                else
                    echo -e "${RED}Group name and members file path cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    echo -e "${YELLOW}This will remove $user_email from ALL groups${NC}"
                    read -p "Are you sure? (yes/no): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        remove_user_from_all_groups "$user_email"
                    else
                        echo "Operation cancelled"
                    fi
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3|4)
                read -p "Enter user email: " user_email
                echo -e "${CYAN}Select operation:${NC}"
                echo "1. Backup and remove group memberships"
                echo "2. Restore group memberships"
                read -p "Select (1-2): " group_op
                if [[ -n "$user_email" ]]; then
                    case $group_op in
                        1) manage_suspension_groups "$user_email" "backup" ;;
                        2) manage_suspension_groups "$user_email" "restore" ;;
                        *) echo -e "${RED}Invalid option${NC}" ;;
                    esac
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    echo -e "${CYAN}Group memberships for $user_email:${NC}"
                    $GAM print groups member "$user_email" 2>/dev/null || echo "No groups found or user doesn't exist"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            15)
                echo -e "${CYAN}All groups in domain:${NC}"
                $GAM print groups 2>/dev/null | head -20
                echo ""
                echo -e "${YELLOW}(Showing first 20 groups)${NC}"
                read -p "Press Enter to continue..."
                ;;
            16) return ;;
            m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Source database functions
source "${SCRIPTPATH}/shared-utilities/database_functions.sh" 2>/dev/null || {
    echo -e "${YELLOW}Warning: Database functions not available. Some features may be limited.${NC}"
}

# List Management Menu
list_management_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Account List Management ===${NC}"
        echo ""
        echo -e "${CYAN}Track account batches through lifecycle stages with persistent state${NC}"
        echo ""
        echo "1. 📋 View all account lists"
        echo "2. ➕ Create new account list"
        echo "3. 📥 Import accounts from file to list"
        echo "4. 👥 View accounts in specific list"
        echo "5. ✅ Verify list progress (check account states)"
        echo "6. 🔄 Bulk verify all accounts in list"
        echo "7. 📊 List progress summary"
        echo "8. 🔍 Scan all suspended accounts (discover current stages)"
        echo "9. 🤖 Auto-create lists from account scan"
        echo "10. 🗃️  Database maintenance"
        echo ""
        echo "11. Return to main menu"
        echo ""
        echo "p. Previous menu (main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-11, p, m, x): " list_choice
        echo ""
        
        case $list_choice in
            1)
                echo -e "${CYAN}Current Account Lists:${NC}"
                echo ""
                if db_list_account_lists; then
                    echo ""
                else
                    echo -e "${YELLOW}No lists found or database not initialized${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                read -p "Enter list name: " list_name
                read -p "Enter description (optional): " list_desc
                echo ""
                echo "Select target stage for this list:"
                echo "1. recently_suspended"
                echo "2. pending_deletion"
                echo "3. temporary_hold"
                echo "4. exit_row"
                echo "5. deleted"
                read -p "Select stage (1-5): " stage_choice
                
                case $stage_choice in
                    1) target_stage="recently_suspended" ;;
                    2) target_stage="pending_deletion" ;;
                    3) target_stage="temporary_hold" ;;
                    4) target_stage="exit_row" ;;
                    5) target_stage="deleted" ;;
                    *) 
                        echo -e "${RED}Invalid stage selection${NC}"
                        read -p "Press Enter to continue..."
                        continue
                        ;;
                esac
                
                if [[ -n "$list_name" ]]; then
                    db_create_list "$list_name" "$list_desc" "$target_stage"
                else
                    echo -e "${RED}List name cannot be empty${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                read -p "Enter path to file containing account emails: " file_path
                read -p "Enter list name (will create if doesn't exist): " list_name
                echo ""
                echo "Select initial stage for imported accounts:"
                echo "1. recently_suspended"
                echo "2. pending_deletion" 
                echo "3. temporary_hold"
                echo "4. exit_row"
                read -p "Select stage (1-4): " stage_choice
                
                case $stage_choice in
                    1) initial_stage="recently_suspended" ;;
                    2) initial_stage="pending_deletion" ;;
                    3) initial_stage="temporary_hold" ;;
                    4) initial_stage="exit_row" ;;
                    *) 
                        echo -e "${RED}Invalid stage selection${NC}"
                        read -p "Press Enter to continue..."
                        continue
                        ;;
                esac
                
                if [[ -n "$file_path" && -n "$list_name" ]]; then
                    import_accounts_to_list "$file_path" "$list_name" "$initial_stage"
                else
                    echo -e "${RED}File path and list name are required${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                read -p "Enter list name: " list_name
                if [[ -n "$list_name" ]]; then
                    echo -e "${CYAN}Accounts in list '$list_name':${NC}"
                    echo ""
                    db_get_list_accounts "$list_name"
                else
                    echo -e "${RED}List name cannot be empty${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            5)
                read -p "Enter account email: " email
                read -p "Enter expected stage (optional): " stage
                if [[ -n "$email" ]]; then
                    if [[ -n "$stage" ]]; then
                        verify_account_state "$email" "$stage"
                    else
                        # Get current stage from database
                        current_stage=$(sqlite3 "$DB_FILE" "SELECT current_stage FROM accounts WHERE email = '$email';" 2>/dev/null)
                        if [[ -n "$current_stage" ]]; then
                            verify_account_state "$email" "$current_stage"
                        else
                            echo -e "${RED}Account not found in database or no stage specified${NC}"
                        fi
                    fi
                else
                    echo -e "${RED}Email cannot be empty${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            15)
                read -p "Enter list name: " list_name
                if [[ -n "$list_name" ]]; then
                    bulk_verify_list "$list_name"
                else
                    echo -e "${RED}List name cannot be empty${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${CYAN}Account List Progress Summary:${NC}"
                echo ""
                if db_list_account_lists; then
                    echo ""
                    echo -e "${YELLOW}Progress shows: accounts_at_target / total_accounts (completion%)${NC}"
                    echo -e "${YELLOW}Verified shows accounts that passed all verification checks${NC}"
                else
                    echo -e "${YELLOW}No lists found or database not initialized${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            14)
                echo -e "${CYAN}Scanning all suspended accounts for current stage discovery...${NC}"
                echo ""
                read -p "Update database with discovered accounts? (yes/no): " update_choice
                if [[ "$update_choice" == "yes" ]]; then
                    scan_suspended_accounts true
                else
                    scan_suspended_accounts false
                fi
                read -p "Press Enter to continue..."
                ;;
            15)
                echo -e "${CYAN}Auto-creating lists from current account scan...${NC}"
                echo ""
                read -p "Enter list prefix (default: scan_$(date +%Y%m%d_%H%M)): " list_prefix
                if [[ -z "$list_prefix" ]]; then
                    auto_create_stage_lists
                else
                    auto_create_stage_lists "$list_prefix"
                fi
                read -p "Press Enter to continue..."
                ;;
            16)
                echo -e "${CYAN}Database Maintenance${NC}"
                echo ""
                echo "1. Initialize/recreate database"
                echo "2. Check database status"
                echo "3. Export database backup"
                echo "4. View database statistics"
                read -p "Select maintenance option (1-4): " maint_choice
                
                case $maint_choice in
                    1)
                        echo -e "${YELLOW}This will recreate the database. Continue? (yes/no)${NC}"
                        read -p "> " confirm
                        if [[ "$confirm" == "yes" ]]; then
                            rm -f "$DB_FILE"
                            init_database && echo -e "${GREEN}Database recreated${NC}"
                        fi
                        ;;
                    2)
                        if check_database; then
                            echo -e "${GREEN}Database is accessible${NC}"
                            echo "Location: $DB_FILE"
                            echo "Size: $(du -h "$DB_FILE" 2>/dev/null | cut -f1 || echo 'unknown')"
                            echo "Tables: $(sqlite3 "$DB_FILE" ".tables" 2>/dev/null | wc -w || echo 'unknown')"
                        else
                            echo -e "${RED}Database is not accessible${NC}"
                        fi
                        ;;
                    3)
                        backup_file="${DB_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
                        cp "$DB_FILE" "$backup_file" 2>/dev/null && \
                            echo -e "${GREEN}Database backed up to: $backup_file${NC}" || \
                            echo -e "${RED}Backup failed${NC}"
                        ;;
                    4)
                        if check_database; then
                            echo -e "${CYAN}Database Statistics:${NC}"
                            sqlite3 "$DB_FILE" "
                                SELECT 'Total Accounts: ' || COUNT(*) FROM accounts;
                                SELECT 'Active Lists: ' || COUNT(*) FROM account_lists WHERE is_active = 1;
                                SELECT 'Total Verifications: ' || COUNT(*) FROM verification_status;
                                SELECT 'Total Operations: ' || COUNT(*) FROM operation_log;
                            "
                        else
                            echo -e "${RED}Database not accessible${NC}"
                        fi
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            11|p|P|m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-11, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Menu functions for consolidated operations

file_drive_operations_menu() {
    shared_drive_cleanup_menu
}

analysis_discovery_menu() {
    discovery_mode
}

system_administration_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== System Administration ===${NC}"
        echo ""
        echo -e "${CYAN}System configuration and maintenance${NC}"
        echo ""
        echo "1. ⚙️  Configuration Management"
        echo "2. 🔍 Dry-run & Preview Modes"
        echo "3. 🛠️  System Health & Maintenance"
        echo "4. 💾 Backup Management"
        echo "5. 📋 File Ownership Audit"
        echo "6. 🔧 Check System Dependencies"
        echo ""
        echo "7. Return to main menu"
        echo ""
        echo "p. Previous menu (main menu)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-7, p, m, x): " admin_choice
        echo ""
        
        case $admin_choice in
            1) configuration_menu ;;
            2) dry_run_mode ;;
            3) check_incomplete_operations ;;
            4) 
                echo -e "${CYAN}Backup files location: $BACKUP_DIR${NC}"
                if [[ -d "$BACKUP_DIR" ]]; then
                    ls -la "$BACKUP_DIR" | head -20
                    echo ""
                    echo -e "${YELLOW}(Showing recent backup files)${NC}"
                else
                    echo "No backup directory found"
                fi
                read -p "Press Enter to continue..."
                ;;
            5) audit_file_ownership_menu ;;
            6) 
                check_dependencies
                read -p "Press Enter to continue..."
                ;;
            7|p|P|m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Stage 1: Recently Suspended Accounts
stage1_recently_suspended_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Stage 1: Recently Suspended Accounts ===${NC}"
        echo ""
        echo -e "${CYAN}These accounts have been suspended but no further processing has occurred.${NC}"
        echo -e "${CYAN}Use this stage to review and query recently suspended accounts.${NC}"
        echo ""
        echo "1. Query all suspended accounts (all OUs)"
        echo "2. Query suspended accounts by department/type"
        echo "3. Check account status and details"
        echo "4. View suspended account statistics"
        echo "5. Export suspended account list"
        echo ""
        echo "6. Return to lifecycle management menu"
        echo ""
        echo "p. Previous menu (lifecycle management)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-6, p, m, x): " stage1_choice
        echo ""
        
        case $stage1_choice in
            1) query_all_suspended_users ;;
            2) query_users_by_filter ;;
            3) 
                read -p "Enter username to check: " username
                if [[ -n "$username" ]]; then
                    diagnose_account "$username"
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${CYAN}Suspended Account Statistics:${NC}"
                query_all_suspended_users | tail -n +2 | wc -l | xargs echo "Total suspended accounts:"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Exporting suspended account list...${NC}"
                local export_file="local-config/reports/suspended_accounts_$(date +%Y%m%d_%H%M%S).csv"
                mkdir -p reports
                query_all_suspended_users > "$export_file"
                echo -e "${GREEN}Exported to: $export_file${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6|p|P|m|M) return ;;
            x|X) exit 0 ;;
            *) 
                echo -e "${RED}Invalid option. Please select 1-6, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Stage 2: Process Pending Deletion
stage2_pending_deletion_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Stage 2: Process Pending Deletion (Rename & Label) ===${NC}"
        echo ""
        echo -e "${CYAN}Move accounts to 'Pending Deletion' OU and process their files:${NC}"
        echo -e "${CYAN}• Rename user's last name with '(PENDING DELETION - CONTACT OIT)'${NC}"
        echo -e "${CYAN}• Rename and label all their files${NC}"
        echo -e "${CYAN}• Remove from all groups${NC}"
        echo ""
        echo "1. Process single user for pending deletion"
        echo "2. Process multiple users from file"
        echo "3. Process multiple users (manual entry)"
        echo "4. Remove pending deletion (reverse operation)"
        echo "5. Query users in Pending Deletion OU"
        echo "6. Dry-run mode (preview changes)"
        echo ""
        echo "7. Return to lifecycle management menu"
        echo ""
        echo "p. Previous menu (lifecycle management)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-7, p, m, x): " stage2_choice
        echo ""
        
        case $stage2_choice in
            1)
                user=$(get_user_input)
                show_pending_summary "$user"
                if enhanced_confirm "mark for pending deletion" 1 "high"; then
                    create_backup "$user" "add_pending"
                    process_pending_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                file_path=$(load_users_from_file)
                user_count=$(wc -l < "$file_path")
                echo ""
                echo -e "${YELLOW}Found $user_count users in file.${NC}"
                echo "Each user will be marked for pending deletion."
                if enhanced_confirm "batch mark for pending deletion" "$user_count" "high"; then
                    process_pending_users_from_file "$file_path"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                users_array=($(get_multiple_user_input))
                if [[ ${#users_array[@]} -gt 0 ]]; then
                    echo ""
                    echo "Processing ${#users_array[@]} users for pending deletion"
                    if enhanced_confirm "process ${#users_array[@]} manually entered users" "${#users_array[@]}" "high"; then
                        for user in "${users_array[@]}"; do
                            echo ""
                            echo -e "${CYAN}Processing: $user${NC}"
                            create_backup "$user" "add_pending"
                            process_pending_user "$user"
                            echo "----------------------------------------"
                        done
                        echo -e "${GREEN}Manual processing completed for ${#users_array[@]} users.${NC}"
                    else
                        echo -e "${YELLOW}Operation cancelled.${NC}"
                    fi
                else
                    echo -e "${YELLOW}No users entered. Returning to menu.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                user=$(get_user_input)
                show_pending_removal_summary "$user"
                if enhanced_confirm "remove pending deletion" 1 "normal"; then
                    create_backup "$user" "remove_pending"
                    remove_pending_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5) 
                query_pending_users
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15) 
                DRY_RUN=true
                echo -e "${YELLOW}Dry-run mode enabled. No actual changes will be made.${NC}"
                echo ""
                user=$(get_user_input)
                show_pending_summary "$user"
                process_pending_user "$user"
                DRY_RUN=false
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7|p|P|m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Stage 3: File Sharing Analysis & Reports  
stage3_sharing_analysis_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Stage 3: File Sharing Analysis & Reports ===${NC}"
        echo ""
        echo -e "${CYAN}Analyze files shared by pending deletion accounts with active ${DOMAIN:-yourdomain.edu} users.${NC}"
        echo -e "${CYAN}Generate reports for active users about files they're receiving from suspended accounts.${NC}"
        echo ""
        echo "1. Analyze single user's file sharing"
        echo "2. Analyze multiple users (batch processing)"
        echo "3. Generate report for active user (what they're receiving)"
        echo "4. Update shared filenames with pending deletion labels"
        echo "5. Bulk analysis of all pending deletion users"
        echo "6. View analysis statistics"
        echo "7. Clean up analysis files"
        echo ""
        echo "p. Previous menu (Lifecycle Management)"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-7, p, m, x): " stage3_choice
        echo ""
        
        case $stage3_choice in
            1)
                read -p "Enter username (email): " username
                if [[ -n "$username" ]]; then
                    echo ""
                    echo "Analysis options:"
                    echo "1. Standard analysis"
                    echo "2. Analysis with pending deletion filename updates"
                    echo "3. Analysis without report generation"
                    read -p "Select analysis type (1-3): " analysis_type
                    
                    case $analysis_type in
                        1) analyze_user_file_sharing "$username" false false true ;;
                        2) analyze_user_file_sharing "$username" false true true ;;
                        3) analyze_user_file_sharing "$username" false false false ;;
                        *) analyze_user_file_sharing "$username" false false true ;;
                    esac
                    
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                echo -e "${CYAN}Batch File Sharing Analysis${NC}"
                echo ""
                read -p "Enter path to file containing usernames (one per line): " user_file
                if [[ -f "$user_file" ]]; then
                    echo "Analysis options:"
                    echo "1. Standard analysis for all users"
                    echo "2. Analysis with pending deletion updates"
                    read -p "Select analysis type (1-2): " batch_type
                    
                    local pending_mode=false
                    [[ "$batch_type" == "2" ]] && pending_mode=true
                    
                    echo -e "${CYAN}Processing users from file...${NC}"
                    local total_users=$(wc -l < "$user_file")
                    local current_user=0
                    local success_count=0
                    local error_count=0
                    
                    while read -r username; do
                        [[ -z "$username" ]] && continue
                        ((current_user++))
                        echo ""
                        echo -e "${BLUE}=== Processing user $current_user of $total_users: $username ===${NC}"
                        
                        if analyze_user_file_sharing "$username" false "$pending_mode" true; then
                            ((success_count++))
                        else
                            ((error_count++))
                        fi
                    done < "$user_file"
                    
                    echo ""
                    echo -e "${GREEN}Batch analysis completed${NC}"
                    echo -e "${CYAN}Total users processed: $current_user${NC}"
                    echo -e "${GREEN}Successful analyses: $success_count${NC}"
                    echo -e "${RED}Failed analyses: $error_count${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}File not found: $user_file${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                read -p "Enter active user email to generate report for: " recipient_email
                if [[ -n "$recipient_email" ]]; then
                    generate_recipient_report "$recipient_email"
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            4)
                read -p "Enter username to update filenames for: " username
                if [[ -n "$username" ]]; then
                    local active_shares_csv="listshared/${username}_active-shares.csv"
                    if [[ -f "$active_shares_csv" ]]; then
                        update_pending_deletion_filenames "$username" "$active_shares_csv"
                    else
                        echo -e "${RED}No active shares analysis found for $username${NC}"
                        echo -e "${CYAN}Please run file sharing analysis first${NC}"
                    fi
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            5)
                echo -e "${CYAN}Bulk Analysis of All Pending Deletion Users${NC}"
                echo ""
                echo "This will analyze all users in pending deletion OU."
                read -p "Continue? (y/n): " confirm_bulk
                
                if [[ "$confirm_bulk" == "y" || "$confirm_bulk" == "Y" ]]; then
                    local pending_users=$(mktemp)
                    $GAM print users query "orgUnitPath:'/Suspended Accounts/Suspended - Pending Deletion'" fields primaryemail > "$pending_users" 2>/dev/null
                    
                    local total=$(tail -n +2 "$pending_users" | wc -l)
                    echo -e "${CYAN}Found $total pending deletion users to analyze${NC}"
                    
                    local processed=0
                    local success=0
                    
                    tail -n +2 "$pending_users" | while read -r email rest; do
                        ((processed++))
                        echo ""
                        echo -e "${BLUE}=== Processing $processed/$total: $email ===${NC}"
                        
                        if analyze_user_file_sharing "$email" false false true; then
                            ((success++))
                        fi
                    done
                    
                    rm -f "$pending_users"
                    echo -e "${GREEN}Bulk analysis completed${NC}"
                    read -p "Press Enter to continue..."
                else
                    echo -e "${YELLOW}Bulk analysis cancelled${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            6)
                echo -e "${CYAN}File Sharing Analysis Statistics${NC}"
                echo ""
                
                local user_analyses=$(ls listshared/*_all_files.csv 2>/dev/null | wc -l)
                local sharing_analyses=$(ls listshared/*_shared_files.csv 2>/dev/null | wc -l)
                local active_analyses=$(ls listshared/*_active-shares.csv 2>/dev/null | wc -l)
                local recipient_reports=$(ls local-config/reports/*_files_from_*.csv 2>/dev/null | wc -l)
                
                echo "Analysis Files:"
                echo "- User file analyses: $user_analyses"
                echo "- Sharing analyses: $sharing_analyses"  
                echo "- Active share analyses: $active_analyses"
                echo "- Recipient reports: $recipient_reports"
                
                if [[ $active_analyses -gt 0 ]]; then
                    echo ""
                    echo "Active Sharing Summary:"
                    local total_active_files=0
                    for file in listshared/*_active-shares.csv; do
                        if [[ -f "$file" ]]; then
                            local count=$(tail -n +2 "$file" | wc -l 2>/dev/null || echo "0")
                            total_active_files=$((total_active_files + count))
                        fi
                    done
                    echo "- Total files shared with active users: $total_active_files"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "${CYAN}Clean Up Analysis Files${NC}"
                echo ""
                echo "This will clean up temporary and cache files from analysis."
                echo "Analysis results and reports will be preserved."
                echo ""
                read -p "Continue? (y/n): " confirm_cleanup
                
                if [[ "$confirm_cleanup" == "y" || "$confirm_cleanup" == "Y" ]]; then
                    rm -rf listshared/temp/* listshared/cache/*
                    find listshared/ -name "*.tmp" -delete 2>/dev/null
                    find listshared/ -name "temp-*" -delete 2>/dev/null
                    echo -e "${GREEN}Cleanup completed${NC}"
                else
                    echo -e "${YELLOW}Cleanup cancelled${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            p|P) return ;;
            m|M) return 99 ;;  # Special code to return to main menu
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7, p, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Stage 4: Final Decisions (Exit Row / Temporary Hold)
stage4_final_decisions_menu() {
    while true; do
        clear
        echo -e "${GREEN}=== Stage 4: Final Decisions (Exit Row / Temporary Hold) ===${NC}"
        echo ""
        echo -e "${CYAN}Make final decisions about pending deletion accounts:${NC}"
        echo -e "${YELLOW}• Move to 'Exit Row' → Account will be deleted soon${NC}"
        echo -e "${YELLOW}• Move to 'Temporary Hold' → Account gets more time${NC}"
        echo ""
        echo "1. Move user to Temporary Hold"
        echo "2. Move users from file to Temporary Hold"
        echo "3. Remove user from Temporary Hold (reactivate or continue deletion)"
        echo "4. Query users in Temporary Hold OU"
        echo "5. Query users in Exit Row OU"
        echo "6. Move user to Exit Row (prepare for deletion)"
        echo ""
        echo "7. Return to main menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-7, m, x): " stage4_choice
        echo ""
        
        case $stage4_choice in
            1)
                user=$(get_user_input)
                show_summary "$user"
                if enhanced_confirm "move to temporary hold" 1 "normal"; then
                    create_backup "$user" "add_gwombat_hold"
                    process_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                file_path=$(load_users_from_file)
                user_count=$(wc -l < "$file_path")
                echo ""
                echo -e "${YELLOW}Found $user_count users in file.${NC}"
                echo "Each user will be moved to temporary hold."
                if enhanced_confirm "batch move to temporary hold" "$user_count" "batch"; then
                    process_users_from_file "$file_path"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                user=$(get_user_input)
                show_removal_summary "$user"
                if enhanced_confirm "remove from temporary hold" 1 "normal"; then
                    create_backup "$user" "remove_gwombat_hold"
                    remove_gwombat_hold_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4) 
                query_gwombat_hold_users
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Querying users in Exit Row OU...${NC}"
                $GAM print users query "orgUnitPath:'/Suspended Accounts/Suspended - Exit Row'" fields primaryemail,givenname,familyname,suspended,lastlogintime
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                read -p "Enter username to move to Exit Row: " username
                if [[ -n "$username" ]]; then
                    echo -e "${RED}WARNING: Moving to Exit Row means this account will be deleted soon!${NC}"
                    if enhanced_confirm "move $username to Exit Row" 1 "high"; then
                        move_user_to_ou "$username" "/Suspended Accounts/Suspended - Exit Row"
                        echo -e "${GREEN}$username moved to Exit Row${NC}"
                        log_info "Moved $username to Exit Row OU"
                    else
                        echo -e "${YELLOW}Operation cancelled.${NC}"
                    fi
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            16) return ;;
            m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Stage 5: Account Deletion Operations
stage5_deletion_operations_menu() {
    while true; do
        clear
        echo -e "${RED}=== Stage 5: Account Deletion Operations ===${NC}"
        echo ""
        echo -e "${YELLOW}⚠️  DANGER ZONE: These operations are irreversible!${NC}"
        echo -e "${CYAN}Manage accounts that are ready for final deletion.${NC}"
        echo ""
        echo "1. List accounts ready for deletion (Exit Row)"
        echo "2. Collect orphaned files before deletion"
        echo "3. License management for deletion candidates"
        echo "4. Generate pre-deletion audit report"
        echo "5. View deletion-related statistics"
        echo ""
        echo "6. Return to main menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-6, m, x): " stage5_choice
        echo ""
        
        case $stage5_choice in
            1)
                echo -e "${CYAN}Accounts in Exit Row (ready for deletion):${NC}"
                $GAM print users query "orgUnitPath:'/Suspended Accounts/Suspended - Exit Row'" fields primaryemail,givenname,familyname,suspended,lastlogintime,creationtime
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                orphaned_file_collection_menu
                ;;
            3)
                license_management_menu
                ;;
            4)
                read -p "Enter username for pre-deletion audit: " username
                if [[ -n "$username" ]]; then
                    echo -e "${CYAN}Generating pre-deletion audit for $username...${NC}"
                    
                    local audit_file="local-config/reports/${username}_pre_deletion_audit_$(date +%Y%m%d_%H%M%S).txt"
                    mkdir -p reports
                    
                    {
                        echo "=== PRE-DELETION AUDIT REPORT ==="
                        echo "User: $username"
                        echo "Generated: $(date)"
                        echo ""
                        
                        echo "=== USER INFORMATION ==="
                        $GAM info user "$username" 2>/dev/null || echo "User not found"
                        echo ""
                        
                        echo "=== FILE SHARING STATUS ==="
                        if [[ -f "listshared/${username}_active-shares.csv" ]]; then
                            local shared_files=$(tail -n +2 "listshared/${username}_active-shares.csv" | wc -l)
                            echo "Files still shared with active users: $shared_files"
                            
                            if [[ $shared_files -gt 0 ]]; then
                                echo ""
                                echo "WARNING: User still has files shared with active users!"
                                echo "Recipients:"
                                tail -n +2 "listshared/${username}_active-shares.csv" | cut -d, -f8 | sort -u
                            fi
                        else
                            echo "No file sharing analysis found - run Stage 3 analysis first"
                        fi
                        
                        echo ""
                        echo "=== GROUP MEMBERSHIPS ==="
                        $GAM info user "$username" | grep -A 10 "Groups:" 2>/dev/null || echo "No group information available"
                        
                    } > "$audit_file"
                    
                    echo -e "${GREEN}Pre-deletion audit saved to: $audit_file${NC}"
                    
                    # Show summary
                    echo ""
                    echo -e "${CYAN}Audit Summary:${NC}"
                    grep -E "Files still shared|WARNING|User not found" "$audit_file" || echo "No warnings found"
                else
                    echo -e "${RED}Username cannot be empty${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Deletion-Related Statistics:${NC}"
                echo ""
                
                local exit_row_count=$($GAM print users query "orgUnitPath:'/Suspended Accounts/Suspended - Exit Row'" fields primaryemail 2>/dev/null | tail -n +2 | wc -l)
                local temphold_count=$(query_gwombat_hold_users | tail -n +2 | wc -l)
                local pending_count=$(query_pending_users | tail -n +2 | wc -l)
                
                echo "Accounts by stage:"
                echo "- Exit Row (ready for deletion): $exit_row_count"
                echo "- Temporary Hold: $temphold_count"
                echo "- Pending Deletion: $pending_count"
                echo ""
                
                # Check for potential issues
                local shared_files_count=0
                for file in listshared/*_active-shares.csv; do
                    if [[ -f "$file" ]]; then
                        local count=$(tail -n +2 "$file" | wc -l 2>/dev/null || echo "0")
                        shared_files_count=$((shared_files_count + count))
                    fi
                done
                
                echo "Potential issues:"
                echo "- Files still shared with active users: $shared_files_count"
                
                if [[ $shared_files_count -gt 0 ]]; then
                    echo -e "${YELLOW}⚠️  Warning: Some accounts still have active file shares!${NC}"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15) return ;;
            m|M) return ;;
            x|X) exit 0 ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-6, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# SCuBA Compliance Management Menu
scuba_compliance_menu() {
    if [[ -x "$SHARED_UTILITIES_PATH/scuba_compliance_bridge.sh" ]]; then
        "$SHARED_UTILITIES_PATH/scuba_compliance_bridge.sh" menu
    else
        echo -e "${YELLOW}=== SCuBA Compliance Setup Required ===${NC}"
        echo ""
        echo "SCuBA (Secure Cloud Business Applications) compliance provides automated"
        echo "security baseline checking based on CISA guidelines for Google Workspace."
        echo ""
        echo -e "${CYAN}Features include:${NC}"
        echo "• Automated compliance checking for 9 Google Workspace services"
        echo "• Gap analysis and remediation tracking"
        echo "• Executive reporting and compliance dashboards"
        echo "• Integration with GWOMBAT's scheduling system"
        echo ""
        echo -e "${CYAN}Services covered:${NC}"
        echo "• Gmail - Email security settings and policies"
        echo "• Calendar - Calendar sharing and access controls"
        echo "• Drive & Docs - File sharing and collaboration settings"
        echo "• Google Meet - Meeting security and recording controls"
        echo "• Google Chat - Chat and messaging security"
        echo "• Groups for Business - Group membership and access"
        echo "• Google Classroom - Educational environment security"
        echo "• Google Sites - Website publishing controls"
        echo "• Common Controls - Cross-service security settings"
        echo ""
        echo -e "${GREEN}Setup Instructions:${NC}"
        echo "1. Install Python 3 and required dependencies:"
        echo "   pip3 install -r python-modules/requirements.txt"
        echo ""
        echo "2. Configure Google Workspace API credentials (optional but recommended):"
        echo "   - Download OAuth2 credentials from Google Cloud Console"
        echo "   - Save as ./config/gws_credentials.json"
        echo ""
        echo "3. Enable SCuBA compliance in Configuration Management"
        echo ""
        echo -e "${YELLOW}Note: SCuBA compliance can work with GAM-only mode but enhanced${NC}"
        echo -e "${YELLOW}features require Google Workspace API access.${NC}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Check if first time setup is needed
check_first_time_setup() {
    # Check if .env file exists
    if [[ ! -f "./.env" ]]; then
        return 0  # First time setup needed
    fi
    
    # Check if setup was completed
    if [[ -f "./.env" ]] && grep -q "SETUP_COMPLETED=.*true" "./.env"; then
        return 1  # Setup already completed
    fi
    
    return 0  # Setup needed
}

# Menu navigation functions
show_menu_index() {
    clear
    # Use database-driven index
    show_menu_database_index
    
    echo ""
    read -p "Press Enter to return to main menu..."
}
search_menu_options() {
    while true; do
        clear
        echo -e "${BLUE}=== GWOMBAT Menu Search ===${NC}"
        echo ""
        echo -e "${CYAN}Search for menu options by keyword${NC}"
        echo ""
        read -p "Enter search term (or 'back' to return): " search_term
        
        if [[ "$search_term" == "back" || "$search_term" == "b" ]]; then
            break
        fi
        
        if [[ -z "$search_term" ]]; then
            echo -e "${RED}Please enter a search term${NC}"
            read -p "Press Enter to continue..."
            continue
        fi
        
        echo ""
        
        # Use database-driven search
        search_menu_database "$search_term"
        
        echo ""
        echo -e "${GRAY}Tip: Use short keywords for better results${NC}"
        echo ""
        read -p "Press Enter to search again (or type 'back' to return)..."
    done
}
# Main script execution
main() {
    # Critical security check: Verify GAM domain matches configuration
    echo -e "${BLUE}=== GWOMBAT Security Verification ===${NC}"
    if ! verify_gam_domain; then
        echo ""
        echo -e "${RED}❌ CRITICAL SECURITY ERROR: Cannot proceed with domain mismatch${NC}"
        echo ""
        echo "This prevents potential data operations on the wrong domain."
        echo "Please fix the domain configuration and try again."
        echo ""
        exit 1
    fi
    echo ""
    
    # Check for first-time setup
    if check_first_time_setup; then
        echo -e "${BLUE}=== GWOMBAT First-Time Setup ===${NC}"
        echo ""
        echo "Welcome to GWOMBAT! It looks like this is your first time running the application."
        echo ""
        echo "Would you like to run the setup wizard to configure GWOMBAT for your environment?"
        echo "The wizard will help you configure:"
        echo ""
        echo "• Google Workspace domain and admin settings"
        echo "• GAM (Google Apps Manager) configuration"
        echo "• Organizational unit structure"
        echo "• Python environment and dependencies"
        echo "• Optional tools (GYB, rclone, restic)"
        echo "• Initial system scans and statistics"
        echo ""
        echo "1. Yes - Run setup wizard (recommended)"
        echo "2. No - Continue to main menu"
        echo "3. Exit"
        echo ""
        
        while true; do
            read -p "Select option (1-3): " setup_choice
            case "$setup_choice" in
                1)
                    echo ""
                    echo -e "${CYAN}Starting setup wizard...${NC}"
                    if [[ -x "./setup_wizard.sh" ]]; then
                        ./setup_wizard.sh
                        # After setup wizard completes, continue to main menu
                        break
                    else
                        echo -e "${RED}Setup wizard not found. Continuing to main menu.${NC}"
                        break
                    fi
                    ;;
                2)
                    echo ""
                    echo -e "${YELLOW}Skipping setup wizard. You can run it later with: ./setup_wizard.sh${NC}"
                    echo ""
                    break
                    ;;
                3)
                    echo "Goodbye!"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please select 1, 2, or 3.${NC}"
                    ;;
            esac
        done
        
        echo ""
        read -p "Press Enter to continue to GWOMBAT main menu..."
    fi
    
    # Run dependency check on startup
    if ! check_dependencies; then
        echo -e "${RED}Dependency check failed. Please install missing dependencies before continuing.${NC}"
        echo -e "${YELLOW}Press Enter to continue anyway, or Ctrl+C to exit...${NC}"
        read -r
    fi
    
    while true; do
        show_main_menu
        choice=$?
        
        case $choice in
            1)
                user_group_management_menu
                ;;
            2)
                file_drive_operations_menu
                ;;
            3)
                analysis_discovery_menu
                ;;
            4)
                list_management_menu
                ;;
            5)
                dashboard_menu
                ;;
            6)
                reports_and_cleanup_menu
                ;;
            7)
                system_administration_menu
                ;;
            8)
                scuba_compliance_menu
                ;;
            97)
                # Menu Index (Alphabetical)
                show_menu_index
                ;;
            98)
                # Search Menu Options
                search_menu_options
                ;;
            99)
                # Configuration Management
                if [[ -x "$SHARED_UTILITIES_PATH/config_manager.sh" ]]; then
                    source "$SHARED_UTILITIES_PATH/config_manager.sh"
                    show_config_menu
                else
                    configuration_menu
                fi
                ;;
            10)
                echo -e "${BLUE}Goodbye!${NC}"
                log_info "Session ended by user"
                echo "=== SESSION END: $(date) ===" >> "$LOG_FILE"
                generate_daily_report
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please select a number between 1-8, c, s, i, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Check if required directories exist
if [[ ! -d "$SCRIPTPATH" ]]; then
    echo -e "${RED}Error: Script path $SCRIPTPATH does not exist.${NC}"
    exit 1
fi

if [[ ! -d "$SHARED_UTILITIES_PATH" ]]; then
    echo -e "${RED}Error: Shared utilities path $SHARED_UTILITIES_PATH does not exist.${NC}"
    exit 1
fi

# Run the main function
main
