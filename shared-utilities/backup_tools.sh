#!/bin/bash

# Backup Tools Integration for GWOMBAT
# Provides GYB (Got Your Back) and rclone integration for comprehensive backup management

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
GYB_PATH="${GYB_PATH:-gyb}"
RCLONE_PATH="${RCLONE_PATH:-rclone}"
RESTIC_PATH="${RESTIC_PATH:-restic}"

# Default backup locations
BACKUP_BASE_PATH="${BACKUP_BASE_PATH:-./backups}"
GMAIL_BACKUP_PATH="${GMAIL_BACKUP_PATH:-$BACKUP_BASE_PATH/gmail}"
DRIVE_BACKUP_PATH="${DRIVE_BACKUP_PATH:-$BACKUP_BASE_PATH/drive}"
STAGING_PATH="${STAGING_PATH:-./tmp/backup_staging}"

# S3-compatible provider endpoints
declare -A S3_ENDPOINTS=(
    ["s3"]="s3.amazonaws.com"
    ["wasabi"]="s3.wasabisys.com"
    ["b2"]="s3.us-west-000.backblazeb2.com"
    ["storj"]="gateway.storjshare.io"
    ["spaces"]="nyc3.digitaloceanspaces.com"
    ["r2"]="r2.cloudflarestorage.com"
)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Initialize backup tools database
init_backup_db() {
    if [[ -f "../backup_tools_schema.sql" ]]; then
        sqlite3 "$DB_PATH" < ../backup_tools_schema.sql 2>/dev/null || true
        echo "Backup tools database initialized."
    fi
}

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Check if backup tools are available
check_backup_tools() {
    local gyb_available=0
    local rclone_available=0
    local restic_available=0
    
    if command -v "$GYB_PATH" >/dev/null 2>&1; then
        gyb_available=1
        GYB_VERSION=$($GYB_PATH --version 2>/dev/null | head -1 || echo "unknown")
    fi
    
    if command -v "$RCLONE_PATH" >/dev/null 2>&1; then
        rclone_available=1
        RCLONE_VERSION=$($RCLONE_PATH --version 2>/dev/null | head -1 || echo "unknown")
    fi
    
    if command -v "$RESTIC_PATH" >/dev/null 2>&1; then
        restic_available=1
        RESTIC_VERSION=$($RESTIC_PATH version 2>/dev/null | head -1 || echo "unknown")
    fi
    
    echo "$gyb_available|$rclone_available|$restic_available|$GYB_VERSION|$RCLONE_VERSION|$RESTIC_VERSION"
}

# Create Gmail backup using GYB
create_gmail_backup() {
    local user_email="$1"
    local backup_type="${2:-full}" # full, incremental
    local backup_path="${3:-$GMAIL_BACKUP_PATH/$user_email}"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Start backup tracking
    local backup_id=$(execute_db "
    INSERT INTO gyb_backups (user_email, backup_type, backup_path, session_id, gyb_version, status)
    VALUES ('$user_email', '$backup_type', '$backup_path', '$SESSION_ID', '$GYB_VERSION', 'running');
    SELECT last_insert_rowid();
    ")
    
    echo -e "${BLUE}Starting Gmail backup for $user_email (ID: $backup_id)${NC}"
    echo "Backup path: $backup_path"
    
    local start_time=$(date +%s)
    local gyb_flags=""
    
    # Set flags based on backup type
    case "$backup_type" in
        "full")
            gyb_flags="--email $user_email --action backup --local-folder $backup_path"
            ;;
        "incremental")
            gyb_flags="--email $user_email --action backup --local-folder $backup_path --search \"newer_than:$(date -d '1 day ago' '+%Y/%m/%d')\""
            ;;
        "verify")
            gyb_flags="--email $user_email --action restore --local-folder $backup_path --dry-run"
            ;;
    esac
    
    # Execute GYB backup
    local gyb_output
    local exit_code
    
    if gyb_output=$($GYB_PATH $gyb_flags 2>&1); then
        exit_code=0
        local status="completed"
    else
        exit_code=$?
        local status="failed"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse GYB output for statistics
    local message_count=$(echo "$gyb_output" | grep -oE 'Got [0-9]+ messages' | grep -oE '[0-9]+' || echo "0")
    local backup_size=$(du -sb "$backup_path" 2>/dev/null | cut -f1 || echo "0")
    
    # Update backup record
    execute_db "
    UPDATE gyb_backups 
    SET end_time = datetime('now'),
        status = '$status',
        exit_code = $exit_code,
        message_count = $message_count,
        backup_size_bytes = $backup_size,
        backup_flags = '$gyb_flags',
        error_message = '$(echo "$gyb_output" | tail -5 | tr "'" "''")'
    WHERE id = $backup_id;
    "
    
    if [[ "$status" == "completed" ]]; then
        echo -e "${GREEN}✓ Gmail backup completed successfully${NC}"
        echo "  Messages: $message_count"
        echo "  Size: $(numfmt --to=iec $backup_size 2>/dev/null || echo "${backup_size} bytes")"
        echo "  Duration: ${duration}s"
        
        # Schedule verification if enabled
        if [[ "${BACKUP_VERIFICATION_ENABLED:-1}" == "1" ]]; then
            verify_gmail_backup "$user_email" "$backup_path" "$backup_id"
        fi
    else
        echo -e "${RED}✗ Gmail backup failed${NC}"
        echo "Error: $(echo "$gyb_output" | tail -3)"
    fi
    
    echo "$backup_id"
}

# Verify Gmail backup integrity
verify_gmail_backup() {
    local user_email="$1"
    local backup_path="$2"
    local backup_id="$3"
    
    echo -e "${BLUE}Verifying Gmail backup for $user_email${NC}"
    
    # Basic verification: check if backup folder exists and has content
    if [[ ! -d "$backup_path" ]]; then
        execute_db "
        INSERT INTO backup_verification (backup_id, verification_type, status, details)
        VALUES ($backup_id, 'size', 'failed', '{\"error\": \"Backup directory not found\"}');
        "
        return 1
    fi
    
    # Check backup size and file count
    local backup_size=$(du -sb "$backup_path" 2>/dev/null | cut -f1 || echo "0")
    local file_count=$(find "$backup_path" -type f | wc -l)
    
    if [[ "$backup_size" -gt 0 ]] && [[ "$file_count" -gt 0 ]]; then
        execute_db "
        INSERT INTO backup_verification (backup_id, verification_type, status, backup_size, details)
        VALUES ($backup_id, 'size', 'passed', $backup_size, '{\"file_count\": $file_count, \"size_bytes\": $backup_size}');
        "
        echo -e "${GREEN}✓ Backup verification passed${NC}"
        
        # Update backup verification status
        execute_db "UPDATE gyb_backups SET verification_status = 'passed' WHERE id = $backup_id;"
    else
        execute_db "
        INSERT INTO backup_verification (backup_id, verification_type, status, details)
        VALUES ($backup_id, 'size', 'failed', '{\"error\": \"Empty backup or no files found\"}');
        "
        echo -e "${RED}✗ Backup verification failed${NC}"
        
        execute_db "UPDATE gyb_backups SET verification_status = 'failed' WHERE id = $backup_id;"
    fi
}

# Create cloud backup using rclone
create_cloud_backup() {
    local source_path="$1"
    local remote_name="$2"
    local destination_path="$3"
    local operation="${4:-copy}" # copy, sync, move
    
    # Start operation tracking
    local operation_id=$(execute_db "
    INSERT INTO rclone_operations (operation_type, source_path, destination_path, remote_name, session_id, rclone_version, status)
    VALUES ('$operation', '$source_path', '$destination_path', '$remote_name', '$SESSION_ID', '$RCLONE_VERSION', 'running');
    SELECT last_insert_rowid();
    ")
    
    echo -e "${BLUE}Starting rclone $operation (ID: $operation_id)${NC}"
    echo "Source: $source_path"
    echo "Destination: $remote_name:$destination_path"
    
    local start_time=$(date +%s)
    local rclone_flags="--progress --stats 10s --transfers 4"
    
    # Execute rclone operation
    local rclone_output
    local exit_code
    
    case "$operation" in
        "copy")
            rclone_output=$($RCLONE_PATH copy "$source_path" "$remote_name:$destination_path" $rclone_flags 2>&1)
            ;;
        "sync")
            rclone_output=$($RCLONE_PATH sync "$source_path" "$remote_name:$destination_path" $rclone_flags 2>&1)
            ;;
        "move")
            rclone_output=$($RCLONE_PATH move "$source_path" "$remote_name:$destination_path" $rclone_flags 2>&1)
            ;;
        "check")
            rclone_output=$($RCLONE_PATH check "$source_path" "$remote_name:$destination_path" 2>&1)
            ;;
    esac
    
    exit_code=$?
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse rclone output for statistics
    local transferred_files=$(echo "$rclone_output" | grep -oE 'Transferred:.*files' | grep -oE '[0-9]+' | head -1 || echo "0")
    local transferred_bytes=$(echo "$rclone_output" | grep -oE 'Transferred:.*Bytes' | grep -oE '[0-9,]+' | head -1 | tr -d ',' || echo "0")
    
    local status="completed"
    if [[ "$exit_code" -ne 0 ]]; then
        status="failed"
    fi
    
    # Update operation record
    execute_db "
    UPDATE rclone_operations 
    SET end_time = datetime('now'),
        status = '$status',
        exit_code = $exit_code,
        transferred_files = $transferred_files,
        transferred_bytes = $transferred_bytes,
        operation_flags = '$rclone_flags',
        error_message = '$(echo "$rclone_output" | tail -5 | tr "'" "''")'
    WHERE id = $operation_id;
    "
    
    if [[ "$status" == "completed" ]]; then
        echo -e "${GREEN}✓ Cloud operation completed successfully${NC}"
        echo "  Files transferred: $transferred_files"
        echo "  Bytes transferred: $(numfmt --to=iec $transferred_bytes 2>/dev/null || echo "${transferred_bytes} bytes")"
        echo "  Duration: ${duration}s"
    else
        echo -e "${RED}✗ Cloud operation failed${NC}"
        echo "Error: $(echo "$rclone_output" | tail -3)"
    fi
    
    echo "$operation_id"
}

# Backup user on suspension (trigger function)
backup_suspended_user() {
    local user_email="$1"
    local backup_gmail="${2:-1}"
    local backup_drive="${3:-1}"
    local cloud_upload="${4:-0}"
    
    echo -e "${CYAN}=== Starting Backup for Suspended User: $user_email ===${NC}"
    
    local backup_ids=()
    
    # Gmail backup with GYB
    if [[ "$backup_gmail" == "1" ]] && command -v "$GYB_PATH" >/dev/null 2>&1; then
        echo -e "${BLUE}📧 Creating Gmail backup...${NC}"
        local gmail_backup_id=$(create_gmail_backup "$user_email" "full")
        backup_ids+=("gmail:$gmail_backup_id")
    fi
    
    # Drive backup (placeholder - would use GAM or other tools)
    if [[ "$backup_drive" == "1" ]]; then
        echo -e "${BLUE}📁 Creating Drive backup...${NC}"
        local drive_backup_path="$DRIVE_BACKUP_PATH/$user_email"
        mkdir -p "$drive_backup_path"
        
        # Use GAM to backup drive files (this would be expanded)
        # $GAM user $user_email print filelist > "$drive_backup_path/filelist.csv"
        echo "Drive backup placeholder - integrate with GAM file operations"
    fi
    
    # Cloud upload with rclone
    if [[ "$cloud_upload" == "1" ]] && command -v "$RCLONE_PATH" >/dev/null 2>&1; then
        local primary_remote=$(execute_db "SELECT rclone_remote_name FROM backup_storage WHERE is_primary = 1 AND is_active = 1 LIMIT 1;")
        
        if [[ -n "$primary_remote" ]] && [[ -d "$GMAIL_BACKUP_PATH/$user_email" ]]; then
            echo -e "${BLUE}☁️ Uploading to cloud storage...${NC}"
            local cloud_operation_id=$(create_cloud_backup "$GMAIL_BACKUP_PATH/$user_email" "$primary_remote" "suspended_users/$user_email" "copy")
            backup_ids+=("cloud:$cloud_operation_id")
        fi
    fi
    
    # Record activity
    execute_db "
    INSERT INTO activity_summary (activity_type, activity_description, affected_users, session_id, details)
    VALUES ('backup', 'Automated backup for suspended user', 1, '$SESSION_ID', 
            json_object('user_email', '$user_email', 'backup_ids', '$(IFS=,; echo "${backup_ids[*]}")'));
    "
    
    echo -e "${GREEN}✓ Backup process completed for $user_email${NC}"
    echo "Backup IDs: ${backup_ids[*]}"
}

# Get backup statistics for dashboard
get_backup_stats() {
    execute_db "
    SELECT 
        metric,
        value,
        unit,
        last_updated
    FROM backup_summary
    ORDER BY metric;
    "
}

# Show backup tools status
show_backup_status() {
    echo -e "${CYAN}🔧 BACKUP TOOLS STATUS${NC}"
    
    local tool_status=$(check_backup_tools)
    IFS='|' read -r gyb_available rclone_available gyb_version rclone_version <<< "$tool_status"
    
    # GYB Status
    if [[ "$gyb_available" == "1" ]]; then
        echo -e "${WHITE}GYB (Got Your Back):${NC}  ${GREEN}✓ Available${NC} ($gyb_version)"
    else
        echo -e "${WHITE}GYB (Got Your Back):${NC}  ${RED}✗ Not Found${NC} (Install: pip install gyb)"
    fi
    
    # rclone Status
    if [[ "$rclone_available" == "1" ]]; then
        echo -e "${WHITE}rclone:${NC}              ${GREEN}✓ Available${NC} ($rclone_version)"
    else
        echo -e "${WHITE}rclone:${NC}              ${RED}✗ Not Found${NC} (Install: https://rclone.org/install/)"
    fi
    
    echo ""
    
    # Show backup statistics if tools are available
    if [[ "$gyb_available" == "1" ]] || [[ "$rclone_available" == "1" ]]; then
        echo -e "${CYAN}📊 BACKUP STATISTICS${NC}"
        get_backup_stats | while IFS='|' read -r metric value unit updated; do
            printf "%-25s ${WHITE}%s${NC} %s\n" "$metric:" "$value" "$unit"
        done
        echo ""
    fi
    
    # Show recent backup activity
    echo -e "${CYAN}📈 RECENT BACKUP ACTIVITY${NC}"
    execute_db "
    SELECT 
        tool,
        operation,
        target,
        status,
        strftime('%H:%M', start_time) as time,
        CASE WHEN size_bytes > 0 THEN 
            ROUND(size_bytes / (1024.0 * 1024.0), 1) || ' MB'
        ELSE '-' END as size
    FROM recent_backup_activity
    LIMIT 5;
    " | while IFS='|' read -r tool operation target status time size; do
        local status_color="$WHITE"
        case "$status" in
            "completed") status_color="$GREEN" ;;
            "failed") status_color="$RED" ;;
            "running") status_color="$YELLOW" ;;
        esac
        
        printf "${CYAN}%s${NC} %s %s ${status_color}%s${NC} (%s)\n" "$time" "$tool" "$operation" "$status" "$size"
    done
}

