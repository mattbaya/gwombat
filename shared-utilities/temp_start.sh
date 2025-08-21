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

# Database paths
DB_FILE="local-config/gwombat.db"
DATABASE_PATH="local-config/gwombat.db"
MENU_DB="local-config/menu.db"

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
    if [[ -f "local-config/.env" ]]; then
        source local-config/.env
        echo "Loaded environment configuration from local-config/.env"
    elif [[ -f ".env" ]]; then
        source .env
        echo "Loaded environment configuration from .env (legacy location)"
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

# Initialize the main database with all required tables
initialize_database() {
    local db_file="${DB_FILE:-local-config/gwombat.db}"
    local menu_db="${MENU_DB:-local-config/menu.db}"
    
    echo -e "${CYAN}Initializing GWOMBAT databases...${NC}"
    
    # Create local-config directory if it doesn't exist
    mkdir -p "$(dirname "$db_file")"
    
    # Initialize main database with schema
    if [[ -f "shared-config/main_schema.sql" ]]; then
        echo "  Loading main database schema..."
        if sqlite3 "$db_file" < "shared-config/main_schema.sql" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Main database initialized${NC}"
            log_info "Main database initialized at $db_file"
        else
            echo -e "${YELLOW}  ⚠ Main database initialization had warnings${NC}"
            log_error "Main database initialization warnings"
        fi
    else
        echo -e "${YELLOW}  ⚠ Main schema file not found, creating basic tables${NC}"
        # Create minimal accounts table if schema file is missing
        sqlite3 "$db_file" "CREATE TABLE IF NOT EXISTS accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            full_name TEXT,
            ou_path TEXT,
            current_stage TEXT,
            is_suspended INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );" 2>/dev/null
        
        sqlite3 "$db_file" "CREATE TABLE IF NOT EXISTS account_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_email TEXT NOT NULL,
            operation_type TEXT NOT NULL,
            operation_status TEXT NOT NULL,
            started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            completed_at TIMESTAMP
        );" 2>/dev/null
    fi
    
    # Initialize menu database
    if [[ -f "shared-config/menu_schema.sql" ]]; then
        echo "  Loading menu database schema..."
        if sqlite3 "$menu_db" < "shared-config/menu_schema.sql" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Menu database initialized${NC}"
            
            # Load menu data if available
            if [[ -x "shared-utilities/menu_data_loader.sh" ]]; then
                echo "  Loading menu data..."
                if ./shared-utilities/menu_data_loader.sh >/dev/null 2>&1; then
                    echo -e "${GREEN}  ✓ Menu data loaded${NC}"
                else
                    echo -e "${YELLOW}  ⚠ Menu data loading had issues${NC}"
                fi
            fi
        else
            echo -e "${YELLOW}  ⚠ Menu database initialization had warnings${NC}"
        fi
    fi
    
    echo -e "${GREEN}✓ Database initialization complete${NC}"
    return 0
}

# Enhanced dependency check function with logging and optional tools
store_domain_in_database() {
    local domain="$1"
    local db_file="${SCRIPTPATH}/local-config/gwombat.db"
    
    if [[ -f "$db_file" && -n "$domain" ]]; then
        sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('configured_domain', '$domain');" 2>/dev/null
        sqlite3 "$db_file" "INSERT OR REPLACE INTO config (key, value) VALUES ('domain_set_at', datetime('now'));" 2>/dev/null
    fi
}

