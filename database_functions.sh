#!/bin/bash

# Account Lifecycle Database Management Functions
# SQLite-based persistent state tracking for account management

# Database configuration
DB_FILE="${SCRIPTPATH}/account_lifecycle.db"
DB_SCHEMA_FILE="${SCRIPTPATH}/database_schema.sql"

# Initialize database
init_database() {
    local db_file="$1"
    [[ -z "$db_file" ]] && db_file="$DB_FILE"
    
    if [[ ! -f "$db_file" ]]; then
        echo -e "${CYAN}Initializing account lifecycle database...${NC}"
        
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
    
    # Sanitize all inputs
    email=$(sanitize_sql_input "$email")
    stage=$(sanitize_sql_input "$stage")
    display_name=$(sanitize_sql_input "$display_name")
    ou_path=$(sanitize_sql_input "$ou_path")
    
    init_database || return 1
    
    sqlite3 "$DB_FILE" <<EOF
INSERT OR REPLACE INTO accounts (email, current_stage, display_name, ou_path, updated_at)
VALUES ('$email', '$stage', '$display_name', '$ou_path', CURRENT_TIMESTAMP);
EOF
    
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
    
    sqlite3 "$DB_FILE" <<EOF
INSERT INTO account_lists (name, description, target_stage)
VALUES ('$list_name', '$description', '$target_stage');
EOF
    
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
    
    # Update account stage
    sqlite3 "$DB_FILE" <<EOF
UPDATE accounts 
SET current_stage = '$to_stage', updated_at = CURRENT_TIMESTAMP 
WHERE email = '$email';

INSERT INTO stage_history (account_id, from_stage, to_stage, operation_details, session_id)
SELECT id, '$from_stage', '$to_stage', '$operation_details', '$SESSION_ID'
FROM accounts WHERE email = '$email';
EOF
    
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
    expected_stage=$(sanitize_sql_input "$expected_stage")
    
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
    
    # Update overall verification timestamp
    sqlite3 "$DB_FILE" "UPDATE accounts SET last_verified_at = CURRENT_TIMESTAMP WHERE email = '$email';"
    
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
    expected_stage=$(sanitize_sql_input "$expected_stage")
    
    # If no stage provided, get from list definition
    if [[ -z "$expected_stage" ]]; then
        expected_stage=$(sqlite3 "$DB_FILE" "SELECT target_stage FROM account_lists WHERE name = '$list_name';")
        if [[ -z "$expected_stage" ]]; then
            echo -e "${RED}Error: No target stage found for list $list_name${NC}"
            return 1
        fi
    fi
    
    echo -e "${BLUE}=== Bulk Verification: $list_name (Stage: $expected_stage) ===${NC}"
    echo ""
    
    # Get all accounts in list
    local accounts=($(sqlite3 "$DB_FILE" "SELECT a.email FROM accounts a JOIN account_list_memberships alm ON a.id = alm.account_id JOIN account_lists l ON alm.list_id = l.id WHERE l.name = '$list_name';"))
    
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
        local count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM accounts WHERE current_stage = '$stage';" 2>/dev/null || echo "0")
        
        if [[ $count -gt 0 ]]; then
            local list_name="${list_prefix}_${stage}"
            local description="Auto-generated list from account scan on $(date)"
            
            # Create the list
            if db_create_list "$list_name" "$description" "$stage"; then
                # Add all accounts of this stage to the list
                sqlite3 "$DB_FILE" <<EOF
INSERT INTO account_list_memberships (account_id, list_id)
SELECT a.id, l.id
FROM accounts a, account_lists l
WHERE a.current_stage = '$stage' AND l.name = '$list_name';
EOF
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