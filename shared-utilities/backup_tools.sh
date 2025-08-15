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

# Default backup locations
BACKUP_BASE_PATH="${BACKUP_BASE_PATH:-./backups}"
GMAIL_BACKUP_PATH="${GMAIL_BACKUP_PATH:-$BACKUP_BASE_PATH/gmail}"
DRIVE_BACKUP_PATH="${DRIVE_BACKUP_PATH:-$BACKUP_BASE_PATH/drive}"

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
    
    if command -v "$GYB_PATH" >/dev/null 2>&1; then
        gyb_available=1
        GYB_VERSION=$($GYB_PATH --version 2>/dev/null | head -1 || echo "unknown")
    fi
    
    if command -v "$RCLONE_PATH" >/dev/null 2>&1; then
        rclone_available=1
        RCLONE_VERSION=$($RCLONE_PATH --version 2>/dev/null | head -1 || echo "unknown")
    fi
    
    echo "$gyb_available|$rclone_available|$GYB_VERSION|$RCLONE_VERSION"
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
    "stats")
        get_backup_stats
        ;;
    *)
        echo "Usage: $0 {init|status|backup-user|gmail-backup|cloud-backup|stats}"
        echo ""
        echo "Commands:"
        echo "  init              - Initialize backup tools database"
        echo "  status            - Show backup tools status and recent activity"
        echo "  backup-user <email> - Backup user on suspension"
        echo "  gmail-backup <email> - Create Gmail backup with GYB"
        echo "  cloud-backup <src> <remote> <dest> - Upload to cloud with rclone"
        echo "  stats             - Show backup statistics"
        exit 1
        ;;
esac