reset_database_for_domain_change() {
    local new_domain="$1"
    local old_domain="$2"
    local db_file="${SCRIPTPATH}/local-config/gwombat.db"
    
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
        if [[ -f "${SCRIPTPATH}/shared-config/database_schema.sql" ]]; then
            echo -e "${CYAN}Initializing fresh database...${NC}"
            sqlite3 "$db_file" < "${SCRIPTPATH}/shared-config/database_schema.sql"
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
    local db_file="${SCRIPTPATH}/local-config/gwombat.db"
    
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
        
        # Check if this is GAM7
        local is_gam7=false
        if echo "$gam_version" | grep -q "GAM 7\|GAM7\|^7\." 2>/dev/null; then
            is_gam7=true
            echo -e "${GREEN}✓ GAM7: $gam_version${NC}"
            echo -e "${GREEN}  Path: $gam_path${NC}"
            log_info "GAM7 found: $gam_version at $gam_path"
        else
            echo -e "${YELLOW}⚠ GAM found but not GAM7: $gam_version${NC}"
            echo -e "${RED}  GWOMBAT requires GAM7 for compatibility${NC}"
            echo -e "${YELLOW}  Please upgrade to GAM7: https://github.com/GAM-team/GAM/wiki${NC}"
            missing_deps+=("GAM7 (Current version: $gam_version)")
            log_error "GAM version is not GAM7: $gam_version"
            recommendations+=("Upgrade to GAM7 for full compatibility: https://github.com/GAM-team/GAM/wiki")
        fi
        
        # Only check configuration if GAM7 is installed
        if [[ "$is_gam7" == "true" ]]; then
            # Check if GAM is configured (with timeout handling)
            echo -e "${YELLOW}  Checking GAM configuration...${NC}"
            if command -v timeout >/dev/null 2>&1; then
                # Use timeout if available (Linux)
                if timeout 10 $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
                    echo -e "${GREEN}  ✓ GAM7 is configured${NC}"
                    log_info "GAM7 is configured and working"
                else
                    recommendations+=("GAM7 needs configuration: Run 'gam info domain' to verify setup")
                    echo -e "${YELLOW}  ○ GAM7 found but not configured or timed out${NC}"
                    log_info "GAM7 found but not configured or configuration check timed out"
                fi
            else
                # Fallback for macOS - skip configuration check to avoid hang
                echo -e "${YELLOW}  ○ GAM7 found - configuration check skipped (run 'gam info domain' to verify)${NC}"
                recommendations+=("Verify GAM7 configuration: Run 'gam info domain' manually")
                log_info "GAM7 found but configuration check skipped (timeout not available)"
            fi
        fi
    else
        missing_deps+=("GAM7 (Google Apps Manager 7)")
        echo -e "${RED}✗ GAM7 not found at: $gam_path${NC}"
        echo -e "${YELLOW}  Install GAM7: https://github.com/GAM-team/GAM/wiki${NC}"
        log_error "GAM7 not found at: $gam_path"
        recommendations+=("Install GAM7: https://github.com/GAM-team/GAM/wiki")
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
    local db_file="${SCRIPTPATH}/local-config/gwombat.db"
    
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
    local db_file="${SCRIPTPATH}/local-config/gwombat.db"
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
                if [[ -x "./shared-utilities/setup_wizard.sh" ]]; then
                    ./shared-utilities/setup_wizard.sh
                else
                    echo -e "${RED}Setup wizard not found at ./shared-utilities/setup_wizard.sh${NC}"
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
                        [[ -f "local-config/gwombat.db" ]] && cp "local-config/gwombat.db" "$backup_dir/"
                        
                        # Backup any local-config/reports/logs
                        [[ -d "reports" ]] && cp -r "reports" "$backup_dir/"
                        [[ -d "logs" ]] && cp -r "logs" "$backup_dir/" 2>/dev/null || true
                        
                        echo -e "${GREEN}✓ Backup created: $backup_dir${NC}"
                        echo ""
                        
                        # Run setup wizard for new domain
                        echo "Starting setup wizard for new domain..."
                        if [[ -x "./shared-utilities/setup_wizard.sh" ]]; then
                            ./shared-utilities/setup_wizard.sh
                        else
                            echo -e "${RED}Setup wizard not found${NC}"
                        fi
                    else
                        echo "Domain change cancelled."
                    fi
                else
                    echo "No current domain configured. Running setup wizard..."
                    if [[ -x "./shared-utilities/setup_wizard.sh" ]]; then
                        ./shared-utilities/setup_wizard.sh
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
                if [[ -x "./shared-utilities/setup_wizard.sh" ]]; then
                    ./shared-utilities/setup_wizard.sh python
                else
                    echo -e "${RED}Setup wizard not found at ./shared-utilities/setup_wizard.sh${NC}"
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
                if [[ -f "local-config/gwombat.db" ]]; then
                    cp "local-config/gwombat.db" "$backup_dir/"
                    echo "  ✓ local-config/gwombat.db"
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
                                [[ -f "$selected_backup/local-config/gwombat.db" ]] && cp "$selected_backup/local-config/gwombat.db" "./" && echo "  ✓ database restored"
                                
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

# System Overview Menu - SQLite-driven implementation
system_overview_menu() {
    # Source database functions if not already loaded
    if ! type generate_submenu >/dev/null 2>&1; then
        source "$SHARED_UTILITIES_PATH/database_functions.sh" 2>/dev/null || {
            echo -e "${RED}Error: Cannot load database functions${NC}"
            return 1
        }
    fi
    
    while true; do
        clear
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                           GWOMBAT - System Overview                            ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Show current system status at the top
        echo -e "${CYAN}📊 Current System Status:${NC}"
        
        # Quick system health indicators
        local db_status="❌"
        local gam_status="❌" 
        local tools_status="❌"
        
        # Check database connectivity
        if sqlite3 local-config/gwombat.db "SELECT 1;" >/dev/null 2>&1; then
            db_status="✅"
        fi
        
        # Check GAM availability
        if [[ -x "$GAM" ]] && $GAM info domain >/dev/null 2>&1; then
            gam_status="✅"
        fi
        
        # Check external tools
        local tool_count=0
        [[ -x "$(command -v gyb)" ]] && ((tool_count++))
        [[ -x "$(command -v rclone)" ]] && ((tool_count++))
        if [[ $tool_count -gt 0 ]]; then
            tools_status="✅ ($tool_count/2)"
        fi
        
        echo -e "  ${WHITE}Database:${NC} $db_status  |  ${WHITE}GAM:${NC} $gam_status  |  ${WHITE}External Tools:${NC} $tools_status"
        echo ""
        
        echo -e "${GREEN}=== SYSTEM OVERVIEW OPTIONS ===${NC}"
        echo "1. 🎯 System Dashboard (Real-time overview with key metrics)"
        echo "2. 📊 System Health Check (Comprehensive system diagnostics)"
        echo "3. 📈 Performance Metrics (System performance and response times)"
        echo "4. 🔍 System Status Report (Detailed status of all components)"
        echo "5. 🗄️ Database Overview (Database status and statistics)"
        echo ""
        echo -e "${PURPLE}=== MAINTENANCE & TOOLS ===${NC}"
        echo "6. 🧹 System Cleanup (Clear logs, temp files, old data)"
        echo "7. 🔄 Refresh All Data (Force refresh of all cached data)"