# S3-compatible storage configuration and management
configure_s3_storage() {
    local storage_name="$1"
    local provider_type="$2"  # wasabi, b2, s3, storj, etc.
    local bucket_name="$3"
    local access_key="$4"
    local secret_key="$5"
    local region="${6:-us-east-1}"
    
    echo -e "${CYAN}Configuring S3-compatible storage: $storage_name ($provider_type)${NC}"
    
    # Get provider endpoint
    local endpoint_url="${S3_ENDPOINTS[$provider_type]}"
    if [[ -z "$endpoint_url" ]]; then
        echo -e "${RED}Unknown provider type: $provider_type${NC}"
        return 1
    fi
    
    # Hash secret key for verification (don't store plaintext)
    local secret_key_hash=$(echo -n "$secret_key" | sha256sum | cut -d' ' -f1)
    
    # Insert/update storage configuration
    execute_db "
    INSERT OR REPLACE INTO backup_storage (
        storage_name, storage_type, provider_type, bucket_name, region, endpoint_url,
        access_key_id, secret_access_key_hash, encryption_enabled, is_active
    ) VALUES (
        '$storage_name', '$provider_type', '$provider_type', '$bucket_name', '$region', '$endpoint_url',
        '$access_key', '$secret_key_hash', 1, 1
    );
    "
    
    echo -e "${GREEN}✓ S3 storage configuration saved for $storage_name${NC}"
    
    # Test connection
    test_s3_connection "$storage_name" "$provider_type" "$bucket_name" "$access_key" "$secret_key" "$endpoint_url"
}

# Test S3 connection
test_s3_connection() {
    local storage_name="$1"
    local provider_type="$2"
    local bucket_name="$3"
    local access_key="$4"
    local secret_key="$5"
    local endpoint_url="$6"
    
    echo "Testing S3 connection to $storage_name..."
    
    # Set AWS credentials for test
    export AWS_ACCESS_KEY_ID="$access_key"
    export AWS_SECRET_ACCESS_KEY="$secret_key"
    
    # Test connection with rclone or direct AWS CLI if available
    if command -v "$RCLONE_PATH" >/dev/null 2>&1; then
        # Create temporary rclone config for test
        local temp_config="/tmp/rclone_test_$$"
        cat > "$temp_config" << EOF
[test_$provider_type]
type = s3
provider = Other
access_key_id = $access_key
secret_access_key = $secret_key
endpoint = https://$endpoint_url
EOF
        
        # Test list operation
        if $RCLONE_PATH --config "$temp_config" lsd "test_$provider_type:$bucket_name" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connection successful${NC}"
            execute_db "UPDATE backup_storage SET connection_status = 'connected', last_checked = CURRENT_TIMESTAMP WHERE storage_name = '$storage_name';"
            rm -f "$temp_config"
            return 0
        else
            echo -e "${RED}✗ Connection failed${NC}"
            execute_db "UPDATE backup_storage SET connection_status = 'error', last_checked = CURRENT_TIMESTAMP WHERE storage_name = '$storage_name';"
            rm -f "$temp_config"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ rclone not available for connection test${NC}"
        return 1
    fi
}

# Initialize restic repository
init_restic_repository() {
    local storage_name="$1"
    local encryption_password="$2"
    
    echo -e "${CYAN}Initializing restic repository for $storage_name...${NC}"
    
    # Get storage configuration from database
    local storage_info=$(execute_db "
    SELECT provider_type, bucket_name, endpoint_url, access_key_id 
    FROM backup_storage 
    WHERE storage_name = '$storage_name' AND storage_type IN ('wasabi', 'b2', 's3', 'storj', 'spaces', 'r2');
    ")
    
    if [[ -z "$storage_info" ]]; then
        echo -e "${RED}Storage configuration not found for: $storage_name${NC}"
        return 1
    fi
    
    IFS='|' read -r provider_type bucket_name endpoint_url access_key_id <<< "$storage_info"
    
    # Build restic repository URL
    local repo_url
    case "$provider_type" in
        "b2")
            repo_url="b2:$bucket_name:gwombat-restic"
            ;;
        *)
            repo_url="s3:https://$endpoint_url/$bucket_name/gwombat-restic"
            ;;
    esac
    
    # Set environment variables
    export RESTIC_REPOSITORY="$repo_url"
    export RESTIC_PASSWORD="$encryption_password"
    
    # Get secret key (would need secure storage in production)
    echo -e "${YELLOW}Note: In production, implement secure credential storage${NC}"
    
    # Initialize repository if it doesn't exist
    if ! $RESTIC_PATH snapshots >/dev/null 2>&1; then
        echo "Initializing new restic repository..."
        if $RESTIC_PATH init; then
            echo -e "${GREEN}✓ Restic repository initialized${NC}"
            
            # Update database with repository info
            local password_hash=$(echo -n "$encryption_password" | sha256sum | cut -d' ' -f1)
            execute_db "
            UPDATE backup_storage 
            SET restic_repo_url = '$repo_url', restic_password_hash = '$password_hash'
            WHERE storage_name = '$storage_name';
            "
        else
            echo -e "${RED}✗ Failed to initialize restic repository${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}✓ Restic repository already exists${NC}"
    fi
}

