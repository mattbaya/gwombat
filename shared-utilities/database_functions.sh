#!/bin/bash

# Account Lifecycle Database Management Functions
# SQLite-based persistent state tracking for account management

# Database configuration
SCRIPTPATH="${SCRIPTPATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Ensure we're in the gwombat directory if not already set correctly
if [[ "$(basename "$SCRIPTPATH")" != "gwombat" ]]; then
    SCRIPTPATH="${SCRIPTPATH}/gwombat"
fi
DB_FILE="${SCRIPTPATH}/local-config/gwombat.db"
MENU_DB_FILE="${SCRIPTPATH}/shared-config/menu.db"
DB_SCHEMA_FILE="${SCRIPTPATH}/shared-config/database_schema.sql"

# Color definitions (fallback if not defined elsewhere)
if [[ -z "$RED" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    GRAY='\033[0;37m'
    NC='\033[0m' # No Color
fi

# Logging function (fallback if not defined elsewhere)
if ! command -v log_info >/dev/null 2>&1; then
    log_info() {
        echo "[INFO] $1" >&2
    }
fi

# Secure database query function to prevent SQL injection
secure_sqlite_query() {
    local db_file="$1"
    local query="$2"
    shift 2
    local params=("$@")
    
    # Basic input validation
    if [[ ! -f "$db_file" ]]; then
        echo -e "${RED}Error: Database file does not exist: $db_file${NC}" >&2
        return 1
    fi
    
    # Sanitize parameters by escaping single quotes
    local sanitized_params=()
    for param in "${params[@]}"; do
        # Escape single quotes and control characters
        sanitized_param=$(printf '%s\n' "$param" | sed "s/'/''/g" | tr -d '\0-\37\177-\377')
        sanitized_params+=("$sanitized_param")
    done
    
    # Execute query with sanitized parameters
    # Note: This is a basic implementation. For production use, consider prepared statements
    printf -v formatted_query "$query" "${sanitized_params[@]}"
    sqlite3 "$db_file" "$formatted_query"
}

# Database backup function
create_database_backup() {
    local db_file="$1"
    local backup_name="$2"
    local backup_dir="${SCRIPTPATH}/local-config/backups"
    
    # Validate inputs
    if [[ ! -f "$db_file" ]]; then
        echo -e "${RED}Error: Database file does not exist: $db_file${NC}" >&2
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    # Generate backup filename with timestamp
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_filename="${backup_name:-gwombat}_backup_${timestamp}.db"
    local backup_path="$backup_dir/$backup_filename"
    
    # Create backup
    if cp "$db_file" "$backup_path"; then
        echo -e "${GREEN}✓ Database backup created: $backup_path${NC}"
        
        # Verify backup integrity
        if sqlite3 "$backup_path" "PRAGMA integrity_check;" | grep -q "ok"; then
            echo -e "${GREEN}✓ Backup integrity verified${NC}"
            
            # Create backup manifest
            echo "Backup created: $(date)" > "$backup_path.manifest"
            echo "Source database: $db_file" >> "$backup_path.manifest"
            echo "Backup size: $(stat -f%z "$backup_path" 2>/dev/null || stat -c%s "$backup_path" 2>/dev/null) bytes" >> "$backup_path.manifest"
            
            return 0
        else
            echo -e "${RED}❌ Backup integrity check failed${NC}" >&2
            rm -f "$backup_path"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to create backup${NC}" >&2
        return 1
    fi
}

# Database restore function
restore_database_backup() {
    local backup_file="$1"
    local target_db="$2"
    
    # Validate inputs
    if [[ ! -f "$backup_file" ]]; then
        echo -e "${RED}Error: Backup file does not exist: $backup_file${NC}" >&2
        return 1
    fi
    
    if [[ -z "$target_db" ]]; then
        echo -e "${RED}Error: Target database path required${NC}" >&2
        return 1
    fi
    
    # Verify backup integrity before restore
    if ! sqlite3 "$backup_file" "PRAGMA integrity_check;" | grep -q "ok"; then
        echo -e "${RED}❌ Backup file is corrupted, cannot restore${NC}" >&2
        return 1
    fi
    
    # Create backup of current database if it exists
    if [[ -f "$target_db" ]]; then
        echo -e "${YELLOW}Creating backup of current database before restore...${NC}"
        create_database_backup "$target_db" "pre_restore"
    fi
    
    # Perform restore
    if cp "$backup_file" "$target_db"; then
        echo -e "${GREEN}✓ Database restored from: $backup_file${NC}"
        echo -e "${GREEN}✓ Restored to: $target_db${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to restore database${NC}" >&2
        return 1
    fi
}

# List available backups
list_database_backups() {
    local backup_dir="${SCRIPTPATH}/local-config/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${YELLOW}No backup directory found${NC}"
        return 1
    fi
    
    local backups=($(find "$backup_dir" -name "*.db" -type f 2>/dev/null | sort -r))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No database backups found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Available database backups:${NC}"
    local i=1
    for backup in "${backups[@]}"; do
        local size=$(stat -f%z "$backup" 2>/dev/null || stat -c%s "$backup" 2>/dev/null)
        local date=$(stat -f%Sm "$backup" 2>/dev/null || stat -c%y "$backup" 2>/dev/null)
        echo "  $i. $(basename "$backup") (${size} bytes, $date)"
        ((i++))
    done
    
    return 0
}

# Validate database integrity
validate_database() {
    local db_file="$1"
    
    if [[ ! -f "$db_file" ]]; then
        echo -e "${RED}Error: Database file does not exist: $db_file${NC}" >&2
        return 1
    fi
    
    echo -e "${CYAN}Validating database: $db_file${NC}"
    
    # Check integrity
    local integrity_result=$(sqlite3 "$db_file" "PRAGMA integrity_check;" 2>&1)
    if [[ "$integrity_result" == "ok" ]]; then
        echo -e "${GREEN}✓ Database integrity check passed${NC}"
    else
        echo -e "${RED}❌ Database integrity check failed:${NC}"
        echo "$integrity_result"
        return 1
    fi
    
    # Check table counts
    local table_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null)
    echo -e "${CYAN}Tables found: $table_count${NC}"
    
    # Check if main tables exist
    local main_tables=("accounts" "account_lists" "stage_history")
    for table in "${main_tables[@]}"; do
        if sqlite3 "$db_file" "SELECT COUNT(*) FROM $table;" >/dev/null 2>&1; then
            local count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM $table;" 2>/dev/null)
            echo -e "${GREEN}✓ Table $table: $count records${NC}"
        else
            echo -e "${YELLOW}⚠️  Table $table: not found or empty${NC}"
        fi
    done
    
    return 0
}

# Initialize database
init_database() {
    local db_file="$1"
    [[ -z "$db_file" ]] && db_file="$DB_FILE"
    
    if [[ ! -f "$db_file" ]]; then
        echo -e "${CYAN}Initializing GWOMBAT database...${NC}"
        
        if [[ ! -f "$DB_SCHEMA_FILE" ]]; then
            echo -e "${RED}Error: Database schema file not found: $DB_SCHEMA_FILE${NC}"
            return 1
        fi
        
        # Check if sqlite3 is installed
        if ! command -v sqlite3 >/dev/null 2>&1; then
            echo -e "${RED}Error: sqlite3 is not installed${NC}"
            echo -e "${YELLOW}To install SQLite:${NC}"
            echo -e "${YELLOW}  CentOS/RHEL: sudo yum install sqlite${NC}"
            echo -e "${YELLOW}  Ubuntu/Debian: sudo apt-get install sqlite3${NC}"
            echo -e "${YELLOW}  macOS: brew install sqlite${NC}"
            return 1
        fi
        
        sqlite3 "$db_file" < "$DB_SCHEMA_FILE"
        
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Database initialized successfully: $db_file${NC}"
            log_info "Database initialized: $db_file"
            return 0
        else
            echo -e "${RED}Failed to initialize database${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Check if database exists and is accessible
check_database() {
    local db_file="$1"
    [[ -z "$db_file" ]] && db_file="$DB_FILE"
    
    if [[ ! -f "$db_file" ]]; then
        return 1
    fi
    
    # Test database connectivity
    sqlite3 "$db_file" "SELECT COUNT(*) FROM config;" >/dev/null 2>&1
    return $?
}

# Sanitize input for SQL to prevent injection
sanitize_sql_input() {
    local input="$1"
    # Replace single quotes with two single quotes (SQL escaping)
    echo "${input//\'/\'\'}"
}

# Add or update account in database
db_add_account() {
    local email="$1"
    local stage="$2"
    local display_name="$3"
    local ou_path="$4"
    
    if [[ -z "$email" || -z "$stage" ]]; then
        echo -e "${RED}Error: Email and stage are required${NC}"
        return 1
    fi
    
    # Input validation handled by secure_sqlite_query
    
    init_database || return 1
    
    # Use secure query to prevent SQL injection
    secure_sqlite_query "$DB_FILE" "INSERT OR REPLACE INTO accounts (email, current_stage, display_name, ou_path, updated_at) VALUES ('%s', '%s', '%s', '%s', CURRENT_TIMESTAMP);" "$email" "$stage" "$display_name" "$ou_path"
    
    if [[ $? -eq 0 ]]; then
        log_info "Account added/updated in database: $email -> $stage"
        return 0
    else
        echo -e "${RED}Failed to add/update account: $email${NC}"
        return 1
    fi
}

# Create new account list/tag
db_create_list() {
    local list_name="$1"
    local description="$2"
    local target_stage="$3"
    
    if [[ -z "$list_name" ]]; then
        echo -e "${RED}Error: List name is required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    list_name=$(sanitize_sql_input "$list_name")
    description=$(sanitize_sql_input "$description")
    target_stage=$(sanitize_sql_input "$target_stage")
    
    init_database || return 1
    
    # Use secure query to prevent SQL injection
    secure_sqlite_query "$DB_FILE" "INSERT INTO account_lists (name, description, target_stage) VALUES ('%s', '%s', '%s');" "$list_name" "$description" "$target_stage"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Account list created: $list_name${NC}"
        log_info "Created account list: $list_name"
        return 0
    else
        echo -e "${RED}Failed to create list: $list_name (may already exist)${NC}"
        return 1
    fi
}

# Add account to list
db_add_to_list() {
    local email="$1"
    local list_name="$2"
    
    if [[ -z "$email" || -z "$list_name" ]]; then
        echo -e "${RED}Error: Email and list name are required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    list_name=$(sanitize_sql_input "$list_name")
    
    init_database || return 1
    
    sqlite3 "$DB_FILE" <<EOF
INSERT OR IGNORE INTO account_list_memberships (account_id, list_id)
SELECT a.id, l.id
FROM accounts a, account_lists l
WHERE a.email = '$email' AND l.name = '$list_name';
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "Added account to list: $email -> $list_name"
        return 0
    else
        echo -e "${RED}Failed to add account to list: $email -> $list_name${NC}"
        return 1
    fi
}

# Record stage change
db_record_stage_change() {
    local email="$1"
    local from_stage="$2"
    local to_stage="$3"
    local operation_details="$4"
    
    if [[ -z "$email" || -z "$to_stage" ]]; then
        echo -e "${RED}Error: Email and target stage are required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    from_stage=$(sanitize_sql_input "$from_stage")
    to_stage=$(sanitize_sql_input "$to_stage")
    operation_details=$(sanitize_sql_input "$operation_details")
    
    init_database || return 1
    
    # Update account stage (secure queries to prevent SQL injection)
    secure_sqlite_query "$DB_FILE" "UPDATE accounts SET current_stage = '%s', updated_at = CURRENT_TIMESTAMP WHERE email = '%s';" "$to_stage" "$email"
    
    if [[ $? -eq 0 ]]; then
        # Record stage history
        secure_sqlite_query "$DB_FILE" "INSERT INTO stage_history (account_id, from_stage, to_stage, operation_details, session_id) SELECT id, '%s', '%s', '%s', '%s' FROM accounts WHERE email = '%s';" "$from_stage" "$to_stage" "$operation_details" "$SESSION_ID" "$email"
    fi
    
    if [[ $? -eq 0 ]]; then
        log_info "Stage change recorded: $email: $from_stage -> $to_stage"
        return 0
    else
        echo -e "${RED}Failed to record stage change: $email${NC}"
        return 1
    fi
}

# Set verification status
db_set_verification() {
    local email="$1"
    local stage="$2"
    local verification_type="$3"
    local status="$4"
    local details="$5"
    
    if [[ -z "$email" || -z "$stage" || -z "$verification_type" || -z "$status" ]]; then
        echo -e "${RED}Error: All verification parameters are required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    stage=$(sanitize_sql_input "$stage")
    verification_type=$(sanitize_sql_input "$verification_type")
    status=$(sanitize_sql_input "$status")
    details=$(sanitize_sql_input "$details")
    
    init_database || return 1
    
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO verification_status (account_id, stage, verification_type, status, details, verified_at)
SELECT id, '$stage', '$verification_type', '$status', '$details', CURRENT_TIMESTAMP
FROM accounts WHERE email = '$email';
EOF
    
    if [[ $? -eq 0 ]]; then
        log_info "Verification status set: $email [$stage:$verification_type] -> $status"
        return 0
    else
        echo -e "${RED}Failed to set verification status: $email${NC}"
        return 1
    fi
}

# Get accounts in list
db_get_list_accounts() {
    local list_name="$1"
    
    if [[ -z "$list_name" ]]; then
        echo -e "${RED}Error: List name is required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    list_name=$(sanitize_sql_input "$list_name")
    
    init_database || return 1
    
    sqlite3 "$DB_FILE" -header -column <<EOF
SELECT a.email, a.display_name, a.current_stage, a.updated_at
FROM accounts a
JOIN account_list_memberships alm ON a.id = alm.account_id
JOIN account_lists l ON alm.list_id = l.id
WHERE l.name = '$list_name' AND l.is_active = 1
ORDER BY a.updated_at DESC;
EOF
}

# Get verification status for account
db_get_verification_status() {
    local email="$1"
    local stage="$2"
    
    if [[ -z "$email" ]]; then
        echo -e "${RED}Error: Email is required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    stage=$(sanitize_sql_input "$stage")
    
    init_database || return 1
    
    local stage_filter=""
    if [[ -n "$stage" ]]; then
        stage_filter="AND vs.stage = '$stage'"
    fi
    
    sqlite3 "$DB_FILE" -header -column <<EOF
SELECT vs.stage, vs.verification_type, vs.status, vs.verified_at, vs.details
FROM verification_status vs
JOIN accounts a ON vs.account_id = a.id
WHERE a.email = '$email' $stage_filter
ORDER BY vs.verified_at DESC;
EOF
}

# List all account lists with progress
db_list_account_lists() {
    init_database || return 1
    
    sqlite3 "$DB_FILE" -header -column <<EOF
SELECT 
    list_name,
    target_stage,
    total_accounts,
    accounts_at_target,
    verified_accounts,
    completion_percentage || '%' as completion
FROM list_progress
WHERE total_accounts > 0
ORDER BY list_name;
EOF
}

# Verify account state matches expected stage requirements
verify_account_state() {
    local email="$1"
    local expected_stage="$2"
    local auto_fix="${3:-false}"
    
    if [[ -z "$email" || -z "$expected_stage" ]]; then
        echo -e "${RED}Error: Email and expected stage are required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    # Input validation will be handled by secure_sqlite_query
    
    echo -e "${CYAN}Verifying account state: $email (expected: $expected_stage)${NC}"
    
    # Get current GAM status
    local user_info=$($GAM info user "$email" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        db_set_verification "$email" "$expected_stage" "user_exists" "failed" "User not found in GAM"
        echo -e "${RED}❌ User not found: $email${NC}"
        return 1
    fi
    
    # Extract key information
    local current_ou=$(echo "$user_info" | grep "Org Unit Path" | cut -d: -f2 | xargs)
    local lastname=$(echo "$user_info" | grep "Family Name" | cut -d: -f2 | xargs)
    local suspended=$(echo "$user_info" | grep "Suspended" | cut -d: -f2 | xargs)
    
    local verification_passed=0
    local verification_details=""
    
    # Stage-specific verification
    case "$expected_stage" in
        "recently_suspended")
            if [[ "$suspended" == "True" ]]; then
                echo -e "${GREEN}✅ User is suspended${NC}"
                db_set_verification "$email" "$expected_stage" "suspension_status" "verified" "User correctly suspended"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ User is not suspended${NC}"
                db_set_verification "$email" "$expected_stage" "suspension_status" "failed" "User not suspended"
            fi
            ;;
            
        "pending_deletion")
            # Check OU
            if [[ "$current_ou" =~ "Pending Deletion" ]]; then
                echo -e "${GREEN}✅ User in Pending Deletion OU${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "verified" "In correct OU: $current_ou"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ User not in Pending Deletion OU: $current_ou${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "failed" "Wrong OU: $current_ou"
            fi
            
            # Check lastname marker
            if [[ "$lastname" =~ "PENDING DELETION" ]]; then
                echo -e "${GREEN}✅ Lastname has pending deletion marker${NC}"
                db_set_verification "$email" "$expected_stage" "lastname_marker" "verified" "Lastname: $lastname"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ Lastname missing pending deletion marker: $lastname${NC}"
                db_set_verification "$email" "$expected_stage" "lastname_marker" "failed" "Lastname: $lastname"
            fi
            
            # Check file markers (sample a few files)
            local file_check=$($GAM user "$email" print filelist fields id,name 2>/dev/null | head -5 | grep -c "PENDING DELETION")
            if [[ $file_check -gt 0 ]]; then
                echo -e "${GREEN}✅ Files have pending deletion markers (sample check: $file_check files)${NC}"
                db_set_verification "$email" "$expected_stage" "file_markers" "verified" "Sample files marked: $file_check"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${YELLOW}⚠️  No pending deletion markers found in sample files${NC}"
                db_set_verification "$email" "$expected_stage" "file_markers" "failed" "No markers in sample files"
            fi
            ;;
            
        "temporary_hold")
            if [[ "$current_ou" =~ "Temporary Hold" ]]; then
                echo -e "${GREEN}✅ User in Temporary Hold OU${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "verified" "In correct OU: $current_ou"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ User not in Temporary Hold OU: $current_ou${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "failed" "Wrong OU: $current_ou"
            fi
            
            if [[ "$lastname" =~ "Suspended Account - Temporary Hold" ]]; then
                echo -e "${GREEN}✅ Lastname has temporary hold marker${NC}"
                db_set_verification "$email" "$expected_stage" "lastname_marker" "verified" "Lastname: $lastname"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ Lastname missing temporary hold marker: $lastname${NC}"
                db_set_verification "$email" "$expected_stage" "lastname_marker" "failed" "Lastname: $lastname"
            fi
            ;;
            
        "exit_row")
            if [[ "$current_ou" =~ "Exit Row" ]]; then
                echo -e "${GREEN}✅ User in Exit Row OU${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "verified" "In correct OU: $current_ou"
                verification_passed=$((verification_passed + 1))
            else
                echo -e "${RED}❌ User not in Exit Row OU: $current_ou${NC}"
                db_set_verification "$email" "$expected_stage" "ou_placement" "failed" "Wrong OU: $current_ou"
            fi
            ;;
    esac
    
    # Update overall verification timestamp (SQL injection safe)
    secure_sqlite_query "$DB_FILE" "UPDATE accounts SET last_verified_at = CURRENT_TIMESTAMP WHERE email = '%s';" "$email"
    
    echo ""
    echo -e "${CYAN}Verification Summary: $verification_passed checks passed${NC}"
    
    if [[ $verification_passed -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Bulk verify all accounts in a list
bulk_verify_list() {
    local list_name="$1"
    local expected_stage="$2"
    
    if [[ -z "$list_name" ]]; then
        echo -e "${RED}Error: List name is required${NC}"
        return 1
    fi
    
    # Sanitize all inputs
    list_name=$(sanitize_sql_input "$list_name")
    # Input validation will be handled by secure_sqlite_query
    
    # If no stage provided, get from list definition
    if [[ -z "$expected_stage" ]]; then
        expected_stage=$(secure_sqlite_query "$DB_FILE" "SELECT target_stage FROM account_lists WHERE name = '%s';" "$list_name")
        if [[ -z "$expected_stage" ]]; then
            echo -e "${RED}Error: No target stage found for list $list_name${NC}"
            return 1
        fi
    fi
    
    echo -e "${BLUE}=== Bulk Verification: $list_name (Stage: $expected_stage) ===${NC}"
    echo ""
    
    # Get all accounts in list
    local accounts=($(secure_sqlite_query "$DB_FILE" "SELECT a.email FROM accounts a JOIN account_list_memberships alm ON a.id = alm.account_id JOIN account_lists l ON alm.list_id = l.id WHERE l.name = '%s';" "$list_name"))
    
    if [[ ${#accounts[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No accounts found in list: $list_name${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Verifying ${#accounts[@]} accounts...${NC}"
    echo ""
    
    local passed_count=0
    local failed_count=0
    local counter=0
    
    for email in "${accounts[@]}"; do
        ((counter++))
        echo -e "${BLUE}[$counter/${#accounts[@]}] $email${NC}"
        
        if verify_account_state "$email" "$expected_stage"; then
            ((passed_count++))
        else
            ((failed_count++))
        fi
        
        echo ""
    done
    
    echo -e "${BLUE}=== Bulk Verification Complete ===${NC}"
    echo -e "${GREEN}Passed: $passed_count${NC}"
    echo -e "${RED}Failed: $failed_count${NC}"
    echo -e "${CYAN}Total: ${#accounts[@]}${NC}"
    
    return 0
}

# Import accounts from file to list
import_accounts_to_list() {
    local file_path="$1"
    local list_name="$2"
    local initial_stage="$3"
    
    if [[ -z "$file_path" || -z "$list_name" || -z "$initial_stage" ]]; then
        echo -e "${RED}Error: File path, list name, and initial stage are required${NC}"
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}Error: File not found: $file_path${NC}"
        return 1
    fi
    
    # Sanitize list_name and initial_stage (file_path doesn't go into SQL)
    list_name=$(sanitize_sql_input "$list_name")
    initial_stage=$(sanitize_sql_input "$initial_stage")
    
    # Create list if it doesn't exist
    db_create_list "$list_name" "Imported from $file_path" "$initial_stage"
    
    echo -e "${CYAN}Importing accounts from $file_path to list '$list_name'...${NC}"
    
    local imported_count=0
    local skipped_count=0
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract email (assume first field if comma-separated)
        local email=$(echo "$line" | cut -d',' -f1 | xargs)
        
        if [[ -z "$email" ]]; then
            ((skipped_count++))
            continue
        fi
        
        # Sanitize email input from file
        email=$(sanitize_sql_input "$email")
        
        # Add account to database
        if db_add_account "$email" "$initial_stage"; then
            # Add to list
            if db_add_to_list "$email" "$list_name"; then
                ((imported_count++))
                echo "Imported: $email"
            else
                ((skipped_count++))
                echo "Skipped (list add failed): $email"
            fi
        else
            ((skipped_count++))
            echo "Skipped (account add failed): $email"
        fi
    done < "$file_path"
    
    echo ""
    echo -e "${GREEN}Import completed:${NC}"
    echo -e "  Imported: $imported_count"
    echo -e "  Skipped: $skipped_count"
    
    return 0
}

# Scan all suspended accounts and update database based on their current OU placement
scan_suspended_accounts() {
    local update_db="${1:-true}"
    
    echo -e "${BLUE}=== Scanning All Suspended Accounts ===${NC}"
    echo ""
    echo -e "${CYAN}Discovering accounts and their current stages based on OU placement...${NC}"
    echo ""
    
    if [[ "$update_db" == "true" ]]; then
        init_database || return 1
    fi
    
    # Get all suspended users
    echo -e "${CYAN}Querying GAM for all suspended users...${NC}"
    local suspended_users=$($GAM print users query "isSuspended=true" fields primaryemail,familyname,givenname,orgunitpath 2>/dev/null)
    
    if [[ -z "$suspended_users" ]]; then
        echo -e "${YELLOW}No suspended users found${NC}"
        return 0
    fi
    
    # Parse results and categorize by OU
    local recently_suspended=()
    local pending_deletion=()
    local temporary_hold=()
    local exit_row=()
    local other_suspended=()
    
    echo -e "${CYAN}Analyzing organizational unit placements...${NC}"
    echo ""
    
    # Process each line (skip header)
    local line_count=0
    while IFS=',' read -r email family_name given_name ou_path; do
        ((line_count++))
        
        # Skip header line
        [[ $line_count -eq 1 ]] && continue
        
        # Clean up fields
        email=$(echo "$email" | xargs)
        ou_path=$(echo "$ou_path" | xargs)
        
        [[ -z "$email" ]] && continue
        
        # Determine stage based on OU path
        local stage=""
        local display_name="$given_name $family_name"
        
        case "$ou_path" in
            *"Pending Deletion"*)
                stage="pending_deletion"
                pending_deletion+=("$email")
                ;;
            *"Temporary Hold"*)
                stage="temporary_hold"
                temporary_hold+=("$email")
                ;;
            *"Exit Row"*)
                stage="exit_row"
                exit_row+=("$email")
                ;;
            *"Suspended"*)
                # Generic suspended OU - likely recently suspended
                stage="recently_suspended"
                recently_suspended+=("$email")
                ;;
            *)
                # Other locations - might be recent suspensions not moved yet
                stage="recently_suspended"
                other_suspended+=("$email")
                ;;
        esac
        
        # Update database if requested
        if [[ "$update_db" == "true" && -n "$stage" ]]; then
            db_add_account "$email" "$stage" "$display_name" "$ou_path"
        fi
        
        # Show progress every 10 accounts
        if (( line_count % 10 == 0 )); then
            echo -n "."
        fi
    done <<< "$suspended_users"
    
    echo ""
    echo ""
    
    # Display results summary
    echo -e "${BLUE}=== Account Discovery Results ===${NC}"
    echo ""
    
    if [[ ${#recently_suspended[@]} -gt 0 ]]; then
        echo -e "${GREEN}Recently Suspended (${#recently_suspended[@]} accounts):${NC}"
        printf '  %s\n' "${recently_suspended[@]}" | head -5
        if [[ ${#recently_suspended[@]} -gt 5 ]]; then
            echo -e "${CYAN}  ... and $((${#recently_suspended[@]} - 5)) more${NC}"
        fi
        echo ""
    fi
    
    if [[ ${#pending_deletion[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Pending Deletion (${#pending_deletion[@]} accounts):${NC}"
        printf '  %s\n' "${pending_deletion[@]}" | head -5
        if [[ ${#pending_deletion[@]} -gt 5 ]]; then
            echo -e "${CYAN}  ... and $((${#pending_deletion[@]} - 5)) more${NC}"
        fi
        echo ""
    fi
    
    if [[ ${#temporary_hold[@]} -gt 0 ]]; then
        echo -e "${MAGENTA}Temporary Hold (${#temporary_hold[@]} accounts):${NC}"
        printf '  %s\n' "${temporary_hold[@]}" | head -5
        if [[ ${#temporary_hold[@]} -gt 5 ]]; then
            echo -e "${CYAN}  ... and $((${#temporary_hold[@]} - 5)) more${NC}"
        fi
        echo ""
    fi
    
    if [[ ${#exit_row[@]} -gt 0 ]]; then
        echo -e "${RED}Exit Row (${#exit_row[@]} accounts):${NC}"
        printf '  %s\n' "${exit_row[@]}" | head -5
        if [[ ${#exit_row[@]} -gt 5 ]]; then
            echo -e "${CYAN}  ... and $((${#exit_row[@]} - 5)) more${NC}"
        fi
        echo ""
    fi
    
    if [[ ${#other_suspended[@]} -gt 0 ]]; then
        echo -e "${CYAN}Other Suspended Locations (${#other_suspended[@]} accounts):${NC}"
        printf '  %s\n' "${other_suspended[@]}" | head -3
        if [[ ${#other_suspended[@]} -gt 3 ]]; then
            echo -e "${CYAN}  ... and $((${#other_suspended[@]} - 3)) more${NC}"
        fi
        echo ""
    fi
    
    local total_found=$((${#recently_suspended[@]} + ${#pending_deletion[@]} + ${#temporary_hold[@]} + ${#exit_row[@]} + ${#other_suspended[@]}))
    echo -e "${BLUE}Total suspended accounts found: $total_found${NC}"
    
    if [[ "$update_db" == "true" ]]; then
        echo -e "${GREEN}✅ Database updated with discovered accounts${NC}"
        log_info "Account scan completed: $total_found accounts discovered and catalogued"
    fi
    
    return 0
}

# Auto-create lists based on current account stages
auto_create_stage_lists() {
    local list_prefix="${1:-scan_$(date +%Y%m%d_%H%M)}"
    
    echo -e "${CYAN}Auto-creating lists based on current account stages...${NC}"
    echo ""
    
    init_database || return 1
    
    # Create lists for each stage that has accounts
    for stage in recently_suspended pending_deletion temporary_hold exit_row; do
        local count=$(secure_sqlite_query "$DB_FILE" "SELECT COUNT(*) FROM accounts WHERE current_stage = '%s';" "$stage" 2>/dev/null || echo "0")
        
        if [[ $count -gt 0 ]]; then
            local list_name="${list_prefix}_${stage}"
            local description="Auto-generated list from account scan on $(date)"
            
            # Create the list
            if db_create_list "$list_name" "$description" "$stage"; then
                # Add all accounts of this stage to the list
                secure_sqlite_query "$DB_FILE" "INSERT INTO account_list_memberships (account_id, list_id) SELECT a.id, l.id FROM accounts a, account_lists l WHERE a.current_stage = '%s' AND l.name = '%s';" "$stage" "$list_name"
                echo -e "${GREEN}✅ Created list '$list_name' with $count accounts${NC}"
            else
                echo -e "${RED}❌ Failed to create list for stage: $stage${NC}"
            fi
        fi
    done
    
    echo ""
    echo -e "${BLUE}Auto-list creation completed${NC}"
    return 0
}

# =============================================
# MENU MANAGEMENT FUNCTIONS
# =============================================

# Initialize menu database schema
init_menu_database() {
    local menu_schema_file="${SCRIPTPATH}/shared-config/menu_schema.sql"
    
    if [[ ! -f "$menu_schema_file" ]]; then
        echo -e "${RED}Error: Menu schema file not found: $menu_schema_file${NC}"
        return 1
    fi
    
    sqlite3 "$MENU_DB_FILE" < "$menu_schema_file"
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Menu database schema initialized${NC}"
        return 0
    else
        echo -e "${RED}Failed to initialize menu database schema${NC}"
        return 1
    fi
}

# Generate main menu from database
generate_main_menu() {
    local menu_html=""
    
    # Get sections in order
    while IFS='|' read -r section_id section_name display_name description icon color_code; do
        [[ -z "$section_id" ]] && continue
        
        # Display section header (bash 3.2 compatible)
        case "$color_code" in
            "GREEN") color_var="$GREEN" ;;
            "BLUE") color_var="$BLUE" ;;
            "PURPLE") color_var="$PURPLE" ;;
            "CYAN") color_var="$CYAN" ;;
            "YELLOW") color_var="$YELLOW" ;;
            "RED") color_var="$RED" ;;
            *) color_var="$GRAY" ;;
        esac
        display_upper=$(echo "$display_name" | tr '[:lower:]' '[:upper:]')
        echo -e "${color_var}=== ${display_upper} ===${NC}"
        echo "$section_id. $icon $display_name"
        echo ""
    done < <(sqlite3 "$MENU_DB_FILE" "
        SELECT id, name, display_name, description, icon, color_code 
        FROM menu_sections 
        WHERE is_active = 1 
        ORDER BY section_order;
    ")
    
    # Display navigation options
    echo -e "${GRAY}=== NAVIGATION ===${NC}"
    while IFS='|' read -r key_char display_name icon; do
        [[ -z "$key_char" ]] && continue
        echo "$key_char. $icon $display_name"
    done < <(sqlite3 "$MENU_DB_FILE" "
        SELECT key_char, display_name, icon 
        FROM menu_navigation 
        WHERE is_active = 1 
        ORDER BY nav_order;
    ")
}

# Generate submenu from database
generate_submenu() {
    local section_name="$1"
    
    if [[ -z "$section_name" ]]; then
        echo -e "${RED}Error: Section name required${NC}"
        return 1
    fi
    
    # Get section info
    local section_info=$(sqlite3 "$MENU_DB_FILE" "
        SELECT display_name, description, icon, color_code 
        FROM menu_sections 
        WHERE name = '$section_name' AND is_active = 1;
    ")
    
    if [[ -z "$section_info" ]]; then
        echo -e "${RED}Error: Section '$section_name' not found${NC}"
        return 1
    fi
    
    IFS='|' read -r display_name description icon color_code <<< "$section_info"
    
    # Display section header
    echo -e "${!color_code}=== $display_name ===${NC}"
    echo ""
    echo -e "${CYAN}$description${NC}"
    echo ""
    
    # Group items by their prefixes for better organization
    local current_group=""
    local item_count=0
    
    while IFS='|' read -r item_order display_name description icon keywords; do
        [[ -z "$item_order" ]] && continue
        
        # Detect group changes based on keywords or patterns
        local new_group=""
        if [[ "$keywords" =~ "lifecycle" ]]; then
            new_group="SUSPENDED ACCOUNT LIFECYCLE"
        elif [[ "$keywords" =~ "scan|search|discover" ]]; then
            new_group="ACCOUNT DISCOVERY & SCANNING"
        elif [[ "$keywords" =~ "bulk|individual|status" ]]; then
            new_group="ACCOUNT MANAGEMENT"
        elif [[ "$keywords" =~ "group|license" ]]; then
            new_group="GROUP & LICENSE MANAGEMENT"
        elif [[ "$keywords" =~ "statistics|reports|export" ]]; then
            new_group="REPORTS & ANALYTICS"
        fi
        
        # Display group header if changed
        if [[ -n "$new_group" && "$new_group" != "$current_group" ]]; then
            if [[ $item_count -gt 0 ]]; then
                echo ""
            fi
            echo -e "${BLUE}=== $new_group ===${NC}"
            current_group="$new_group"
        fi
        
        echo "$item_order. $icon $display_name"
        ((item_count++))
        
    done < <(sqlite3 "$MENU_DB_FILE" "
        SELECT item_order, display_name, description, icon, keywords
        FROM menu_items 
        WHERE section_id = (SELECT id FROM menu_sections WHERE name = '$section_name')
        AND is_active = 1 
        ORDER BY item_order;
    ")
    
    # Display navigation options
    echo ""
    echo "p. Previous menu (Main menu)"
    echo "m. Main menu"
    echo "x. Exit"
}

# Get function name for menu choice
get_menu_function() {
    local section_name="$1"
    local choice="$2"
    
    if [[ -z "$section_name" || -z "$choice" ]]; then
        echo -e "${RED}Error: Section name and choice required${NC}" >&2
        return 1
    fi
    
    # Check if it's a navigation option first
    local nav_function=$(secure_sqlite_query "$MENU_DB_FILE" "SELECT function_name FROM menu_navigation WHERE key_char = '%s' AND is_active = 1;" "$choice")
    
    if [[ -n "$nav_function" ]]; then
        echo "$nav_function"
        return 0
    fi
    
    # Check if it's a menu item
    local item_function=$(secure_sqlite_query "$MENU_DB_FILE" "SELECT function_name FROM menu_items WHERE section_id = (SELECT id FROM menu_sections WHERE name = '%s') AND item_order = '%s' AND is_active = 1;" "$section_name" "$choice")
    
    if [[ -n "$item_function" ]]; then
        echo "$item_function"
        return 0
    fi
    
    # Not found
    return 1
}

# Database-driven search function
search_menu_database() {
    local search_term="$1"
    
    if [[ -z "$search_term" ]]; then
        echo -e "${RED}Please enter a search term${NC}"
        return 1
    fi
    
    local search_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
    local found=false
    
    echo -e "${CYAN}Search results for: '$search_term'${NC}"
    echo ""
    
    # Search through menu items and sections  
    while IFS='|' read -r result_type result_id title description sort_order icon color_code function_name keywords searchable_text; do
        [[ -z "$result_type" ]] && continue
        
        # Check if search term matches
        if [[ "$searchable_text" =~ .*$search_lower.* ]]; then
            found=true
            
            if [[ "$result_type" == "section" ]]; then
                local color_var="${color_code:-GREEN}"
                echo -e "${!color_var}$sort_order. $title${NC}"
                if [[ -n "$description" ]]; then
                    echo "   • $description"
                fi
            else
                # Get section info for context
                local section_info=$(sqlite3 "$DB_FILE" "
                    SELECT ms.display_name, ms.id
                    FROM menu_sections ms
                    JOIN menu_items mi ON ms.id = mi.section_id
                    WHERE mi.function_name = '$function_name';
                ")
                IFS='|' read -r section_name section_id <<< "$section_info"
                
                echo -e "${CYAN}$icon $title${NC}"
                echo "   → $section_name"
                if [[ -n "$description" ]]; then
                    echo "   • $description"
                fi
            fi
            echo ""
        fi
    done < <(sqlite3 "$MENU_DB_FILE" "SELECT * FROM menu_search ORDER BY sort_order;")
    
    if [[ "$found" != "true" ]]; then
        echo -e "${YELLOW}No menu options found matching '$search_term'${NC}"
        echo ""
        echo -e "${CYAN}Try searching for:${NC}"
        echo "• Feature names: user, file, backup, report, security"
        echo "• Tool names: gam, gyb, rclone, scuba"
        echo "• Actions: analyze, cleanup, configure, export"
        echo "• Data types: account, drive, log, database"
    fi
}

# Database-driven index function
show_menu_database_index() {
    echo -e "${BLUE}=== GWOMBAT Menu Index (Alphabetical) ===${NC}"
    echo ""
    echo -e "${CYAN}Complete listing of all menu options${NC}"
    echo ""
    
    # Get all menu items sorted alphabetically
    while IFS='|' read -r title section_name icon description; do
        [[ -z "$title" ]] && continue
        
        echo -e "${GREEN}$icon $title${NC}"
        echo "   → $section_name"
        if [[ -n "$description" ]]; then
            echo -e "${GRAY}   $description${NC}"
        fi
        echo ""
    done < <(sqlite3 "$MENU_DB_FILE" "
        SELECT mi.display_name, ms.display_name, mi.icon, mi.description
        FROM menu_items mi
        JOIN menu_sections ms ON mi.section_id = ms.id
        WHERE mi.is_active = 1 AND ms.is_active = 1
        ORDER BY mi.display_name;
    ")
    
    echo -e "${GRAY}Navigation Options:${NC}"
    while IFS='|' read -r key_char display_name icon description; do
        [[ -z "$key_char" ]] && continue
        echo -e "${BLUE}$key_char. $icon $display_name${NC}"
        if [[ -n "$description" ]]; then
            echo -e "${GRAY}   $description${NC}"
        fi
    done < <(sqlite3 "$MENU_DB_FILE" "
        SELECT key_char, display_name, icon, description
        FROM menu_navigation
        WHERE is_active = 1
        ORDER BY display_name;
    ")
}