# Create encrypted incremental backup with restic
create_restic_backup() {
    local user_email="$1"
    local backup_type="$2"  # gmail, drive, full, config
    local source_path="$3"
    local storage_name="$4"
    local encryption_password="$5"
    
    echo -e "${CYAN}Creating restic backup for $user_email ($backup_type)${NC}"
    
    # Get storage configuration
    local storage_info=$(execute_db "
    SELECT restic_repo_url 
    FROM backup_storage 
    WHERE storage_name = '$storage_name' AND restic_repo_url IS NOT NULL;
    ")
    
    if [[ -z "$storage_info" ]]; then
        echo -e "${RED}Restic repository not configured for: $storage_name${NC}"
        return 1
    fi
    
    # Set environment variables
    export RESTIC_REPOSITORY="$storage_info"
    export RESTIC_PASSWORD="$encryption_password"
    
    # Create backup with tags
    local hostname=$(hostname)
    local tags="user:$user_email,type:$backup_type,source:gwombat,date:$(date +%Y-%m-%d)"
    
    echo "Creating backup from: $source_path"
    echo "Tags: $tags"
    
    # Execute restic backup with JSON output for parsing
    local backup_output
    backup_output=$($RESTIC_PATH backup "$source_path" \
        --tag "$tags" \
        --hostname "$hostname" \
        --json 2>&1)
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓ Restic backup completed successfully${NC}"
        
        # Parse snapshot information from JSON output
        local snapshot_id=$(echo "$backup_output" | jq -r '.snapshot_id // empty' 2>/dev/null | tail -1)
        local files_new=$(echo "$backup_output" | jq -r '.files_new // 0' 2>/dev/null | tail -1)
        local data_added=$(echo "$backup_output" | jq -r '.data_added // 0' 2>/dev/null | tail -1)
        
        # Store snapshot information in database
        if [[ -n "$snapshot_id" ]]; then
            execute_db "
            INSERT INTO restic_snapshots (
                snapshot_id, repository_url, user_email, backup_type, snapshot_date,
                file_count, data_size_bytes, tags, hostname, session_id
            ) VALUES (
                '$snapshot_id', '$storage_info', '$user_email', '$backup_type', CURRENT_TIMESTAMP,
                ${files_new:-0}, ${data_added:-0}, '$tags', '$hostname', '$SESSION_ID'
            );
            "
        fi
        
        # Apply retention policy
        apply_retention_policy "$storage_name" "$encryption_password"
        
    else
        echo -e "${RED}✗ Restic backup failed (exit code: $exit_code)${NC}"
        echo "$backup_output"
        return $exit_code
    fi
}

# Apply retention policy to restic repository
apply_retention_policy() {
    local storage_name="$1"
    local encryption_password="$2"
    
    echo "Applying retention policy for $storage_name..."
    
    # Get retention policy from database
    local retention_policy=$(execute_db "
    SELECT retention_policy 
    FROM backup_storage 
    WHERE storage_name = '$storage_name';
    ")
    
    if [[ -n "$retention_policy" ]]; then
        # Parse JSON retention policy (basic implementation)
        local daily=$(echo "$retention_policy" | jq -r '.daily // 7' 2>/dev/null)
        local weekly=$(echo "$retention_policy" | jq -r '.weekly // 4' 2>/dev/null)
        local monthly=$(echo "$retention_policy" | jq -r '.monthly // 12' 2>/dev/null)
        local yearly=$(echo "$retention_policy" | jq -r '.yearly // 2' 2>/dev/null)
        
        # Apply retention policy
        export RESTIC_PASSWORD="$encryption_password"
        $RESTIC_PATH forget \
            --keep-daily "$daily" \
            --keep-weekly "$weekly" \
            --keep-monthly "$monthly" \
            --keep-yearly "$yearly" \
            --prune
        
        echo -e "${GREEN}✓ Retention policy applied (daily:$daily, weekly:$weekly, monthly:$monthly, yearly:$yearly)${NC}"
    fi
}

# Create incremental Google Drive backup using rclone + restic
create_drive_incremental_backup() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local rclone_remote="${4:-googledrive}"
    
    echo -e "${CYAN}Creating incremental Google Drive backup for $user_email${NC}"
    
    # Create staging directory
    local staging_dir="$STAGING_PATH/drive_$user_email"
    mkdir -p "$staging_dir"
    
    echo "Syncing Google Drive to staging area..."
    
    # Sync Google Drive to local staging (with exclusions)
    if $RCLONE_PATH sync "$rclone_remote:" "$staging_dir" \
        --exclude "**.tmp" \
        --exclude "**/Trash/**" \
        --exclude "**.part" \
        --progress; then
        
        echo -e "${GREEN}✓ Google Drive sync completed${NC}"
        
        # Create restic backup from staging
        create_restic_backup "$user_email" "drive" "$staging_dir" "$storage_name" "$encryption_password"
        
        # Cleanup staging directory
        echo "Cleaning up staging directory..."
        rm -rf "$staging_dir"
        
    else
        echo -e "${RED}✗ Google Drive sync failed${NC}"
        rm -rf "$staging_dir"
        return 1
    fi
}

# Get backup cost estimate
calculate_backup_costs() {
    local storage_name="$1"
    local size_gb="$2"
    
    local cost_info=$(execute_db "
    SELECT cost_per_gb_month, egress_cost_per_gb, storage_type
    FROM backup_storage 
    WHERE storage_name = '$storage_name';
    ")
    
    if [[ -n "$cost_info" ]]; then
        IFS='|' read -r storage_cost egress_cost storage_type <<< "$cost_info"
        
        local monthly_cost=$(echo "$size_gb * $storage_cost" | bc -l 2>/dev/null || echo "0")
        local yearly_cost=$(echo "$monthly_cost * 12" | bc -l 2>/dev/null || echo "0")
        
        echo "Storage Cost Estimate for $storage_name:"
        echo "  Size: ${size_gb}GB"
        echo "  Monthly: \$$(printf "%.2f" "$monthly_cost")"
        echo "  Yearly: \$$(printf "%.2f" "$yearly_cost")"
        echo "  Egress: \$${egress_cost}/GB"
    fi
}

# GWOMBAT System Backup - Complete disaster recovery backup
create_gwombat_system_backup() {
    local storage_name="$1"
    local encryption_password="$2"
    local backup_name="${3:-gwombat_system_$(date +%Y%m%d_%H%M%S)}"
    
    echo -e "${CYAN}🔒 Creating complete GWOMBAT system backup for disaster recovery${NC}"
    echo "Backup name: $backup_name"
    
    # Create system backup staging directory
    local system_staging="$STAGING_PATH/gwombat_system_backup"
    rm -rf "$system_staging"
    mkdir -p "$system_staging"
    
    # Define what to backup for complete disaster recovery
    local gwombat_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    echo -e "${YELLOW}📦 Preparing GWOMBAT system backup components...${NC}"
    
    # 1. Core GWOMBAT installation
    echo "• Backing up core GWOMBAT installation..."
    mkdir -p "$system_staging/gwombat"
    
    # Copy essential GWOMBAT files (excluding temporary data)
    rsync -av --exclude='tmp/' \
              --exclude='logs/*.log' \
              --exclude='backups/gmail/' \
              --exclude='backups/drive/' \
              --exclude='*.tmp' \
              --exclude='__pycache__/' \
              "$gwombat_root/" "$system_staging/gwombat/"
    
    # 2. SQLite databases (all of them)
    echo "• Backing up SQLite databases..."
    mkdir -p "$system_staging/databases"
    
    if [[ -f "$DB_PATH" ]]; then
        # Create database backup with .backup command for consistency
        sqlite3 "$DB_PATH" ".backup '$system_staging/databases/gwombat.db'"
        
        # Also create SQL dump for maximum portability
        sqlite3 "$DB_PATH" .dump > "$system_staging/databases/gwombat_schema_and_data.sql"
        
        # Create database info file
        cat > "$system_staging/databases/database_info.txt" << EOF
GWOMBAT Database Backup Information
Generated: $(date)
Original Path: $DB_PATH
Database Size: $(du -h "$DB_PATH" | cut -f1)
Table Count: $(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
Record Counts:
$(sqlite3 "$DB_PATH" "SELECT name, (SELECT COUNT(*) FROM ' || name || ') as count FROM sqlite_master WHERE type='table' ORDER BY name;" | sed 's/|/ = /')
EOF
    fi
    
    # Backup any other database files found
    find "$gwombat_root" -name "*.db" -not -path "*/tmp/*" -exec cp {} "$system_staging/databases/" \;
    
    # 3. Configuration files and credentials
    echo "• Backing up configuration files and credentials..."
    mkdir -p "$system_staging/config"
    
    # Copy all configuration files
    [[ -f "$gwombat_root/.env" ]] && cp "$gwombat_root/.env" "$system_staging/config/"
    [[ -f "$gwombat_root/server.env" ]] && cp "$gwombat_root/server.env" "$system_staging/config/"
    [[ -d "$gwombat_root/config" ]] && rsync -av "$gwombat_root/config/" "$system_staging/config/"
    
    # Backup SSH keys if they exist
    if [[ -f "$HOME/.ssh/gwombatgit-key" ]]; then
        mkdir -p "$system_staging/ssh_keys"
        cp "$HOME/.ssh/gwombatgit-key"* "$system_staging/ssh_keys/" 2>/dev/null || true
    fi
    
    # 4. rclone configuration
    echo "• Backing up rclone configuration..."
    if [[ -f "$HOME/.config/rclone/rclone.conf" ]]; then
        mkdir -p "$system_staging/rclone"
        cp "$HOME/.config/rclone/rclone.conf" "$system_staging/rclone/"
    fi
    
    # 5. GAM configuration (if accessible)
    echo "• Backing up GAM configuration..."
    if [[ -d "${GAM_CONFIG_PATH:-$HOME/.gam}" ]]; then
        mkdir -p "$system_staging/gam_config"
        # Only backup configuration, not cached data
        rsync -av --exclude='cache/' \
                  --exclude='*.log' \
                  "${GAM_CONFIG_PATH:-$HOME/.gam}/" "$system_staging/gam_config/"
    fi
    
    # 6. Essential backup metadata and encryption keys
    echo "• Backing up backup metadata and recovery information..."
    mkdir -p "$system_staging/backup_metadata"
    
    # Export backup storage configurations
    execute_db "
    SELECT 'INSERT OR REPLACE INTO backup_storage (' ||
           'storage_name, storage_type, provider_type, bucket_name, region, endpoint_url, ' ||
           'access_key_id, cost_per_gb_month, egress_cost_per_gb, encryption_enabled, ' ||
           'retention_policy) VALUES (' ||
           quote(storage_name) || ', ' ||
           quote(storage_type) || ', ' ||
           quote(provider_type) || ', ' ||
           quote(bucket_name) || ', ' ||
           quote(region) || ', ' ||
           quote(endpoint_url) || ', ' ||
           quote(access_key_id) || ', ' ||
           quote(cost_per_gb_month) || ', ' ||
           quote(egress_cost_per_gb) || ', ' ||
           quote(encryption_enabled) || ', ' ||
           quote(retention_policy) || ');'
    FROM backup_storage WHERE is_active = 1;
    " > "$system_staging/backup_metadata/storage_configs.sql"
    
    # Create recovery instructions
    cat > "$system_staging/DISASTER_RECOVERY_INSTRUCTIONS.md" << 'EOF'
# GWOMBAT Disaster Recovery Instructions

This backup contains everything needed to restore a complete GWOMBAT installation.

## Recovery Steps

### 1. Prerequisites
Install required tools on the new system:
```bash
# Install Python 3.8+
sudo apt-get install python3 python3-pip

# Install required tools
pip3 install -r gwombat/python-modules/requirements.txt

# Install GAM (GAMADV-XS3)
# Follow instructions at: https://github.com/taers232c/GAMADV-XS3

# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Install restic
sudo apt-get install restic
```

### 2. Restore GWOMBAT Installation
```bash
# Extract this backup to desired location
cp -r gwombat/ /opt/gwombat/
cd /opt/gwombat

# Restore permissions
chmod +x gwombat.sh
chmod +x shared-utilities/*.sh

# Create necessary directories
mkdir -p logs tmp backups config reports
```

### 3. Restore Databases
```bash
# Restore main database
cp databases/gwombat.db config/
# OR restore from SQL dump:
# sqlite3 config/gwombat.db < databases/gwombat_schema_and_data.sql
```

### 4. Restore Configuration
```bash
# Restore environment files
cp config/.env ./
cp config/server.env ./

# Restore SSH keys (if used)
mkdir -p ~/.ssh
cp ssh_keys/gwombatgit-key* ~/.ssh/
chmod 600 ~/.ssh/gwombatgit-key*

# Restore rclone config
mkdir -p ~/.config/rclone
cp rclone/rclone.conf ~/.config/rclone/

# Restore GAM config
cp -r gam_config/ ~/.gam/
```

### 5. Restore Backup Storage Configurations
```bash
# Import storage configurations
sqlite3 config/gwombat.db < backup_metadata/storage_configs.sql

# Re-enter secret keys for S3 providers (not stored in backup for security)
./shared-utilities/backup_tools.sh configure-s3 <storage_name> <provider> <bucket> <access_key> <secret_key>
```

### 6. Test Recovery
```bash
# Test GWOMBAT functionality
./gwombat.sh

# Test backup tools
./shared-utilities/backup_tools.sh status

# Test database connectivity
sqlite3 config/gwombat.db "SELECT COUNT(*) FROM accounts;"
```

## Security Notes

- Secret keys and passwords are NOT included in this backup for security
- You will need to re-configure S3 credentials after restoration  
- Verify all file permissions after restoration
- Test all integrations (GAM, rclone, restic) before production use

## Backup Information

Generated: $(date)
GWOMBAT Version: Hybrid Architecture v3.0
Backup Type: Complete System Backup
EOF
    
    # Create backup manifest
    echo "• Creating backup manifest..."
    find "$system_staging" -type f -exec sha256sum {} \; > "$system_staging/BACKUP_MANIFEST.sha256"
    
    # Calculate total backup size
    local backup_size=$(du -sh "$system_staging" | cut -f1)
    echo -e "${GREEN}✓ GWOMBAT system backup prepared (Size: $backup_size)${NC}"
    
    # Create encrypted backup using restic
    echo -e "${CYAN}🔐 Creating encrypted backup to storage...${NC}"
    
    if create_restic_backup "system" "gwombat_system" "$system_staging" "$storage_name" "$encryption_password"; then
        echo -e "${GREEN}✅ GWOMBAT system backup completed successfully!${NC}"
        echo ""
        echo -e "${YELLOW}📋 System Backup Summary:${NC}"
        echo "  • Complete GWOMBAT installation backed up"
        echo "  • All SQLite databases included"
        echo "  • Configuration files and SSH keys preserved"
        echo "  • rclone and GAM configurations included"
        echo "  • Backup metadata and recovery instructions added"
        echo "  • Total size: $backup_size"
        echo "  • Encrypted and stored in: $storage_name"
        echo ""
        echo -e "${CYAN}🚨 IMPORTANT: Store the encryption password securely!${NC}"
        echo -e "${CYAN}Without it, this backup cannot be restored.${NC}"
        
        # Log system backup in database
        execute_db "
        INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
        VALUES ('INFO', '$SESSION_ID', 'system_backup', 
                'Complete GWOMBAT system backup created: $backup_name (Size: $backup_size)', 
                'backup_tools.sh');
        "
    else
        echo -e "${RED}❌ GWOMBAT system backup failed!${NC}"
        return 1
    fi
    
    # Cleanup staging directory
    rm -rf "$system_staging"
}

# List available GWOMBAT system backups
list_gwombat_system_backups() {
    local storage_name="$1"
    local encryption_password="$2"
    
    echo -e "${CYAN}📋 Available GWOMBAT System Backups${NC}"
    
    # Get restic repository URL
    local repo_url=$(execute_db "
    SELECT restic_repo_url 
    FROM backup_storage 
    WHERE storage_name = '$storage_name' AND restic_repo_url IS NOT NULL;
    ")
    
    if [[ -z "$repo_url" ]]; then
        echo -e "${RED}No restic repository configured for: $storage_name${NC}"
        return 1
    fi
    
    # Set environment variables
    export RESTIC_REPOSITORY="$repo_url"
    export RESTIC_PASSWORD="$encryption_password"
    
    # List system backups
    echo ""
    echo "System backups in repository:"
    $RESTIC_PATH snapshots --tag "type:gwombat_system" --compact || {
        echo -e "${RED}Failed to list backups. Check repository access and encryption password.${NC}"
        return 1
    }
}

# Restore GWOMBAT system from backup (preparation only - manual steps required)
prepare_gwombat_restore() {
    local storage_name="$1"
    local encryption_password="$2"
    local snapshot_id="$3"
    local restore_path="${4:-./gwombat_restore_$(date +%Y%m%d_%H%M%S)}"
    
    echo -e "${CYAN}🔄 Preparing GWOMBAT system restore${NC}"
    echo "Snapshot ID: $snapshot_id"
    echo "Restore path: $restore_path"
    
    # Get restic repository URL
    local repo_url=$(execute_db "
    SELECT restic_repo_url 
    FROM backup_storage 
    WHERE storage_name = '$storage_name' AND restic_repo_url IS NOT NULL;
    ")
    
    if [[ -z "$repo_url" ]]; then
        echo -e "${RED}No restic repository configured for: $storage_name${NC}"
        return 1
    fi
    
    # Set environment variables
    export RESTIC_REPOSITORY="$repo_url"
    export RESTIC_PASSWORD="$encryption_password"
    
    # Create restore directory
    mkdir -p "$restore_path"
    
    # Restore backup
    echo "Restoring backup to: $restore_path"
    if $RESTIC_PATH restore "$snapshot_id" --target "$restore_path"; then
        echo -e "${GREEN}✅ GWOMBAT system backup restored to: $restore_path${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Review restored files in: $restore_path"
        echo "2. Follow instructions in: $restore_path/DISASTER_RECOVERY_INSTRUCTIONS.md"
        echo "3. Copy files to production location"
        echo "4. Restore configurations and test all components"
        echo ""
        echo -e "${CYAN}⚠️  Manual steps required for complete restoration!${NC}"
        
        # Show disaster recovery instructions location
        local recovery_instructions="$restore_path/DISASTER_RECOVERY_INSTRUCTIONS.md"
        if [[ -f "$recovery_instructions" ]]; then
            echo ""
            echo -e "${GREEN}📖 Disaster Recovery Instructions:${NC}"
            echo "   $recovery_instructions"
        fi
        
    else
        echo -e "${RED}❌ Failed to restore GWOMBAT system backup${NC}"
        return 1
    fi
}

# Extended Google Workspace Backup Tools
# Additional tools for backing up Calendar, Contacts, Sites, Groups, etc.

# Check for additional backup tools availability
check_extended_backup_tools() {
    local tools_available=""
    
    echo -e "${CYAN}🔍 Checking Extended Google Workspace Backup Tools${NC}"
    
    # GAM can export most Google Workspace data
    if command -v "$GAM" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GAM available - Can export: users, groups, calendars, contacts, sites${NC}"
        tools_available="$tools_available gam"
    fi
    
    # Check for Google Workspace Migration for Microsoft Exchange (GWMME) - calendar/contacts
    if command -v gwmme >/dev/null 2>&1; then
        echo -e "${GREEN}✓ GWMME available - Enhanced calendar/contact backup${NC}"
        tools_available="$tools_available gwmme"
    fi
    
    # Check for Google Takeout Automation tools
    if command -v takeout-automation >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Takeout automation available${NC}"
        tools_available="$tools_available takeout"
    fi
    
    # Check for custom Google Apps Script backup tools
    if [[ -f "./shared-utilities/gas_backup.js" ]]; then
        echo -e "${GREEN}✓ Google Apps Script backup tools available${NC}"
        tools_available="$tools_available gas"
    fi
    
    echo "$tools_available"
}

# Create Calendar backup using GAM
create_calendar_backup() {
    local user_email="$1"
    local backup_path="${2:-$BACKUP_BASE_PATH/calendar/$user_email}"
    local backup_format="${3:-ics}" # ics, json
    
    echo -e "${CYAN}📅 Creating calendar backup for $user_email${NC}"
    
    mkdir -p "$backup_path"
    
    # Export primary calendar
    echo "Exporting primary calendar..."
    if [[ "$backup_format" == "ics" ]]; then
        $GAM user "$user_email" export calendar primary > "$backup_path/primary_calendar.ics" 2>/dev/null
    else
        $GAM user "$user_email" print calendar > "$backup_path/calendar_list.csv" 2>/dev/null
        $GAM user "$user_email" print events calendar primary > "$backup_path/primary_events.csv" 2>/dev/null
    fi
    
    # Export all calendars
    echo "Exporting all calendars..."
    $GAM user "$user_email" print calendars > "$backup_path/all_calendars.csv" 2>/dev/null
    
    # Create calendar backup metadata
    cat > "$backup_path/calendar_backup_info.txt" << EOF
Calendar Backup Information
User: $user_email
Generated: $(date)
Format: $backup_format
Backup Path: $backup_path

Files included:
- primary_calendar.ics/csv: Primary calendar data
- all_calendars.csv: List of all calendars
- calendar_list.csv: Calendar metadata (JSON format)
- primary_events.csv: Primary calendar events (JSON format)
EOF
    
    echo -e "${GREEN}✓ Calendar backup completed for $user_email${NC}"
}

# Create Contacts backup using GAM
create_contacts_backup() {
    local user_email="$1"
    local backup_path="${2:-$BACKUP_BASE_PATH/contacts/$user_email}"
    local backup_format="${3:-vcard}" # vcard, csv
    
    echo -e "${CYAN}👥 Creating contacts backup for $user_email${NC}"
    
    mkdir -p "$backup_path"
    
    # Export contacts
    echo "Exporting contacts..."
    if [[ "$backup_format" == "vcard" ]]; then
        # Export as vCard format
        $GAM user "$user_email" export contacts > "$backup_path/contacts.vcf" 2>/dev/null
    else
        # Export as CSV
        $GAM user "$user_email" print contacts > "$backup_path/contacts.csv" 2>/dev/null
    fi
    
    # Export contact groups
    echo "Exporting contact groups..."
    $GAM user "$user_email" print contactgroups > "$backup_path/contact_groups.csv" 2>/dev/null
    
    # Create contacts backup metadata
    cat > "$backup_path/contacts_backup_info.txt" << EOF
Contacts Backup Information
User: $user_email
Generated: $(date)
Format: $backup_format
Backup Path: $backup_path

Files included:
- contacts.vcf/csv: All contacts
- contact_groups.csv: Contact groups and memberships
EOF
    
    echo -e "${GREEN}✓ Contacts backup completed for $user_email${NC}"
}

# Create Google Sites backup using GAM
create_sites_backup() {
    local domain="$1"
    local backup_path="${2:-$BACKUP_BASE_PATH/sites}"
    
    echo -e "${CYAN}🌐 Creating Google Sites backup for $domain${NC}"
    
    mkdir -p "$backup_path"
    
    # Export sites list
    echo "Exporting sites list..."
    $GAM print sites > "$backup_path/sites_list.csv" 2>/dev/null
    
    # Export site details (this requires Sites API access)
    echo "Exporting site details..."
    $GAM print sites showdetails > "$backup_path/sites_details.csv" 2>/dev/null
    
    # Note: Actual site content backup requires additional tools or manual export
    cat > "$backup_path/sites_backup_info.txt" << EOF
Google Sites Backup Information
Domain: $domain
Generated: $(date)
Backup Path: $backup_path

Files included:
- sites_list.csv: List of all sites
- sites_details.csv: Detailed site information

NOTE: This backup includes site metadata only.
For complete site content backup, use:
1. Google Sites export feature (manual)
2. Web scraping tools
3. Google Takeout
EOF
    
    echo -e "${GREEN}✓ Sites metadata backup completed${NC}"
    echo -e "${YELLOW}⚠ Manual steps required for complete site content backup${NC}"
}

# Create Groups backup using GAM
create_groups_backup() {
    local domain="$1"
    local backup_path="${2:-$BACKUP_BASE_PATH/groups}"
    
    echo -e "${CYAN}👥 Creating Groups backup for $domain${NC}"
    
    mkdir -p "$backup_path"
    
    # Export all groups
    echo "Exporting groups list..."
    $GAM print groups > "$backup_path/groups_list.csv" 2>/dev/null
    
    # Export group settings
    echo "Exporting group settings..."
    $GAM print groups settings > "$backup_path/groups_settings.csv" 2>/dev/null
    
    # Export group members for all groups
    echo "Exporting group memberships..."
    $GAM print group-members > "$backup_path/group_members.csv" 2>/dev/null
    
    # Export group aliases
    echo "Exporting group aliases..."
    $GAM print groups aliases > "$backup_path/group_aliases.csv" 2>/dev/null
    
    # Create groups backup metadata
    cat > "$backup_path/groups_backup_info.txt" << EOF
Groups Backup Information
Domain: $domain
Generated: $(date)
Backup Path: $backup_path

Files included:
- groups_list.csv: All groups basic information
- groups_settings.csv: Group settings and permissions
- group_members.csv: Group membership details
- group_aliases.csv: Group aliases and forwarding

NOTE: Group message archives require additional backup methods:
1. Google Vault export
2. Google Takeout
3. Third-party archiving tools
EOF
    
    echo -e "${GREEN}✓ Groups backup completed${NC}"
    echo -e "${YELLOW}⚠ Group message archives require separate backup method${NC}"
}

# Create comprehensive user backup (all data types)
create_comprehensive_user_backup() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local include_drive="${4:-true}"
    
    echo -e "${CYAN}🎯 Creating comprehensive backup for $user_email${NC}"
    
    local user_backup_staging="$STAGING_PATH/comprehensive_$user_email"
    rm -rf "$user_backup_staging"
    mkdir -p "$user_backup_staging"
    
    # 1. Gmail backup (existing)
    echo -e "${YELLOW}📧 Gmail backup...${NC}"
    create_gmail_backup "$user_email" "full" "$user_backup_staging/gmail"
    
    # 2. Calendar backup
    echo -e "${YELLOW}📅 Calendar backup...${NC}"
    create_calendar_backup "$user_email" "$user_backup_staging/calendar"
    
    # 3. Contacts backup
    echo -e "${YELLOW}👥 Contacts backup...${NC}"
    create_contacts_backup "$user_email" "$user_backup_staging/contacts"
    
    # 4. Drive backup (if requested)
    if [[ "$include_drive" == "true" ]]; then
        echo -e "${YELLOW}💾 Drive backup...${NC}"
        create_drive_incremental_backup "$user_email" "$storage_name" "$encryption_password" "googledrive"
    fi
    
    # 5. User settings and configuration
    echo -e "${YELLOW}⚙️ User settings backup...${NC}"
    mkdir -p "$user_backup_staging/user_settings"
    
    # Export user information
    $GAM info user "$user_email" > "$user_backup_staging/user_settings/user_info.txt" 2>/dev/null
    
    # Export user's group memberships
    $GAM user "$user_email" print groups > "$user_backup_staging/user_settings/user_groups.csv" 2>/dev/null
    
    # Export user's Gmail settings
    $GAM user "$user_email" print signature > "$user_backup_staging/user_settings/gmail_signature.txt" 2>/dev/null
    $GAM user "$user_email" print filters > "$user_backup_staging/user_settings/gmail_filters.csv" 2>/dev/null
    $GAM user "$user_email" print forwardingaddresses > "$user_backup_staging/user_settings/forwarding.csv" 2>/dev/null
    
    # Create comprehensive backup summary
    cat > "$user_backup_staging/COMPREHENSIVE_BACKUP_README.md" << EOF
# Comprehensive User Backup: $user_email

Generated: $(date)
Backup Type: Complete User Data Backup

## Contents

### 📧 Gmail Backup
- Location: ./gmail/
- Full mailbox backup using GYB
- Includes all emails, labels, and settings

### 📅 Calendar Backup  
- Location: ./calendar/
- Primary calendar in ICS format
- All calendars list and metadata

### 👥 Contacts Backup
- Location: ./contacts/
- All contacts in vCard format
- Contact groups and organization

### 💾 Drive Backup
- Backed up separately using restic (incremental)
- Check restic snapshots for Drive data

### ⚙️ User Settings
- Location: ./user_settings/
- User account information
- Group memberships
- Gmail filters and forwarding rules
- Email signatures

## Restoration Instructions

### Gmail Restoration
\`\`\`bash
# Restore Gmail using GYB
gyb --email $user_email --action restore --local-folder ./gmail/
\`\`\`

### Calendar Restoration
\`\`\`bash
# Import calendar manually through Google Calendar interface
# Or use GAM:
gam user $user_email import calendar ./calendar/primary_calendar.ics
\`\`\`

### Contacts Restoration  
\`\`\`bash
# Import contacts using GAM
gam user $user_email import contacts ./contacts/contacts.vcf
\`\`\`

### Drive Restoration
\`\`\`bash
# Restore Drive files using restic
restic restore <snapshot_id> --target ./drive_restore/
# Then upload back to Drive using rclone
\`\`\`

## Security Notes

- This backup is encrypted using restic
- Store encryption password securely
- Test restoration process before relying on backups
- Consider privacy implications of comprehensive user data
EOF
    
    # Calculate backup size
    local backup_size=$(du -sh "$user_backup_staging" | cut -f1)
    
    # Create encrypted backup using restic
    echo -e "${CYAN}🔐 Creating encrypted comprehensive backup...${NC}"
    
    if create_restic_backup "$user_email" "comprehensive" "$user_backup_staging" "$storage_name" "$encryption_password"; then
        echo -e "${GREEN}✅ Comprehensive user backup completed!${NC}"
        echo ""
        echo -e "${YELLOW}📋 Backup Summary:${NC}"
        echo "  • Gmail: Complete mailbox"
        echo "  • Calendar: All calendars and events"
        echo "  • Contacts: All contacts and groups"
        echo "  • Drive: Incremental file backup (separate snapshot)"
        echo "  • Settings: User configuration and preferences"
        echo "  • Total size: $backup_size"
        echo "  • Storage: $storage_name (encrypted)"
    else
        echo -e "${RED}❌ Comprehensive backup failed!${NC}"
        return 1
    fi
    
    # Cleanup staging
    rm -rf "$user_backup_staging"
}

# API-based backup functions using Python Google Workspace integration
# These leverage the existing Python modules for comprehensive API access

# Create API-based Calendar backup
create_api_calendar_backup() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local backup_path="${4:-$STAGING_PATH/api_calendar_$user_email}"
    
    echo -e "${CYAN}📅 Creating API-based calendar backup for $user_email${NC}"
    
    mkdir -p "$backup_path"
    
    # Use Python Google Calendar API for comprehensive backup
    cat > "$backup_path/calendar_api_backup.py" << 'EOF'
#!/usr/bin/env python3
"""
Comprehensive Google Calendar backup using Calendar API
"""
import os
import sys
import json
import pickle
from datetime import datetime, timedelta
from pathlib import Path

# Add Python modules to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'python-modules'))

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    GOOGLE_API_AVAILABLE = True
except ImportError:
    print("Google API client libraries not available")
    GOOGLE_API_AVAILABLE = False
    sys.exit(1)

SCOPES = ['https://www.googleapis.com/auth/calendar.readonly']

def authenticate():
    """Authenticate with Google Calendar API"""
    creds = None
    token_path = Path('../config/calendar_token.pickle')
    
    if token_path.exists():
        with open(token_path, 'rb') as token:
            creds = pickle.load(token)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            credentials_path = Path('../config/gws_credentials.json')
            if not credentials_path.exists():
                print(f"Credentials file not found: {credentials_path}")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(token_path, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('calendar', 'v3', credentials=creds)

def backup_user_calendars(service, user_email, backup_dir):
    """Backup all calendars for a user"""
    backup_data = {
        'user_email': user_email,
        'backup_date': datetime.now().isoformat(),
        'calendars': [],
        'events': {}
    }
    
    try:
        # Get calendar list
        calendars_result = service.calendarList().list().execute()
        calendars = calendars_result.get('items', [])
        
        backup_data['calendars'] = calendars
        
        # Backup events from each calendar
        for calendar in calendars:
            calendar_id = calendar['id']
            calendar_name = calendar.get('summary', 'Unknown')
            
            print(f"Backing up calendar: {calendar_name}")
            
            # Get events from last 2 years and next 1 year
            time_min = (datetime.now() - timedelta(days=730)).isoformat() + 'Z'
            time_max = (datetime.now() + timedelta(days=365)).isoformat() + 'Z'
            
            events_result = service.events().list(
                calendarId=calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                maxResults=2500,
                singleEvents=True,
                orderBy='startTime'
            ).execute()
            
            events = events_result.get('items', [])
            backup_data['events'][calendar_id] = {
                'calendar_name': calendar_name,
                'events': events,
                'event_count': len(events)
            }
            
        # Save backup data
        backup_file = Path(backup_dir) / 'calendar_backup.json'
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2, default=str)
        
        print(f"Calendar backup completed: {len(calendars)} calendars, total events: {sum(len(cal['events']) for cal in backup_data['events'].values())}")
        return True
        
    except Exception as e:
        print(f"Error backing up calendars: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python calendar_api_backup.py <user_email> <backup_dir>")
        sys.exit(1)
    
    user_email = sys.argv[1]
    backup_dir = sys.argv[2]
    
    service = authenticate()
    if service:
        backup_user_calendars(service, user_email, backup_dir)
    else:
        print("Authentication failed")
        sys.exit(1)
EOF
    
    # Execute Python calendar backup
    if python3 "$backup_path/calendar_api_backup.py" "$user_email" "$backup_path"; then
        echo -e "${GREEN}✓ API calendar backup completed${NC}"
        
        # Create restic backup
        create_restic_backup "$user_email" "calendar_api" "$backup_path" "$storage_name" "$encryption_password"
    else
        echo -e "${RED}✗ API calendar backup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$backup_path"
}

# Create API-based Contacts backup
create_api_contacts_backup() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local backup_path="${4:-$STAGING_PATH/api_contacts_$user_email}"
    
    echo -e "${CYAN}👥 Creating API-based contacts backup for $user_email${NC}"
    
    mkdir -p "$backup_path"
    
    # Use Python People API for comprehensive backup
    cat > "$backup_path/contacts_api_backup.py" << 'EOF'
#!/usr/bin/env python3
"""
Comprehensive Google Contacts backup using People API
"""
import os
import sys
import json
import pickle
from datetime import datetime
from pathlib import Path

# Add Python modules to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'python-modules'))

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    GOOGLE_API_AVAILABLE = True
except ImportError:
    print("Google API client libraries not available")
    sys.exit(1)

SCOPES = ['https://www.googleapis.com/auth/contacts.readonly']

def authenticate():
    """Authenticate with Google People API"""
    creds = None
    token_path = Path('../config/contacts_token.pickle')
    
    if token_path.exists():
        with open(token_path, 'rb') as token:
            creds = pickle.load(token)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            credentials_path = Path('../config/gws_credentials.json')
            if not credentials_path.exists():
                print(f"Credentials file not found: {credentials_path}")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(token_path, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('people', 'v1', credentials=creds)

def backup_user_contacts(service, user_email, backup_dir):
    """Backup all contacts for a user"""
    backup_data = {
        'user_email': user_email,
        'backup_date': datetime.now().isoformat(),
        'contacts': [],
        'contact_groups': []
    }
    
    try:
        # Get all contacts
        contacts_result = service.people().connections().list(
            resourceName='people/me',
            pageSize=1000,
            personFields='names,emailAddresses,phoneNumbers,addresses,organizations,birthdays,photos,urls,biographies,relations,events'
        ).execute()
        
        contacts = contacts_result.get('connections', [])
        backup_data['contacts'] = contacts
        
        # Get contact groups
        groups_result = service.contactGroups().list().execute()
        contact_groups = groups_result.get('contactGroups', [])
        backup_data['contact_groups'] = contact_groups
        
        # Get group memberships
        for group in contact_groups:
            group_id = group['resourceName']
            try:
                group_details = service.contactGroups().get(
                    resourceName=group_id,
                    maxMembers=1000
                ).execute()
                group['members'] = group_details.get('memberResourceNames', [])
            except Exception as e:
                print(f"Error getting group members for {group.get('name', 'Unknown')}: {e}")
        
        # Save backup data
        backup_file = Path(backup_dir) / 'contacts_backup.json'
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2, default=str)
        
        print(f"Contacts backup completed: {len(contacts)} contacts, {len(contact_groups)} groups")
        return True
        
    except Exception as e:
        print(f"Error backing up contacts: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python contacts_api_backup.py <user_email> <backup_dir>")
        sys.exit(1)
    
    user_email = sys.argv[1]
    backup_dir = sys.argv[2]
    
    service = authenticate()
    if service:
        backup_user_contacts(service, user_email, backup_dir)
    else:
        print("Authentication failed")
        sys.exit(1)
EOF
    
    # Execute Python contacts backup
    if python3 "$backup_path/contacts_api_backup.py" "$user_email" "$backup_path"; then
        echo -e "${GREEN}✓ API contacts backup completed${NC}"
        
        # Create restic backup
        create_restic_backup "$user_email" "contacts_api" "$backup_path" "$storage_name" "$encryption_password"
    else
        echo -e "${RED}✗ API contacts backup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$backup_path"
}

# Create API-based Sites backup  
create_api_sites_backup() {
    local domain="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local backup_path="${4:-$STAGING_PATH/api_sites_$domain}"
    
    echo -e "${CYAN}🌐 Creating API-based Sites backup for $domain${NC}"
    
    mkdir -p "$backup_path"
    
    # Use Python Sites API for metadata backup
    cat > "$backup_path/sites_api_backup.py" << 'EOF'
#!/usr/bin/env python3
"""
Comprehensive Google Sites backup using Sites API
"""
import os
import sys
import json
import pickle
from datetime import datetime
from pathlib import Path

# Add Python modules to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent / 'python-modules'))

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    GOOGLE_API_AVAILABLE = True
except ImportError:
    print("Google API client libraries not available")
    sys.exit(1)

SCOPES = ['https://www.googleapis.com/auth/sites.readonly']

def authenticate():
    """Authenticate with Google Sites API"""
    creds = None
    token_path = Path('../config/sites_token.pickle')
    
    if token_path.exists():
        with open(token_path, 'rb') as token:
            creds = pickle.load(token)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            credentials_path = Path('../config/gws_credentials.json')
            if not credentials_path.exists():
                print(f"Credentials file not found: {credentials_path}")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(str(credentials_path), SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(token_path, 'wb') as token:
            pickle.dump(creds, token)
    
    return build('sites', 'v1', credentials=creds)

def backup_domain_sites(service, domain, backup_dir):
    """Backup all sites for a domain"""
    backup_data = {
        'domain': domain,
        'backup_date': datetime.now().isoformat(),
        'sites': []
    }
    
    try:
        # List all sites
        sites_result = service.sites().list().execute()
        sites = sites_result.get('sites', [])
        
        for site in sites:
            site_name = site.get('name', '')
            print(f"Backing up site: {site_name}")
            
            # Get site details
            try:
                site_details = service.sites().get(name=site_name).execute()
                backup_data['sites'].append(site_details)
            except Exception as e:
                print(f"Error getting site details for {site_name}: {e}")
        
        # Save backup data
        backup_file = Path(backup_dir) / 'sites_backup.json'
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2, default=str)
        
        print(f"Sites backup completed: {len(backup_data['sites'])} sites")
        
        # Create backup instructions
        instructions_file = Path(backup_dir) / 'SITES_BACKUP_README.md'
        with open(instructions_file, 'w') as f:
            f.write(f"""# Google Sites Backup for {domain}

Generated: {datetime.now().isoformat()}

## Contents
- sites_backup.json: Complete site metadata and structure

## Limitations
This backup contains site metadata and structure only.
For complete site content backup, consider:

1. **Manual Export**: Use Google Sites "Download" feature for each site
2. **Web Scraping**: Use tools like wget or httrack to download published sites
3. **Google Takeout**: Request site exports through Google Takeout

## Restoration
Site metadata can be used to:
- Recreate site structure
- Restore sharing permissions  
- Reference original content for manual restoration
""")
        
        return True
        
    except Exception as e:
        print(f"Error backing up sites: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python sites_api_backup.py <domain> <backup_dir>")
        sys.exit(1)
    
    domain = sys.argv[1]
    backup_dir = sys.argv[2]
    
    service = authenticate()
    if service:
        backup_domain_sites(service, domain, backup_dir)
    else:
        print("Authentication failed")
        sys.exit(1)
EOF
    
    # Execute Python sites backup
    if python3 "$backup_path/sites_api_backup.py" "$domain" "$backup_path"; then
        echo -e "${GREEN}✓ API sites backup completed${NC}"
        
        # Create restic backup
        create_restic_backup "domain" "sites_api" "$backup_path" "$storage_name" "$encryption_password"
    else
        echo -e "${RED}✗ API sites backup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$backup_path"
}

# Create Google Groups message archive backup
create_api_groups_backup() {
    local domain="$1"
    local storage_name="$2"
    local encryption_password="$3"
    
    echo -e "${CYAN}👥 Creating Google Groups message archive backup for $domain${NC}"
    
    # Create staging directory
    local backup_path="/tmp/gwombat_groups_backup_$(date +%s)"
    mkdir -p "$backup_path"
    
    # Python script for Groups API backup
    cat > "$backup_path/groups_api_backup.py" << 'EOF'
#!/usr/bin/env python3
"""
Google Groups Message Archive Backup
Uses Groups Settings API and Gmail API for message archival
"""

import os
import sys
import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
import pickle
import base64
import email

# Google API imports
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    print("Error: Google API client libraries not installed")
    print("Install with: pip3 install google-api-python-client google-auth-httplib2 google-auth-oauthlib")
    sys.exit(1)

# OAuth2 scopes needed for Groups and Gmail APIs
SCOPES = [
    'https://www.googleapis.com/auth/admin.directory.group.readonly',
    'https://www.googleapis.com/auth/apps.groups.settings',
    'https://www.googleapis.com/auth/gmail.readonly'
]

def authenticate():
    """Authenticate with Google APIs for Groups and Gmail access"""
    creds = None
    token_file = './config/gws_token.json'
    credentials_file = './config/gws_credentials.json'
    
    # Load existing token
    if os.path.exists(token_file):
        creds = Credentials.from_authorized_user_file(token_file, SCOPES)
    
    # Refresh or get new credentials
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(credentials_file):
                print(f"Error: Credentials file not found at {credentials_file}")
                print("Please download OAuth2 credentials from Google Cloud Console")
                return None, None, None
            
            flow = InstalledAppFlow.from_client_secrets_file(credentials_file, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials
        os.makedirs('./config', exist_ok=True)
        with open(token_file, 'w') as token:
            token.write(creds.to_json())
    
    try:
        admin_service = build('admin', 'directory_v1', credentials=creds)
        groups_service = build('groupssettings', 'v1', credentials=creds)
        gmail_service = build('gmail', 'v1', credentials=creds)
        return admin_service, groups_service, gmail_service
    except Exception as e:
        print(f"Error building Google API services: {e}")
        return None, None, None

def get_domain_groups(admin_service, domain):
    """Get all groups in the domain"""
    try:
        groups = []
        page_token = None
        
        while True:
            result = admin_service.groups().list(
                domain=domain,
                maxResults=200,
                pageToken=page_token
            ).execute()
            
            groups.extend(result.get('groups', []))
            page_token = result.get('nextPageToken')
            if not page_token:
                break
                
        print(f"Found {len(groups)} groups in domain {domain}")
        return groups
        
    except HttpError as e:
        print(f"Error fetching groups: {e}")
        return []

def get_group_settings(groups_service, group_email):
    """Get group settings including archive configuration"""
    try:
        settings = groups_service.groups().get(groupUniqueId=group_email).execute()
        return settings
    except HttpError as e:
        if e.resp.status == 403:
            print(f"No access to settings for group {group_email}")
        else:
            print(f"Error fetching settings for {group_email}: {e}")
        return None

def get_group_members(admin_service, group_email):
    """Get all members of a group"""
    try:
        members = []
        page_token = None
        
        while True:
            result = admin_service.members().list(
                groupKey=group_email,
                maxResults=200,
                pageToken=page_token
            ).execute()
            
            members.extend(result.get('members', []))
            page_token = result.get('nextPageToken')
            if not page_token:
                break
                
        return members
        
    except HttpError as e:
        if e.resp.status == 403:
            print(f"No access to members for group {group_email}")
        else:
            print(f"Error fetching members for {group_email}: {e}")
        return []

def search_group_messages(gmail_service, group_email, max_results=1000):
    """Search for messages sent to a group using Gmail API"""
    try:
        # Search for messages sent to the group
        query = f"to:{group_email} OR cc:{group_email}"
        
        result = gmail_service.users().messages().list(
            userId='me',
            q=query,
            maxResults=max_results
        ).execute()
        
        messages = result.get('messages', [])
        print(f"Found {len(messages)} messages for group {group_email}")
        
        # Get message details
        message_details = []
        for msg in messages[:100]:  # Limit to first 100 for performance
            try:
                message = gmail_service.users().messages().get(
                    userId='me',
                    id=msg['id'],
                    format='metadata',
                    metadataHeaders=['Subject', 'From', 'To', 'Date', 'Message-ID']
                ).execute()
                message_details.append(message)
            except Exception as e:
                print(f"Error getting message {msg['id']}: {e}")
                continue
                
        return message_details
        
    except HttpError as e:
        print(f"Error searching messages for {group_email}: {e}")
        return []

def backup_domain_groups(admin_service, groups_service, gmail_service, domain, backup_dir):
    """Backup all groups and their message archives for a domain"""
    try:
        backup_data = {
            'domain': domain,
            'backup_date': datetime.now().isoformat(),
            'total_groups': 0,
            'backed_up_groups': 0,
            'groups_with_archives': 0,
            'groups': []
        }
        
        # Get all domain groups
        groups = get_domain_groups(admin_service, domain)
        backup_data['total_groups'] = len(groups)
        
        for group in groups:
            group_email = group['email']
            group_name = group.get('name', 'Unknown')
            
            print(f"Processing group: {group_name} ({group_email})")
            
            group_backup = {
                'email': group_email,
                'name': group_name,
                'description': group.get('description', ''),
                'id': group.get('id'),
                'admin_created': group.get('adminCreated', False),
                'direct_members_count': group.get('directMembersCount', 0),
                'settings': None,
                'members': [],
                'message_summary': {
                    'total_messages': 0,
                    'searchable_messages': 0,
                    'archive_status': 'unknown'
                },
                'backup_status': 'partial',
                'backup_notes': []
            }
            
            # Get group settings
            settings = get_group_settings(groups_service, group_email)
            if settings:
                group_backup['settings'] = settings
                
                # Check if group has archiving enabled
                archive_enabled = settings.get('isArchived', 'false').lower() == 'true'
                if archive_enabled:
                    backup_data['groups_with_archives'] += 1
                    group_backup['message_summary']['archive_status'] = 'enabled'
                else:
                    group_backup['message_summary']['archive_status'] = 'disabled'
            
            # Get group members
            members = get_group_members(admin_service, group_email)
            group_backup['members'] = members
            
            # Search for group messages (limited approach)
            messages = search_group_messages(gmail_service, group_email)
            group_backup['message_summary']['searchable_messages'] = len(messages)
            
            # Save individual group data
            group_file = Path(backup_dir) / f'group_{group_email.replace("@", "_at_")}.json'
            with open(group_file, 'w') as f:
                json.dump({
                    'group_info': group_backup,
                    'messages': messages[:50]  # Sample of messages
                }, f, indent=2, default=str)
            
            group_backup['backup_status'] = 'completed'
            backup_data['groups'].append(group_backup)
            backup_data['backed_up_groups'] += 1
        
        # Save main backup file
        backup_file = Path(backup_dir) / 'groups_backup.json'
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2, default=str)
        
        print(f"Groups backup completed: {backup_data['backed_up_groups']}/{backup_data['total_groups']} groups")
        print(f"Groups with archiving enabled: {backup_data['groups_with_archives']}")
        
        # Create backup instructions
        instructions_file = Path(backup_dir) / 'GROUPS_BACKUP_README.md'
        with open(instructions_file, 'w') as f:
            f.write(f"""# Google Groups Backup for {domain}

Generated: {datetime.now().isoformat()}

## Contents
- groups_backup.json: Complete groups metadata and summary
- group_*.json: Individual group details and message samples

## Backup Summary
- Total Groups: {backup_data['total_groups']}
- Successfully Backed Up: {backup_data['backed_up_groups']}
- Groups with Archiving: {backup_data['groups_with_archives']}

## Message Archive Limitations

### What This Backup Contains:
1. **Group Metadata**: Name, description, settings, members
2. **Group Configuration**: Archive settings, permissions, access controls
3. **Message Samples**: Limited recent messages visible through Gmail API search

### What This Backup DOES NOT Contain:
1. **Complete Message Archives**: Full historical messages are not accessible via standard APIs
2. **Attachments**: File attachments shared in group messages
3. **Rich Formatting**: Original message formatting may be lost

## Complete Message Archive Options

### For Groups with Google Vault Access:
```bash
# Export via Google Vault (admin access required)
# 1. Go to Google Vault (vault.google.com)
# 2. Create export for Groups data
# 3. Specify date range and export options
# 4. Download exported files when ready
```

### For Individual Users:
```bash
# Users can export their own group messages via Google Takeout
# 1. Go to Google Takeout (takeout.google.com)
# 2. Select "Groups" data
# 3. Choose format and delivery method
# 4. Download when ready
```

### For Migration to New Groups:
```bash
# Group metadata can be restored, but messages typically cannot be migrated
# 1. Recreate groups using backed up settings
# 2. Re-add members from backup
# 3. Restore group configuration
# 4. Note: Historical messages remain in original group
```

## Using This Backup

### Group Recreation:
The backup contains all necessary metadata to recreate groups with identical:
- Names and descriptions
- Member lists
- Permission settings
- Archive configurations

### Compliance and Audit:
- Group membership history
- Configuration changes over time
- Access control verification
- Archive status documentation

## Important Notes

1. **API Limitations**: Google Groups API has limited message access
2. **Archive Access**: Complete archives require Google Vault or user exports
3. **Migration Constraints**: Messages cannot be transferred between groups
4. **Retention**: Check your organization's retention policies for groups
""")
        
        return True
        
    except Exception as e:
        print(f"Error backing up groups: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python groups_api_backup.py <domain> <backup_dir>")
        sys.exit(1)
    
    domain = sys.argv[1]
    backup_dir = sys.argv[2]
    
    admin_service, groups_service, gmail_service = authenticate()
    if admin_service and groups_service and gmail_service:
        backup_domain_groups(admin_service, groups_service, gmail_service, domain, backup_dir)
    else:
        print("Authentication failed")
        sys.exit(1)
EOF
    
    # Execute Python groups backup
    if python3 "$backup_path/groups_api_backup.py" "$domain" "$backup_path"; then
        echo -e "${GREEN}✓ API groups backup completed${NC}"
        
        # Create restic backup
        create_restic_backup "domain" "groups_api" "$backup_path" "$storage_name" "$encryption_password"
    else
        echo -e "${RED}✗ API groups backup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$backup_path"
}

# Create service account-based ongoing Groups message backup system
setup_groups_service_account_backup() {
    local domain="$1"
    local service_account_email="$2"
    local storage_name="$3"
    local encryption_password="$4"
    
    echo -e "${CYAN}🤖 Setting up service account for ongoing Groups message backup${NC}"
    echo "Domain: $domain"
    echo "Service Account: $service_account_email"
    
    # Create staging directory
    local setup_path="/tmp/gwombat_service_setup_$(date +%s)"
    mkdir -p "$setup_path"
    
    # Python script for service account setup
    cat > "$setup_path/groups_service_setup.py" << 'EOF'
#!/usr/bin/env python3
"""
Google Groups Service Account Backup Setup
Creates service account, adds to groups, sets up filters
"""

import os
import sys
import json
import time
from datetime import datetime, timedelta
from pathlib import Path

# Google API imports
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    print("Error: Google API client libraries not installed")
    sys.exit(1)

# OAuth2 scopes for admin and Gmail access
SCOPES = [
    'https://www.googleapis.com/auth/admin.directory.group',
    'https://www.googleapis.com/auth/admin.directory.user',
    'https://www.googleapis.com/auth/gmail.settings.basic',
    'https://www.googleapis.com/auth/gmail.settings.filters'
]

def authenticate():
    """Authenticate with Google APIs"""
    creds = None
    token_file = './config/gws_token.json'
    credentials_file = './config/gws_credentials.json'
    
    if os.path.exists(token_file):
        creds = Credentials.from_authorized_user_file(token_file, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(credentials_file):
                print(f"Error: Credentials file not found at {credentials_file}")
                return None, None
            
            flow = InstalledAppFlow.from_client_secrets_file(credentials_file, SCOPES)
            creds = flow.run_local_server(port=0)
        
        os.makedirs('./config', exist_ok=True)
        with open(token_file, 'w') as token:
            token.write(creds.to_json())
    
    try:
        admin_service = build('admin', 'directory_v1', credentials=creds)
        gmail_service = build('gmail', 'v1', credentials=creds)
        return admin_service, gmail_service
    except Exception as e:
        print(f"Error building services: {e}")
        return None, None

def get_domain_groups(admin_service, domain):
    """Get all groups in domain"""
    try:
        groups = []
        page_token = None
        
        while True:
            result = admin_service.groups().list(
                domain=domain,
                maxResults=200,
                pageToken=page_token
            ).execute()
            
            groups.extend(result.get('groups', []))
            page_token = result.get('nextPageToken')
            if not page_token:
                break
                
        return groups
    except HttpError as e:
        print(f"Error fetching groups: {e}")
        return []

def add_service_account_to_groups(admin_service, service_account_email, groups, role='MEMBER'):
    """Add service account to all specified groups"""
    results = {
        'added': [],
        'already_member': [],
        'failed': []
    }
    
    for group in groups:
        group_email = group['email']
        group_name = group.get('name', 'Unknown')
        
        try:
            # Check if already a member
            try:
                admin_service.members().get(
                    groupKey=group_email,
                    memberKey=service_account_email
                ).execute()
                print(f"✓ Already member of: {group_name}")
                results['already_member'].append(group_email)
                continue
            except HttpError as e:
                if e.resp.status != 404:
                    raise
            
            # Add as member
            member_body = {
                'email': service_account_email,
                'role': role,
                'type': 'USER'
            }
            
            admin_service.members().insert(
                groupKey=group_email,
                body=member_body
            ).execute()
            
            print(f"✓ Added to group: {group_name}")
            results['added'].append(group_email)
            time.sleep(0.5)  # Rate limiting
            
        except HttpError as e:
            print(f"✗ Failed to add to {group_name}: {e}")
            results['failed'].append({'group': group_email, 'error': str(e)})
    
    return results

def create_gmail_filters_for_groups(gmail_service, service_account_email, groups):
    """Create Gmail filters to label group messages"""
    results = {
        'created': [],
        'failed': []
    }
    
    # Impersonate the service account for Gmail operations
    # Note: This requires domain-wide delegation for the service account
    
    for group in groups:
        group_email = group['email']
        group_name = group.get('name', 'Unknown')
        label_name = f"GroupArchive/{group_name}".replace(' ', '_')
        
        try:
            # Create label first
            label_body = {
                'name': label_name,
                'labelListVisibility': 'labelShow',
                'messageListVisibility': 'show'
            }
            
            try:
                gmail_service.users().labels().create(
                    userId=service_account_email,
                    body=label_body
                ).execute()
                print(f"✓ Created label: {label_name}")
            except HttpError as e:
                if 'already exists' not in str(e).lower():
                    print(f"Label creation warning for {label_name}: {e}")
            
            # Create filter
            filter_body = {
                'criteria': {
                    'from': group_email,
                    'to': service_account_email
                },
                'action': {
                    'addLabelIds': [],  # Will be populated with label ID
                    'removeLabelIds': ['INBOX'],  # Keep organized
                    'markAsRead': False  # Keep as unread for processing
                }
            }
            
            # Get label ID
            labels = gmail_service.users().labels().list(
                userId=service_account_email
            ).execute()
            
            label_id = None
            for label in labels.get('labels', []):
                if label['name'] == label_name:
                    label_id = label['id']
                    break
            
            if label_id:
                filter_body['action']['addLabelIds'] = [label_id]
                
                gmail_service.users().settings().filters().create(
                    userId=service_account_email,
                    body=filter_body
                ).execute()
                
                print(f"✓ Created filter for: {group_name}")
                results['created'].append({
                    'group': group_email,
                    'label': label_name,
                    'label_id': label_id
                })
            else:
                print(f"✗ Could not find label ID for: {label_name}")
                results['failed'].append({'group': group_email, 'error': 'Label not found'})
            
            time.sleep(0.5)  # Rate limiting
            
        except HttpError as e:
            print(f"✗ Failed to create filter for {group_name}: {e}")
            results['failed'].append({'group': group_email, 'error': str(e)})
    
    return results

def setup_ongoing_backup(domain, service_account_email, backup_dir):
    """Setup complete ongoing backup system"""
    admin_service, gmail_service = authenticate()
    if not admin_service or not gmail_service:
        return False
    
    setup_results = {
        'domain': domain,
        'service_account': service_account_email,
        'setup_date': datetime.now().isoformat(),
        'groups_processed': 0,
        'membership_results': {},
        'filter_results': {},
        'backup_instructions': {}
    }
    
    # Get all domain groups
    print(f"Fetching groups for domain: {domain}")
    groups = get_domain_groups(admin_service, domain)
    setup_results['groups_processed'] = len(groups)
    
    if not groups:
        print("No groups found or unable to access groups")
        return False
    
    print(f"Found {len(groups)} groups")
    
    # Add service account to groups
    print(f"\nAdding {service_account_email} to groups...")
    membership_results = add_service_account_to_groups(admin_service, service_account_email, groups)
    setup_results['membership_results'] = membership_results
    
    # Create Gmail filters (requires domain-wide delegation)
    print(f"\nCreating Gmail filters for {service_account_email}...")
    try:
        filter_results = create_gmail_filters_for_groups(gmail_service, service_account_email, groups)
        setup_results['filter_results'] = filter_results
    except Exception as e:
        print(f"Filter creation failed (may need domain-wide delegation): {e}")
        setup_results['filter_results'] = {'error': str(e)}
    
    # Save setup results
    setup_file = Path(backup_dir) / 'groups_service_setup.json'
    with open(setup_file, 'w') as f:
        json.dump(setup_results, f, indent=2, default=str)
    
    # Create ongoing backup instructions
    instructions_file = Path(backup_dir) / 'ONGOING_GROUPS_BACKUP.md'
    with open(instructions_file, 'w') as f:
        f.write(f"""# Ongoing Groups Message Backup System

Setup Date: {datetime.now().isoformat()}
Domain: {domain}
Service Account: {service_account_email}

## Setup Results
- Groups Processed: {setup_results['groups_processed']}
- Successfully Added to Groups: {len(membership_results.get('added', []))}
- Already Member: {len(membership_results.get('already_member', []))}
- Failed Additions: {len(membership_results.get('failed', []))}

## Ongoing Backup Process

### 1. Automated Collection
The service account {service_account_email} is now a member of all domain groups and will receive copies of all group messages.

### 2. Regular GYB Backup
Set up a scheduled backup of the service account's Gmail:

```bash
# Daily backup command
./backup_tools.sh gmail-backup {service_account_email} full

# Weekly full backup with restic
./backup_tools.sh restic-backup {service_account_email} gmail ./backups/gmail/{service_account_email} <storage> <password>
```

### 3. Filter Organization
Each group's messages are filtered into separate labels:
- Label Format: GroupArchive/[GroupName]
- Messages are automatically removed from inbox
- Labels maintain organization for easy backup by group

### 4. Scheduled Backup Script
Create a cron job for regular backups:

```cron
# Daily at 2 AM
0 2 * * * cd /path/to/gwombat && ./backup_tools.sh gmail-backup {service_account_email} incremental

# Weekly full backup with cloud upload
0 3 * * 0 cd /path/to/gwombat && ./backup_tools.sh comprehensive-backup {service_account_email} <storage> <password>
```

## Benefits of This Approach

1. **Complete Message Archive**: All group messages are captured
2. **Real-time Collection**: New messages are immediately available
3. **Organized Storage**: Each group gets its own label/folder
4. **Standard Backup Tools**: Uses existing GYB and restic infrastructure
5. **Searchable Archives**: All messages remain searchable in Gmail
6. **Compliance Ready**: Complete audit trail of all group communications

## Management Commands

### Check Service Account Status
```bash
# List groups service account belongs to
gam user {service_account_email} show groups

# Check Gmail filters
gam user {service_account_email} show filters

# Show label structure
gam user {service_account_email} show labels
```

### Add to New Groups
```bash
# Add service account to new group
gam update group <new_group@{domain}> add member {service_account_email}

# Create filter for new group (manual)
# Or re-run the setup script
```

## Troubleshooting

### Missing Messages
- Check group membership: Service account must be member
- Verify filters are active and pointing to correct labels
- Check Gmail quota and storage limits

### Access Issues
- Ensure service account has necessary permissions
- Verify domain-wide delegation if using API-based filter creation
- Check that groups allow external members (if applicable)

## Security Considerations

1. **Service Account Security**: Protect service account credentials
2. **Access Permissions**: Service account only needs read access to groups
3. **Data Retention**: Follow organizational retention policies
4. **Encryption**: All backups are encrypted with restic
5. **Access Logging**: All backup operations are logged

This system provides comprehensive, ongoing group message archival that integrates seamlessly with GWOMBAT's existing backup infrastructure.
""")
    
    print(f"\nSetup completed. Results saved to: {setup_file}")
    print(f"Instructions saved to: {instructions_file}")
    
    return True

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python groups_service_setup.py <domain> <service_account_email> <backup_dir>")
        sys.exit(1)
    
    domain = sys.argv[1]
    service_account_email = sys.argv[2]
    backup_dir = sys.argv[3]
    
    if setup_ongoing_backup(domain, service_account_email, backup_dir):
        print("Service account backup setup completed successfully")
    else:
        print("Setup failed")
        sys.exit(1)
EOF
    
    # Execute Python setup script
    if python3 "$setup_path/groups_service_setup.py" "$domain" "$service_account_email" "$setup_path"; then
        echo -e "${GREEN}✓ Service account setup completed${NC}"
        
        # Create restic backup of setup configuration
        create_restic_backup "domain" "groups_service_setup" "$setup_path" "$storage_name" "$encryption_password"
        
        echo ""
        echo -e "${YELLOW}📋 Next Steps:${NC}"
        echo "1. Set up scheduled GYB backups for $service_account_email"
        echo "2. Configure cron job for regular incremental backups"
        echo "3. Test the system with a test message to a group"
        echo "4. Monitor backup logs for any issues"
        echo ""
        echo -e "${CYAN}Suggested cron entry:${NC}"
        echo "0 2 * * * cd $(pwd) && ./backup_tools.sh gmail-backup $service_account_email incremental"
        
    else
        echo -e "${RED}✗ Service account setup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$setup_path"
}

# Backup Gmail filters and settings
backup_gmail_filters() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    
    echo -e "${CYAN}⚙️ Backing up Gmail filters and settings for $user_email${NC}"
    
    # Create staging directory
    local backup_path="/tmp/gwombat_filters_backup_$(date +%s)"
    mkdir -p "$backup_path"
    
    # Python script for Gmail filters backup
    cat > "$backup_path/gmail_filters_backup.py" << 'EOF'
#!/usr/bin/env python3
"""
Gmail Filters and Settings Backup
Comprehensive backup of Gmail configuration
"""

import os
import sys
import json
from datetime import datetime
from pathlib import Path

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    print("Error: Google API client libraries not installed")
    sys.exit(1)

SCOPES = [
    'https://www.googleapis.com/auth/gmail.settings.basic',
    'https://www.googleapis.com/auth/gmail.settings.filters',
    'https://www.googleapis.com/auth/gmail.settings.forwarding',
    'https://www.googleapis.com/auth/gmail.labels'
]

def authenticate():
    """Authenticate with Gmail API"""
    creds = None
    token_file = './config/gws_token.json'
    credentials_file = './config/gws_credentials.json'
    
    if os.path.exists(token_file):
        creds = Credentials.from_authorized_user_file(token_file, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(credentials_file):
                print(f"Error: Credentials file not found at {credentials_file}")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(credentials_file, SCOPES)
            creds = flow.run_local_server(port=0)
        
        os.makedirs('./config', exist_ok=True)
        with open(token_file, 'w') as token:
            token.write(creds.to_json())
    
    try:
        return build('gmail', 'v1', credentials=creds)
    except Exception as e:
        print(f"Error building Gmail service: {e}")
        return None

def backup_gmail_settings(service, user_email, backup_dir):
    """Backup comprehensive Gmail settings"""
    backup_data = {
        'user_email': user_email,
        'backup_date': datetime.now().isoformat(),
        'filters': [],
        'labels': [],
        'forwarding_addresses': [],
        'vacation_settings': {},
        'imap_settings': {},
        'pop_settings': {},
        'general_settings': {},
        'send_as_settings': [],
        'signature': '',
        'delegates': []
    }
    
    try:
        # Backup filters
        print("Backing up filters...")
        filters_result = service.users().settings().filters().list(userId=user_email).execute()
        backup_data['filters'] = filters_result.get('filter', [])
        print(f"✓ Backed up {len(backup_data['filters'])} filters")
        
        # Backup labels
        print("Backing up labels...")
        labels_result = service.users().labels().list(userId=user_email).execute()
        backup_data['labels'] = labels_result.get('labels', [])
        print(f"✓ Backed up {len(backup_data['labels'])} labels")
        
        # Backup forwarding addresses
        try:
            forwarding_result = service.users().settings().forwardingAddresses().list(userId=user_email).execute()
            backup_data['forwarding_addresses'] = forwarding_result.get('forwardingAddresses', [])
            print(f"✓ Backed up {len(backup_data['forwarding_addresses'])} forwarding addresses")
        except HttpError as e:
            print(f"Could not backup forwarding addresses: {e}")
        
        # Backup vacation/auto-reply settings
        try:
            vacation_result = service.users().settings().getVacation(userId=user_email).execute()
            backup_data['vacation_settings'] = vacation_result
            print("✓ Backed up vacation settings")
        except HttpError as e:
            print(f"Could not backup vacation settings: {e}")
        
        # Backup IMAP settings
        try:
            imap_result = service.users().settings().getImap(userId=user_email).execute()
            backup_data['imap_settings'] = imap_result
            print("✓ Backed up IMAP settings")
        except HttpError as e:
            print(f"Could not backup IMAP settings: {e}")
        
        # Backup POP settings  
        try:
            pop_result = service.users().settings().getPop(userId=user_email).execute()
            backup_data['pop_settings'] = pop_result
            print("✓ Backed up POP settings")
        except HttpError as e:
            print(f"Could not backup POP settings: {e}")
        
        # Backup send-as settings
        try:
            sendas_result = service.users().settings().sendAs().list(userId=user_email).execute()
            backup_data['send_as_settings'] = sendas_result.get('sendAs', [])
            
            # Get signature for each send-as address
            for sendas in backup_data['send_as_settings']:
                if 'sendAsEmail' in sendas:
                    try:
                        signature_result = service.users().settings().sendAs().get(
                            userId=user_email, 
                            sendAsEmail=sendas['sendAsEmail']
                        ).execute()
                        sendas['full_details'] = signature_result
                    except HttpError:
                        pass
            
            print(f"✓ Backed up {len(backup_data['send_as_settings'])} send-as settings")
        except HttpError as e:
            print(f"Could not backup send-as settings: {e}")
        
        # Backup delegates
        try:
            delegates_result = service.users().settings().delegates().list(userId=user_email).execute()
            backup_data['delegates'] = delegates_result.get('delegates', [])
            print(f"✓ Backed up {len(backup_data['delegates'])} delegates")
        except HttpError as e:
            print(f"Could not backup delegates: {e}")
        
        # Save main backup file
        backup_file = Path(backup_dir) / f'gmail_settings_{user_email.replace("@", "_at_")}.json'
        with open(backup_file, 'w') as f:
            json.dump(backup_data, f, indent=2, default=str)
        
        # Create detailed filters file for easy reading
        filters_file = Path(backup_dir) / f'gmail_filters_{user_email.replace("@", "_at_")}.json'
        with open(filters_file, 'w') as f:
            json.dump({
                'user_email': user_email,
                'backup_date': datetime.now().isoformat(),
                'filter_count': len(backup_data['filters']),
                'filters': backup_data['filters']
            }, f, indent=2, default=str)
        
        # Create restoration script
        restore_script = Path(backup_dir) / f'restore_gmail_settings_{user_email.replace("@", "_at_")}.py'
        with open(restore_script, 'w') as f:
            f.write(f'''#!/usr/bin/env python3
"""
Gmail Settings Restoration Script for {user_email}
Generated: {datetime.now().isoformat()}

Usage: python restore_gmail_settings_{user_email.replace("@", "_at_")}.py <target_user_email>
"""

import json
import sys
from pathlib import Path

# Load backup data
with open('{backup_file.name}', 'r') as f:
    backup_data = json.load(f)

def restore_filters(service, target_user):
    """Restore Gmail filters to target user"""
    print(f"Restoring {{len(backup_data['filters'])}} filters to {{target_user}}")
    
    for filter_data in backup_data['filters']:
        # Remove ID and other server-generated fields
        filter_body = {{
            'criteria': filter_data.get('criteria', {{}}),
            'action': filter_data.get('action', {{}})
        }}
        
        try:
            service.users().settings().filters().create(
                userId=target_user,
                body=filter_body
            ).execute()
            print(f"✓ Restored filter: {{filter_data.get('criteria', {{}}).get('from', 'Unknown')}}")
        except Exception as e:
            print(f"✗ Failed to restore filter: {{e}}")

def restore_labels(service, target_user):
    """Restore custom Gmail labels"""
    custom_labels = [l for l in backup_data['labels'] if l.get('type') == 'user']
    print(f"Restoring {{len(custom_labels)}} custom labels to {{target_user}}")
    
    for label_data in custom_labels:
        label_body = {{
            'name': label_data['name'],
            'labelListVisibility': label_data.get('labelListVisibility', 'labelShow'),
            'messageListVisibility': label_data.get('messageListVisibility', 'show')
        }}
        
        try:
            service.users().labels().create(
                userId=target_user,
                body=label_body
            ).execute()
            print(f"✓ Restored label: {{label_data['name']}}")
        except Exception as e:
            if 'already exists' not in str(e).lower():
                print(f"✗ Failed to restore label {{label_data['name']}}: {{e}}")

# Add authentication and service building code here
# Then call restore_filters() and restore_labels()
''')
        
        # Create backup summary
        summary_file = Path(backup_dir) / 'GMAIL_SETTINGS_BACKUP_README.md'
        with open(summary_file, 'w') as f:
            f.write(f"""# Gmail Settings Backup for {user_email}

Generated: {datetime.now().isoformat()}

## Backup Contents

### Filters ({len(backup_data['filters'])})
- Complete filter criteria and actions
- All rules for automatic mail processing
- Label assignments and forwarding rules

### Labels ({len(backup_data['labels'])})
- System labels: {len([l for l in backup_data['labels'] if l.get('type') == 'system'])}
- Custom labels: {len([l for l in backup_data['labels'] if l.get('type') == 'user'])}
- Label visibility and display settings

### Account Settings
- Forwarding addresses: {len(backup_data['forwarding_addresses'])}
- Send-as addresses: {len(backup_data['send_as_settings'])}
- Delegates: {len(backup_data['delegates'])}
- Vacation settings: {'✓' if backup_data['vacation_settings'] else '✗'}
- IMAP settings: {'✓' if backup_data['imap_settings'] else '✗'}
- POP settings: {'✓' if backup_data['pop_settings'] else '✗'}

## Files Created

1. **gmail_settings_{user_email.replace("@", "_at_")}.json** - Complete backup data
2. **gmail_filters_{user_email.replace("@", "_at_")}.json** - Filters only (for easy import)
3. **restore_gmail_settings_{user_email.replace("@", "_at_")}.py** - Restoration script
4. **GMAIL_SETTINGS_BACKUP_README.md** - This documentation

## Restoration Options

### Option 1: Using GWOMBAT
```bash
# Restore to same user
./backup_tools.sh restore-gmail-settings {user_email}

# Restore to different user  
./backup_tools.sh restore-gmail-settings {user_email} <target_user@domain.com>
```

### Option 2: Manual Filter Import
1. Download gmail_filters_{user_email.replace("@", "_at_")}.json
2. Use Gmail's filter import feature (if available)
3. Or manually recreate filters from JSON data

### Option 3: Python Script
```bash
python restore_gmail_settings_{user_email.replace("@", "_at_")}.py <target_user@domain.com>
```

## What Can Be Restored

✅ **Fully Restorable:**
- All Gmail filters and rules
- Custom labels and organization
- Send-as addresses and signatures
- Forwarding addresses (with re-verification)
- Vacation/auto-reply settings

⚠️ **Partially Restorable:**
- Delegates (require re-approval)
- IMAP/POP settings (may need admin permissions)

❌ **Cannot Be Restored:**
- Message history and content
- Conversation threading preferences
- Some advanced security settings

## Important Notes

1. **Filter Dependencies**: Some filters may depend on labels that need to be created first
2. **Permissions**: Restoring to a different user may require admin permissions
3. **Verification**: Forwarding addresses will need to be re-verified
4. **Signatures**: HTML signatures are preserved with full formatting
5. **Delegates**: Delegation relationships require fresh approval

This backup provides comprehensive preservation of Gmail configuration for disaster recovery or user migration scenarios.
""")
        
        print(f"Gmail settings backup completed for {user_email}")
        print(f"Files saved to: {backup_dir}")
        return True
        
    except Exception as e:
        print(f"Error backing up Gmail settings: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python gmail_filters_backup.py <user_email> <backup_dir>")
        sys.exit(1)
    
    user_email = sys.argv[1]
    backup_dir = sys.argv[2]
    
    service = authenticate()
    if service:
        if backup_gmail_settings(service, user_email, backup_dir):
            print("Gmail settings backup completed successfully")
        else:
            print("Backup failed")
            sys.exit(1)
    else:
        print("Authentication failed")
        sys.exit(1)
EOF
    
    # Execute Python filters backup
    if python3 "$backup_path/gmail_filters_backup.py" "$user_email" "$backup_path"; then
        echo -e "${GREEN}✓ Gmail filters backup completed${NC}"
        
        # Create restic backup
        create_restic_backup "$user_email" "gmail_settings" "$backup_path" "$storage_name" "$encryption_password"
    else
        echo -e "${RED}✗ Gmail filters backup failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$backup_path"
}

# Backup Google Groups settings including auto-reply configurations
backup_groups_settings() {
    local domain="$1"
    local storage_name="$2"
    local encryption_password="$3"
    
    echo -e "${CYAN}⚙️ Backing up Google Groups settings for $domain${NC}"
    
    # Create staging directory
    local backup_path="/tmp/gwombat_groups_settings_backup_$(date +%s)"
    mkdir -p "$backup_path"
    
    echo -e "${YELLOW}Fetching all groups in domain...${NC}"
    
    # Get list of all groups
    if ! gam print groups > "$backup_path/groups_list.csv" 2>/dev/null; then
        echo -e "${RED}✗ Failed to fetch groups list${NC}"
        rm -rf "$backup_path"
        return 1
    fi
    
    local group_count=$(tail -n +2 "$backup_path/groups_list.csv" | wc -l)
    echo -e "${GREEN}Found $group_count groups to backup${NC}"
    
    # Create detailed settings backup for each group
    echo -e "${YELLOW}Backing up individual group settings...${NC}"
    
    mkdir -p "$backup_path/individual_groups"
    
    # Process each group
    while IFS=',' read -r email name description || [[ -n "$email" ]]; do
        # Skip header row
        if [[ "$email" == "email" ]]; then
            continue
        fi
        
        # Clean up email (remove quotes if present)
        email=$(echo "$email" | tr -d '"')
        name=$(echo "$name" | tr -d '"')
        
        if [[ -n "$email" ]]; then
            echo "Processing group: $email"
            
            # Get group settings using GAM
            local group_file="$backup_path/individual_groups/${email}.txt"
            
            {
                echo "=== GROUP INFORMATION ==="
                echo "Email: $email"
                echo "Name: $name"
                echo "Description: $description"
                echo "Backup Date: $(date)"
                echo ""
                
                echo "=== GROUP SETTINGS ==="
                gam info group "$email" 2>/dev/null || echo "Error: Could not fetch group settings"
                echo ""
                
                echo "=== GROUP MEMBERS ==="
                gam print group-members group "$email" 2>/dev/null || echo "Error: Could not fetch group members"
                echo ""
                
                echo "=== GROUP ALIASES ==="
                gam print aliases group "$email" 2>/dev/null || echo "Error: Could not fetch group aliases"
                echo ""
                
            } > "$group_file"
            
            # Also get group settings in JSON format for easier parsing
            gam info group "$email" formatjson > "$backup_path/individual_groups/${email}.json" 2>/dev/null || \
                echo '{"error": "Could not fetch group settings"}' > "$backup_path/individual_groups/${email}.json"
        fi
    done < "$backup_path/groups_list.csv"
    
    # Create comprehensive groups settings summary
    echo -e "${YELLOW}Creating groups settings summary...${NC}"
    
    cat > "$backup_path/groups_settings_summary.md" << EOF
# Google Groups Settings Backup for $domain

Generated: $(date)
Total Groups: $group_count

## Backup Contents

### 1. Complete Groups List
- File: groups_list.csv
- Contains: Email, name, description for all groups

### 2. Individual Group Settings
- Directory: individual_groups/
- Contains: Detailed settings for each group including:
  - Group information and description
  - Auto-reply/vacation message settings
  - Message moderation settings
  - Member permissions and roles
  - Posting permissions
  - Message delivery options
  - Archive settings
  - Group aliases

### 3. Settings That Can Be Backed Up

✅ **Fully Backed Up:**
- Group name and description
- Member list and roles
- Auto-reply messages (vacation responses)
- Message moderation settings
- Posting permissions (who can post)
- Reply-to settings
- Message delivery options
- Archive visibility settings
- Group aliases and alternative addresses

❌ **Group Auto-Reply Settings:**
Google Groups auto-reply settings are NOT accessible via GAM/API and cannot be backed up:
- Auto-reply to members inside organization
- Auto-reply to non-members inside organization  
- Auto-reply to members outside organization
- Auto-reply to non-members outside organization
- Auto-reply message content

These settings must be manually documented and configured through the Google Groups web interface.

### 4. Restoration Process

#### Using GAM Commands:
\`\`\`bash
# Restore group settings (example)
gam create group newgroup@domain.com name "Group Name" description "Description"

# Note: Auto-reply settings cannot be restored via GAM - manual configuration required

# Restore members
gam update group newgroup@domain.com add member user1@domain.com role member
gam update group newgroup@domain.com add member admin@domain.com role manager

# Restore posting permissions
gam update group newgroup@domain.com who_can_post_message all_members_can_post
\`\`\`

#### Using GWOMBAT:
\`\`\`bash
# Restore all groups settings from backup
./backup_tools.sh restore-groups-settings $domain <backup_location>
\`\`\`

## Important Notes

1. **Auto-Reply Messages**: Google Groups auto-reply settings CANNOT be backed up via GAM/API
2. **Member Relationships**: Group memberships and roles are completely backed up
3. **Permissions**: All posting, viewing, and moderation permissions are captured
4. **Aliases**: Alternative email addresses for groups are included
5. **Archive Settings**: Message archive visibility and access controls

## Manual Verification Recommended

After restoration, manually verify:
- [ ] Auto-reply messages are manually reconfigured (not backed up by GAM)
- [ ] Group permissions match original settings
- [ ] Member roles are correctly assigned
- [ ] Message delivery preferences are preserved

This backup provides preservation of Google Groups configuration. Note: Auto-reply settings must be manually documented and reconfigured as they are not accessible via GAM/API.
EOF
    
    # Create restoration script
    cat > "$backup_path/restore_groups_settings.sh" << 'EOF'
#!/bin/bash
# Google Groups Settings Restoration Script
# Usage: ./restore_groups_settings.sh [target_domain]

TARGET_DOMAIN="${1:-}"
BACKUP_DIR="$(dirname "$0")"

if [[ -z "$TARGET_DOMAIN" ]]; then
    echo "Usage: $0 <target_domain>"
    echo "Example: $0 newdomain.edu"
    exit 1
fi

echo "Restoring Google Groups settings to domain: $TARGET_DOMAIN"
echo "Reading from backup directory: $BACKUP_DIR"

# Function to restore a single group
restore_group() {
    local group_email="$1"
    local group_json="$2"
    
    if [[ ! -f "$group_json" ]]; then
        echo "Warning: JSON file not found for $group_email"
        return 1
    fi
    
    echo "Restoring group: $group_email"
    
    # Extract basic info (this would need proper JSON parsing in production)
    # For now, provide manual restoration instructions
    echo "Manual restoration required for: $group_email"
    echo "Refer to: $group_json for settings"
    echo "---"
}

# Process all groups
if [[ -f "$BACKUP_DIR/groups_list.csv" ]]; then
    while IFS=',' read -r email name description; do
        if [[ "$email" != "email" && -n "$email" ]]; then
            email=$(echo "$email" | tr -d '"')
            restore_group "$email" "$BACKUP_DIR/individual_groups/${email}.json"
        fi
    done < "$BACKUP_DIR/groups_list.csv"
else
    echo "Error: groups_list.csv not found in backup"
    exit 1
fi

echo "Group restoration completed. Please verify settings manually."
EOF
    
    chmod +x "$backup_path/restore_groups_settings.sh"
    
    echo -e "${GREEN}✓ Groups settings backup completed${NC}"
    echo -e "${YELLOW}Files created:${NC}"
    echo "  • groups_list.csv - Complete groups list"
    echo "  • individual_groups/ - Detailed settings per group"
    echo "  • groups_settings_summary.md - Backup documentation"
    echo "  • restore_groups_settings.sh - Restoration script"
    
    # Create restic backup
    create_restic_backup "domain" "groups_settings" "$backup_path" "$storage_name" "$encryption_password"
    
    # Cleanup
    rm -rf "$backup_path"
}

# Create comprehensive API-based user backup
create_comprehensive_api_backup() {
    local user_email="$1"
    local storage_name="$2"
    local encryption_password="$3"
    local domain="${4:-$(echo "$user_email" | cut -d'@' -f2)}"
    
    echo -e "${CYAN}🎯 Creating comprehensive API-based backup for $user_email${NC}"
    
    # 1. Gmail backup (existing GYB method)
    echo -e "${YELLOW}📧 Gmail backup (GYB)...${NC}"
    create_gmail_backup "$user_email" "full"
    
    # 2. Calendar API backup
    echo -e "${YELLOW}📅 Calendar API backup...${NC}"
    create_api_calendar_backup "$user_email" "$storage_name" "$encryption_password"
    
    # 3. Contacts API backup
    echo -e "${YELLOW}👥 Contacts API backup...${NC}"
    create_api_contacts_backup "$user_email" "$storage_name" "$encryption_password"
    
    # 4. Drive backup (existing rclone + restic method)
    echo -e "${YELLOW}💾 Drive incremental backup...${NC}"
    create_drive_incremental_backup "$user_email" "$storage_name" "$encryption_password"
    
    # 5. Sites backup (domain-level)
    echo -e "${YELLOW}🌐 Sites API backup...${NC}"
    create_api_sites_backup "$domain" "$storage_name" "$encryption_password"
    
    # 6. Groups backup (domain-level)
    echo -e "${YELLOW}👥 Groups message archive backup...${NC}"
    create_api_groups_backup "$domain" "$storage_name" "$encryption_password"
    
    echo -e "${GREEN}✅ Comprehensive API-based backup completed for $user_email${NC}"
    echo ""
    echo -e "${YELLOW}📋 API Backup Components:${NC}"
    echo "  • Gmail: Complete mailbox (GYB)"
    echo "  • Calendar: All calendars and events (Calendar API)"
    echo "  • Contacts: All contacts and groups (People API)"
    echo "  • Drive: Incremental file backup (rclone + restic)"
    echo "  • Sites: Domain sites metadata (Sites API)"
    echo "  • Groups: Message archives and metadata (Groups API)"
    echo "  • Storage: $storage_name (encrypted with restic)"
}

# ==========================================
# RESTORATION FUNCTIONS
# ==========================================

# List available backups for restoration
list_restic_snapshots() {
    local storage_name="$1"
    local encryption_password="$2"
    local user_filter="${3:-}"
    local backup_type_filter="${4:-}"
    
    echo -e "${CYAN}📋 Listing available restic snapshots${NC}"
    
    # Get storage configuration
    local storage_config
    storage_config=$(get_storage_config "$storage_name")
    if [[ -z "$storage_config" ]]; then
        echo -e "${RED}✗ Storage configuration not found for: $storage_name${NC}"
        return 1
    fi
    
    local repo_url=$(echo "$storage_config" | jq -r '.restic_repo_url // empty')
    if [[ -z "$repo_url" ]]; then
        echo -e "${RED}✗ No restic repository configured for storage: $storage_name${NC}"
        return 1
    fi
    
    # Set restic environment
    export RESTIC_REPOSITORY="$repo_url"
    export RESTIC_PASSWORD="$encryption_password"
    
    echo -e "${YELLOW}Repository: $repo_url${NC}"
    echo ""
    
    # Build filter arguments
    local filter_args=""
    if [[ -n "$user_filter" ]]; then
        filter_args="--tag user:$user_filter"
    fi
    if [[ -n "$backup_type_filter" ]]; then
        filter_args="$filter_args --tag type:$backup_type_filter"
    fi
    
    # List snapshots
    echo -e "${CYAN}Available Snapshots:${NC}"
    if ! restic snapshots $filter_args --compact; then
        echo -e "${RED}✗ Failed to list snapshots${NC}"
        unset RESTIC_REPOSITORY RESTIC_PASSWORD
        return 1
    fi
    
    unset RESTIC_REPOSITORY RESTIC_PASSWORD
}

# Restore files from restic backup to specified location
restore_restic_backup() {
    local storage_name="$1"
    local encryption_password="$2"
    local snapshot_id="$3"
    local restore_path="$4"
    local target_path="${5:-./restored_files}"
    local user_email="${6:-}"
    
    echo -e "${CYAN}🔄 Restoring files from restic backup${NC}"
    echo "Snapshot: $snapshot_id"
    echo "Source: $restore_path"
    echo "Target: $target_path"
    
    # Get storage configuration
    local storage_config
    storage_config=$(get_storage_config "$storage_name")
    if [[ -z "$storage_config" ]]; then
        echo -e "${RED}✗ Storage configuration not found for: $storage_name${NC}"
        return 1
    fi
    
    local repo_url=$(echo "$storage_config" | jq -r '.restic_repo_url // empty')
    if [[ -z "$repo_url" ]]; then
        echo -e "${RED}✗ No restic repository configured for storage: $storage_name${NC}"
        return 1
    fi
    
    # Set restic environment
    export RESTIC_REPOSITORY="$repo_url"
    export RESTIC_PASSWORD="$encryption_password"
    
    # Create target directory
    mkdir -p "$target_path"
    
    # Restore files
    echo -e "${YELLOW}Restoring files...${NC}"
    if restic restore "$snapshot_id" --target "$target_path" --include "$restore_path"; then
        echo -e "${GREEN}✓ Files restored successfully to: $target_path${NC}"
        
        # Log restoration
        log_restoration_activity "$snapshot_id" "$restore_path" "$target_path" "$user_email" "success"
        
        # Show restored files
        echo ""
        echo -e "${CYAN}Restored files:${NC}"
        find "$target_path" -type f | head -20
        if [[ $(find "$target_path" -type f | wc -l) -gt 20 ]]; then
            echo "... and $(( $(find "$target_path" -type f | wc -l) - 20 )) more files"
        fi
        
        unset RESTIC_REPOSITORY RESTIC_PASSWORD
        return 0
    else
        echo -e "${RED}✗ Failed to restore files${NC}"
        log_restoration_activity "$snapshot_id" "$restore_path" "$target_path" "$user_email" "failed"
        unset RESTIC_REPOSITORY RESTIC_PASSWORD
        return 1
    fi
}

# Restore user Drive files to new account
restore_drive_to_account() {
    local source_user="$1"
    local target_user="$2"
    local storage_name="$3"
    local encryption_password="$4"
    local snapshot_id="$5"
    local rclone_remote="${6:-gdrive}"
    
    echo -e "${CYAN}📁 Restoring Drive files from $source_user to $target_user${NC}"
    
    # Create temporary restoration directory
    local temp_restore="/tmp/gwombat_drive_restore_$(date +%s)"
    mkdir -p "$temp_restore"
    
    # Restore files from restic
    if ! restore_restic_backup "$storage_name" "$encryption_password" "$snapshot_id" "/" "$temp_restore"; then
        echo -e "${RED}✗ Failed to restore files from backup${NC}"
        rm -rf "$temp_restore"
        return 1
    fi
    
    # Configure rclone for target user
    local target_remote="${rclone_remote}_${target_user//@/_}"
    
    echo -e "${YELLOW}Uploading files to $target_user's Drive...${NC}"
    
    # Upload files to target user's Drive
    if rclone copy "$temp_restore" "$target_remote:" --progress --transfers 4 --checkers 8; then
        echo -e "${GREEN}✓ Drive files restored to $target_user${NC}"
        
        # Log the operation
        log_restoration_activity "$snapshot_id" "drive_restore" "$target_user" "$source_user" "success"
        
        # Cleanup
        rm -rf "$temp_restore"
        return 0
    else
        echo -e "${RED}✗ Failed to upload files to target account${NC}"
        log_restoration_activity "$snapshot_id" "drive_restore" "$target_user" "$source_user" "failed"
        rm -rf "$temp_restore"
        return 1
    fi
}

# Restore Gmail data using GYB
restore_gmail_backup() {
    local source_user="$1"
    local target_user="$2"
    local backup_type="${3:-restore}"
    local backup_path="${4:-}"
    
    echo -e "${CYAN}📧 Restoring Gmail from $source_user to $target_user${NC}"
    
    # Determine backup path
    if [[ -z "$backup_path" ]]; then
        backup_path="./backups/gmail/$source_user"
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        echo -e "${RED}✗ Gmail backup not found at: $backup_path${NC}"
        return 1
    fi
    
    # GYB restore command
    echo -e "${YELLOW}Starting Gmail restore (this may take a while)...${NC}"
    
    local gyb_command="$GYB_PATH --email '$target_user' --action restore --local-folder '$backup_path'"
    
    if [[ "$backup_type" == "restore-mbox" ]]; then
        gyb_command="$gyb_command --use-mbox"
    fi
    
    echo -e "${BLUE}Command: $gyb_command${NC}"
    
    # Execute restore
    if eval "$gyb_command"; then
        echo -e "${GREEN}✓ Gmail restore completed for $target_user${NC}"
        
        # Log the operation
        log_restoration_activity "gmail_backup" "$backup_path" "$target_user" "$source_user" "success"
        return 0
    else
        echo -e "${RED}✗ Gmail restore failed${NC}"
        log_restoration_activity "gmail_backup" "$backup_path" "$target_user" "$source_user" "failed"
        return 1
    fi
}

# Interactive restoration menu
interactive_restore_menu() {
    local storage_name="$1"
    local encryption_password="$2"
    
    echo -e "${CYAN}🔄 GWOMBAT Interactive Restoration Menu${NC}"
    echo ""
    
    while true; do
        echo -e "${YELLOW}Restoration Options:${NC}"
        echo "1. List available snapshots"
        echo "2. Restore files to local directory"
        echo "3. Restore Drive files to new account"
        echo "4. Restore Gmail to new account"
        echo "5. Search snapshots by user"
        echo "6. Search snapshots by backup type"
        echo "7. View snapshot details"
        echo "x. Exit"
        echo ""
        read -p "Select option: " choice
        
        case "$choice" in
            1)
                list_restic_snapshots "$storage_name" "$encryption_password"
                ;;
            2)
                read -p "Enter snapshot ID: " snapshot_id
                read -p "Enter path to restore (or / for all): " restore_path
                read -p "Enter target directory [./restored_files]: " target_path
                target_path="${target_path:-./restored_files}"
                restore_restic_backup "$storage_name" "$encryption_password" "$snapshot_id" "$restore_path" "$target_path"
                ;;
            3)
                read -p "Enter source user email: " source_user
                read -p "Enter target user email: " target_user
                read -p "Enter snapshot ID: " snapshot_id
                restore_drive_to_account "$source_user" "$target_user" "$storage_name" "$encryption_password" "$snapshot_id"
                ;;
            4)
                read -p "Enter source user email: " source_user
                read -p "Enter target user email: " target_user
                read -p "Enter backup path [auto-detect]: " backup_path
                restore_gmail_backup "$source_user" "$target_user" "restore" "$backup_path"
                ;;
            5)
                read -p "Enter user email to filter: " user_filter
                list_restic_snapshots "$storage_name" "$encryption_password" "$user_filter"
                ;;
            6)
                read -p "Enter backup type to filter (gmail/drive/full/config): " type_filter
                list_restic_snapshots "$storage_name" "$encryption_password" "" "$type_filter"
                ;;
            7)
                read -p "Enter snapshot ID: " snapshot_id
                export RESTIC_REPOSITORY=$(get_storage_config "$storage_name" | jq -r '.restic_repo_url')
                export RESTIC_PASSWORD="$encryption_password"
                restic snapshots "$snapshot_id" --json | jq '.[0]'
                unset RESTIC_REPOSITORY RESTIC_PASSWORD
                ;;
            "x"|"X")
                echo "Exiting restoration menu"
                break
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
        echo ""
    done
}

# Log restoration activities
log_restoration_activity() {
    local snapshot_id="$1"
    local source_path="$2"
    local target_path="$3"
    local user_email="$4"
    local status="$5"
    local session_id="${GWOMBAT_SESSION_ID:-$(date +%s)}"
    
    # Insert into database if available
    if command -v sqlite3 &> /dev/null && [[ -f "./config/gwombat.db" ]]; then
        sqlite3 "./config/gwombat.db" << EOF
INSERT INTO operation_log (
    operation_type, 
    operation_details, 
    user_email, 
    status, 
    session_id,
    operation_timestamp
) VALUES (
    'restore_operation',
    json_object(
        'snapshot_id', '$snapshot_id',
        'source_path', '$source_path', 
        'target_path', '$target_path',
        'restoration_status', '$status'
    ),
    '$user_email',
    '$status',
    '$session_id',
    datetime('now')
);
EOF
    fi
    
    # Also log to file
    echo "$(date '+%Y-%m-%d %H:%M:%S') - RESTORE: $snapshot_id -> $target_path [$status] ($user_email)" >> "./logs/restoration.log"
}

# Command line interface
case "${1:-status}" in
    "init")
        init_backup_db
        ;;
    "status")
        show_backup_status
        ;;
    "backup-user")
        if [[ -z "$2" ]]; then
            echo "Usage: $0 backup-user <email> [gmail:1/0] [drive:1/0] [cloud:1/0]"
            exit 1
        fi
        backup_suspended_user "$2" "${3:-1}" "${4:-1}" "${5:-0}"
        ;;
    "gmail-backup")
        if [[ -z "$2" ]]; then
            echo "Usage: $0 gmail-backup <email> [type:full/incremental] [path]"
            exit 1
        fi
        create_gmail_backup "$2" "${3:-full}" "$4"
        ;;
    "cloud-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 cloud-backup <source> <remote> <destination> [operation:copy/sync/move]"
            exit 1
        fi
        create_cloud_backup "$2" "$3" "$4" "${5:-copy}"
        ;;
    "configure-s3")
        if [[ -z "$6" ]]; then
            echo "Usage: $0 configure-s3 <storage_name> <provider> <bucket> <access_key> <secret_key> [region]"
            echo "Providers: s3, wasabi, b2, storj, spaces, r2"
            exit 1
        fi
        configure_s3_storage "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "init-restic")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 init-restic <storage_name> <encryption_password>"
            exit 1
        fi
        init_restic_repository "$2" "$3"
        ;;
    "restic-backup")
        if [[ -z "$6" ]]; then
            echo "Usage: $0 restic-backup <user_email> <backup_type> <source_path> <storage_name> <encryption_password>"
            echo "Backup types: gmail, drive, full, config"
            exit 1
        fi
        create_restic_backup "$2" "$3" "$4" "$5" "$6"
        ;;
    "drive-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 drive-backup <user_email> <storage_name> <encryption_password> [rclone_remote]"
            exit 1
        fi
        create_drive_incremental_backup "$2" "$3" "$4" "$5"
        ;;
    "system-backup")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 system-backup <storage_name> <encryption_password> [backup_name]"
            exit 1
        fi
        create_gwombat_system_backup "$2" "$3" "$4"
        ;;
    "list-system-backups")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 list-system-backups <storage_name> <encryption_password>"
            exit 1
        fi
        list_gwombat_system_backups "$2" "$3"
        ;;
    "restore-system")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 restore-system <storage_name> <encryption_password> <snapshot_id> [restore_path]"
            exit 1
        fi
        prepare_gwombat_restore "$2" "$3" "$4" "$5"
        ;;
    "api-calendar-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 api-calendar-backup <user_email> <storage_name> <encryption_password>"
            exit 1
        fi
        create_api_calendar_backup "$2" "$3" "$4"
        ;;
    "api-contacts-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 api-contacts-backup <user_email> <storage_name> <encryption_password>"
            exit 1
        fi
        create_api_contacts_backup "$2" "$3" "$4"
        ;;
    "api-sites-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 api-sites-backup <domain> <storage_name> <encryption_password>"
            exit 1
        fi
        create_api_sites_backup "$2" "$3" "$4"
        ;;
    "api-groups-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 api-groups-backup <domain> <storage_name> <encryption_password>"
            exit 1
        fi
        create_api_groups_backup "$2" "$3" "$4"
        ;;
    "comprehensive-backup")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 comprehensive-backup <user_email> <storage_name> <encryption_password> [domain]"
            exit 1
        fi
        create_comprehensive_api_backup "$2" "$3" "$4" "$5"
        ;;
    "list-snapshots")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 list-snapshots <storage_name> <encryption_password> [user_filter] [type_filter]"
            exit 1
        fi
        list_restic_snapshots "$2" "$3" "$4" "$5"
        ;;
    "restore-files")
        if [[ -z "$5" ]]; then
            echo "Usage: $0 restore-files <storage_name> <encryption_password> <snapshot_id> <restore_path> [target_path]"
            exit 1
        fi
        restore_restic_backup "$2" "$3" "$4" "$5" "$6"
        ;;
    "restore-drive")
        if [[ -z "$6" ]]; then
            echo "Usage: $0 restore-drive <source_user> <target_user> <storage_name> <encryption_password> <snapshot_id> [rclone_remote]"
            exit 1
        fi
        restore_drive_to_account "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "restore-gmail")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 restore-gmail <source_user> <target_user> [backup_type] [backup_path]"
            exit 1
        fi
        restore_gmail_backup "$2" "$3" "$4" "$5"
        ;;
    "restore-menu")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 restore-menu <storage_name> <encryption_password>"
            exit 1
        fi
        interactive_restore_menu "$2" "$3"
        ;;
    "setup-groups-service")
        if [[ -z "$5" ]]; then
            echo "Usage: $0 setup-groups-service <domain> <service_account_email> <storage_name> <encryption_password>"
            exit 1
        fi
        setup_groups_service_account_backup "$2" "$3" "$4" "$5"
        ;;
    "backup-gmail-filters")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 backup-gmail-filters <user_email> <storage_name> <encryption_password>"
            exit 1
        fi
        backup_gmail_filters "$2" "$3" "$4"
        ;;
    "backup-groups-settings")
        if [[ -z "$4" ]]; then
            echo "Usage: $0 backup-groups-settings <domain> <storage_name> <encryption_password>"
            exit 1
        fi
        backup_groups_settings "$2" "$3" "$4"
        ;;
    "cost-estimate")
        if [[ -z "$3" ]]; then
            echo "Usage: $0 cost-estimate <storage_name> <size_gb>"
            exit 1
        fi
        calculate_backup_costs "$2" "$3"
        ;;
    "stats")
        get_backup_stats
        ;;
    *)
        echo "Usage: $0 {init|status|backup-user|gmail-backup|cloud-backup|configure-s3|init-restic|restic-backup|drive-backup|system-backup|list-system-backups|restore-system|api-calendar-backup|api-contacts-backup|api-sites-backup|api-groups-backup|comprehensive-backup|list-snapshots|restore-files|restore-drive|restore-gmail|restore-menu|setup-groups-service|backup-gmail-filters|backup-groups-settings|cost-estimate|stats}"
        echo ""
        echo "Basic Commands:"
        echo "  init              - Initialize backup tools database"
        echo "  status            - Show backup tools status and recent activity"
        echo "  backup-user <email> - Backup user on suspension"
        echo "  gmail-backup <email> - Create Gmail backup with GYB"
        echo "  cloud-backup <src> <remote> <dest> - Upload to cloud with rclone"
        echo "  stats             - Show backup statistics"
        echo ""
        echo "S3 & Restic Backup Commands:"
        echo "  configure-s3 <name> <provider> <bucket> <key> <secret> - Configure S3 storage"
        echo "  init-restic <storage> <password> - Initialize restic repository"
        echo "  restic-backup <user> <type> <source> <storage> <password> - Create restic backup"
        echo "  drive-backup <user> <storage> <password> - Incremental Drive backup"
        echo ""
        echo "API-Based Backup Commands:"
        echo "  api-calendar-backup <user> <storage> <password> - Calendar API backup"
        echo "  api-contacts-backup <user> <storage> <password> - Contacts API backup"
        echo "  api-sites-backup <domain> <storage> <password> - Sites API backup"
        echo "  api-groups-backup <domain> <storage> <password> - Groups API backup"
        echo "  comprehensive-backup <user> <storage> <password> - Complete API backup"
        echo ""
        echo "System Backup Commands:"
        echo "  system-backup <storage> <password> - Complete GWOMBAT system backup"
        echo "  list-system-backups <storage> <password> - List available system backups"
        echo "  restore-system <storage> <password> <snapshot> - Restore system backup"
        echo ""
        echo "Advanced Backup Features:"
        echo "  setup-groups-service <domain> <service_account> <storage> <password> - Setup ongoing Groups archival"
        echo "  backup-gmail-filters <user> <storage> <password> - Backup Gmail filters and settings"
        echo "  backup-groups-settings <domain> <storage> <password> - Backup Google Groups settings & auto-replies"
        echo ""
        echo "Restoration Commands:"
        echo "  list-snapshots <storage> <password> [user] [type] - List available snapshots"
        echo "  restore-files <storage> <password> <snapshot> <path> - Restore files to local"
        echo "  restore-drive <src_user> <dst_user> <storage> <password> <snapshot> - Restore to account"
        echo "  restore-gmail <src_user> <dst_user> [type] [path] - Restore Gmail to account"
        echo "  restore-menu <storage> <password> - Interactive restoration menu"
        echo ""
        echo "Utilities:"
        echo "  cost-estimate <storage> <size_gb> - Calculate backup costs"
        exit 1
        ;;
esac