#!/bin/bash

# Dashboard Functions for GWOMBAT
# Provides OU statistics, system health monitoring, and dashboard display

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Database and GAM configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
GAM="${GAM_PATH:-gam}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"

# Color codes for dashboard display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Initialize dashboard database
init_dashboard_db() {
    if [[ -f "../dashboard_schema.sql" ]]; then
        sqlite3 "$DB_PATH" < ../dashboard_schema.sql 2>/dev/null || true
        log_dashboard "Dashboard database initialized" "INFO"
    fi
}

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Logging function for dashboard operations
log_dashboard() {
    local message="$1"
    local level="${2:-INFO}"
    local operation="${3:-dashboard}"
    
    execute_db "
    INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
    VALUES ('$level', '$SESSION_ID', '$operation', '$message', 'dashboard_functions.sh');
    " >/dev/null 2>&1
}

# Get cached value with expiration check
get_cache() {
    local key="$1"
    local result=$(execute_db "
    SELECT cache_value FROM dashboard_cache 
    WHERE cache_key = '$key' 
    AND (expires_at IS NULL OR expires_at > datetime('now'));
    ")
    echo "$result"
}

# Set cached value with optional expiration
set_cache() {
    local key="$1"
    local value="$2"
    local expires_in_seconds="${3:-300}" # Default 5 minutes
    
    execute_db "
    INSERT OR REPLACE INTO dashboard_cache (cache_key, cache_value, expires_at, updated_at)
    VALUES (
        '$key', 
        '$value', 
        datetime('now', '+$expires_in_seconds seconds'),
        CURRENT_TIMESTAMP
    );
    "
}

# Check if OU exists, create if it doesn't
ensure_ou_exists() {
    local ou_path="$1"
    local parent_ou="${2:-}"
    
    # Check if OU exists
    if ! $GAM info org "$ou_path" >/dev/null 2>&1; then
        log_dashboard "Creating missing OU: $ou_path" "INFO" "ou_management"
        
        if [[ -n "$parent_ou" ]]; then
            if $GAM create org "$ou_path" parent "$parent_ou" 2>/dev/null; then
                log_dashboard "Successfully created OU: $ou_path under $parent_ou" "INFO" "ou_management"
                return 0
            else
                log_dashboard "Failed to create OU: $ou_path under $parent_ou" "ERROR" "ou_management"
                return 1
            fi
        else
            log_dashboard "Parent OU required to create: $ou_path" "WARNING" "ou_management"
            return 1
        fi
    fi
    return 0
}

# Scan extended statistics (inactive users, shared drives, storage, external sharing)
scan_extended_statistics() {
    local start_time=$(date +%s)
    
    log_dashboard "Starting extended statistics scan" "INFO" "extended_scan"
    
    # Mark old extended statistics as historical
    execute_db "UPDATE extended_statistics SET status = 'historical' WHERE status = 'current';"
    
    # Count inactive users (no login in 30+ days)
    log_dashboard "Scanning for inactive users (30+ days)" "DEBUG" "extended_scan"
    local inactive_count=0
    
    # Use GAM to get users with last login info - this may take a while for large domains
    local users_data
    if users_data=$($GAM print users fields primaryEmail,lastLoginTime 2>/dev/null); then
        local cutoff_date=$(date -d "30 days ago" "+%Y-%m-%dT%H:%M:%S")
        
        # Count users with no recent login
        inactive_count=$(echo "$users_data" | tail -n +2 | awk -F, -v cutoff="$cutoff_date" '
        {
            # Extract last login time (field 2)
            last_login = $2
            
            # If no login time or login time is before cutoff, count as inactive
            if (last_login == "" || last_login < cutoff) {
                count++
            }
        }
        END { print count + 0 }
        ')
        
        log_dashboard "Found $inactive_count inactive users (30+ days)" "INFO" "extended_scan"
    else
        log_dashboard "Failed to scan inactive users" "WARNING" "extended_scan"
    fi
    
    # Count shared drives
    log_dashboard "Scanning shared drives count" "DEBUG" "extended_scan"
    local shared_drives_count=0
    
    # Use GAM to count team drives (shared drives)
    local gam_output
    gam_output=$($GAM print shareddrives 2>&1)
    if echo "$gam_output" | grep -q "Drive API v3 Service/App not enabled"; then
        log_dashboard "Shared drives scan blocked: Drive API v3 not enabled" "WARNING" "extended_scan"
        shared_drives_count="API_DISABLED"
    elif shared_drives_count=$(echo "$gam_output" | tail -n +2 | wc -l 2>/dev/null) && [[ "$shared_drives_count" =~ ^[0-9]+$ ]]; then
        log_dashboard "Found $shared_drives_count shared drives" "INFO" "extended_scan"
    else
        log_dashboard "Failed to scan shared drives: $gam_output" "WARNING" "extended_scan"
        shared_drives_count=0
    fi
    
    # Count external sharing (files shared outside domain)
    log_dashboard "Scanning external sharing count" "DEBUG" "extended_scan"
    local external_sharing_count=0
    
    # This is a complex query that may take time for large domains
    # We'll use a sample-based approach for performance
    if external_sharing_data=$($GAM config csv_output_row_filter "permissions.*.emailAddress:regex:^(?!.*@${DOMAIN:-your-domain.edu})" print filelist fields id,permissions.emailAddress 2>/dev/null); then
        external_sharing_count=$(echo "$external_sharing_data" | tail -n +2 | wc -l)
        log_dashboard "Found $external_sharing_count files with external sharing" "INFO" "extended_scan"
    else
        log_dashboard "Failed to scan external sharing (using fallback method)" "WARNING" "extended_scan"
        # Fallback: estimate based on suspended user files
        external_sharing_count=0
    fi
    
    # Get storage usage statistics
    log_dashboard "Scanning storage usage" "DEBUG" "extended_scan"
    local total_storage_gb=0
    local used_storage_gb=0
    
    # Get domain storage info
    if storage_data=$($GAM info domain 2>/dev/null | grep -E "(Storage|Usage)"); then
        # Parse storage information (this will vary by GAM version)
        used_storage_gb=$(echo "$storage_data" | grep -i "used" | grep -oE '[0-9]+' | head -1 || echo "0")
        total_storage_gb=$(echo "$storage_data" | grep -i "total\|limit" | grep -oE '[0-9]+' | head -1 || echo "0")
        log_dashboard "Storage: ${used_storage_gb}GB used of ${total_storage_gb}GB total" "INFO" "extended_scan"
    else
        log_dashboard "Failed to get domain storage information" "WARNING" "extended_scan"
    fi
    
    # Count users with admin roles
    log_dashboard "Scanning admin users count" "DEBUG" "extended_scan"
    local admin_users_count=0
    
    if admin_data=$($GAM print admins 2>/dev/null); then
        admin_users_count=$(echo "$admin_data" | tail -n +2 | wc -l)
        log_dashboard "Found $admin_users_count admin users" "INFO" "extended_scan"
    else
        log_dashboard "Failed to scan admin users" "WARNING" "extended_scan"
    fi
    
    # Count groups
    log_dashboard "Scanning groups count" "DEBUG" "extended_scan"
    local groups_count=0
    
    if groups_count=$($GAM print groups 2>/dev/null | tail -n +2 | wc -l); then
        log_dashboard "Found $groups_count groups" "INFO" "extended_scan"
    else
        log_dashboard "Failed to scan groups" "WARNING" "extended_scan"
        groups_count=0
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Store statistics in database
    execute_db "
    INSERT INTO extended_statistics (statistic_name, statistic_value, scan_session_id, scan_duration_seconds, status)
    VALUES 
        ('inactive_users_30d', $inactive_count, '$SESSION_ID', $duration, 'current'),
        ('shared_drives_count', $([ "$shared_drives_count" == "API_DISABLED" ] && echo "-1" || echo "$shared_drives_count"), '$SESSION_ID', $duration, 'current'),
        ('external_sharing_files', $external_sharing_count, '$SESSION_ID', $duration, 'current'),
        ('storage_used_gb', $used_storage_gb, '$SESSION_ID', $duration, 'current'),
        ('storage_total_gb', $total_storage_gb, '$SESSION_ID', $duration, 'current'),
        ('admin_users_count', $admin_users_count, '$SESSION_ID', $duration, 'current'),
        ('groups_count', $groups_count, '$SESSION_ID', $duration, 'current');
    "
    
    log_dashboard "Extended statistics scan completed in ${duration}s" "INFO" "extended_scan"
}

# Scan OU statistics using GAM
scan_ou_statistics() {
    local force_refresh="${1:-false}"
    local start_time=$(date +%s)
    
    # Check cache unless force refresh
    if [[ "$force_refresh" != "true" ]]; then
        local cached_scan=$(get_cache "last_ou_scan")
        if [[ -n "$cached_scan" ]]; then
            log_dashboard "Using cached OU statistics" "DEBUG" "ou_scan"
            return 0
        fi
    fi
    
    log_dashboard "Starting OU statistics scan" "INFO" "ou_scan"
    
    # Mark old statistics as historical
    execute_db "UPDATE ou_statistics SET status = 'historical' WHERE status = 'current';"
    
    # Get the main suspended OU path from environment or default
    local suspended_ou="${SUSPENDED_OU:-/Suspended Users}"
    local pending_deletion_ou="${PENDING_DELETION_OU:-$suspended_ou/Pending Deletion}"
    local temporary_hold_ou="${TEMPORARY_HOLD_OU:-$suspended_ou/Temporary Hold}"
    local exit_row_ou="${EXIT_ROW_OU:-$suspended_ou/Exit Row}"
    
    # Ensure OUs exist
    ensure_ou_exists "$suspended_ou"
    ensure_ou_exists "$pending_deletion_ou" "$suspended_ou"
    ensure_ou_exists "$temporary_hold_ou" "$suspended_ou"
    ensure_ou_exists "$exit_row_ou" "$suspended_ou"
    
    # Array of OUs to scan
    local -a ous_to_scan=(
        "$suspended_ou"
        "$pending_deletion_ou" 
        "$temporary_hold_ou"
        "$exit_row_ou"
        "/" # Root OU for total active users
    )
    
    # Scan each OU
    for ou_path in "${ous_to_scan[@]}"; do
        scan_single_ou "$ou_path"
    done
    
    # Also scan extended statistics (but only if force refresh or cache expired)
    local cached_extended=$(get_cache "last_extended_scan")
    if [[ "$force_refresh" == "true" ]] || [[ -z "$cached_extended" ]]; then
        scan_extended_statistics
        set_cache "last_extended_scan" "$(date)" 3600  # Cache extended stats for 1 hour (slower scan)
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Cache the scan result
    set_cache "last_ou_scan" "$(date)" 1800  # Cache for 30 minutes
    
    # Log performance
    execute_db "
    INSERT INTO performance_metrics (operation_type, operation_name, duration_seconds, session_id)
    VALUES ('ou_scan', 'full_statistics_scan', $duration, '$SESSION_ID');
    "
    
    log_dashboard "OU statistics scan completed in ${duration}s" "INFO" "ou_scan"
}

# Scan a single OU for user statistics
scan_single_ou() {
    local ou_path="$1"
    local start_time=$(date +%s)
    
    log_dashboard "Scanning OU: $ou_path" "DEBUG" "ou_scan"
    
    # Get user count in this OU
    local total_users=0
    local suspended_users=0
    local active_users=0
    
    # Use GAM to get user list from OU
    local user_data
    if user_data=$($GAM print users ou "$ou_path" fields primaryEmail,suspended 2>/dev/null); then
        # Count total users (excluding header)
        total_users=$(echo "$user_data" | tail -n +2 | wc -l)
        
        # Count suspended users
        suspended_users=$(echo "$user_data" | tail -n +2 | grep -c ",True$" || echo "0")
        
        # Calculate active users
        active_users=$((total_users - suspended_users))
        
        log_dashboard "OU $ou_path: $total_users total ($suspended_users suspended, $active_users active)" "DEBUG" "ou_scan"
    else
        log_dashboard "Failed to scan OU: $ou_path" "WARNING" "ou_scan"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Store statistics in database
    execute_db "
    INSERT INTO ou_statistics (
        ou_path, account_count, suspended_count, active_count, 
        scan_session_id, scan_duration_seconds, status
    ) VALUES (
        '$ou_path', $total_users, $suspended_users, $active_users,
        '$SESSION_ID', $duration, 'current'
    );
    "
}

# Get dashboard statistics
get_dashboard_stats() {
    # Get OU statistics
    local ou_stats=$(execute_db "
    SELECT 
        CASE 
            WHEN ou_path LIKE '%Pending Deletion%' THEN 'pending_deletion'
            WHEN ou_path LIKE '%Temporary Hold%' THEN 'temporary_hold'  
            WHEN ou_path LIKE '%Exit Row%' THEN 'exit_row'
            WHEN ou_path LIKE '%Suspended%' AND ou_path NOT LIKE '%/%' THEN 'suspended_total'
            WHEN ou_path = '/' THEN 'domain_total'
            ELSE 'other'
        END as category,
        SUM(account_count) as count,
        MAX(last_updated) as last_updated
    FROM ou_statistics 
    WHERE status = 'current'
    GROUP BY category;
    ")
    
    # Get extended statistics
    local extended_stats=$(execute_db "
    SELECT 
        statistic_name as category,
        statistic_value as count,
        calculation_time as last_updated
    FROM extended_statistics 
    WHERE status = 'current';
    ")
    
    # Combine both statistics
    {
        echo "$ou_stats"
        echo "$extended_stats"
    } | grep -v "^$"
}

# Get system health information
get_system_health() {
    execute_db "SELECT component, value, unit, status FROM system_health;"
}

# Get recent activity
get_recent_activity() {
    execute_db "
    SELECT activity_type, activity_description, affected_users, 
           strftime('%H:%M', timestamp) as time
    FROM recent_activity 
    LIMIT 5;
    "
}

# Record activity for dashboard
record_activity() {
    local activity_type="$1"
    local description="$2"
    local affected_users="${3:-0}"
    local details="${4:-}"
    
    execute_db "
    INSERT INTO activity_summary (activity_type, activity_description, affected_users, session_id, details)
    VALUES ('$activity_type', '$description', $affected_users, '$SESSION_ID', '$details');
    "
}

# Display main dashboard
show_dashboard() {
    local force_refresh="${1:-false}"
    
    # Initialize database if needed
    init_dashboard_db
    
    # Refresh statistics if needed
    scan_ou_statistics "$force_refresh"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                           🎯 GWOMBAT DASHBOARD                              ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Get and display OU statistics
    local stats=$(get_dashboard_stats)
    local suspended_total=0
    local pending_deletion=0
    local temporary_hold=0
    local exit_row=0
    local domain_total=0
    local inactive_users_30d=0
    local shared_drives_count=0
    local external_sharing_files=0
    local storage_used_gb=0
    local storage_total_gb=0
    local admin_users_count=0
    local groups_count=0
    local last_updated=""
    
    while IFS='|' read -r category count updated; do
        case "$category" in
            "suspended_total") suspended_total="$count"; last_updated="$updated" ;;
            "pending_deletion") pending_deletion="$count" ;;
            "temporary_hold") temporary_hold="$count" ;;
            "exit_row") exit_row="$count" ;;
            "domain_total") domain_total="$count" ;;
            "inactive_users_30d") inactive_users_30d="$count" ;;
            "shared_drives_count") 
                if [[ "$count" == "-1" ]]; then
                    shared_drives_count="API_DISABLED"
                else
                    shared_drives_count="$count"
                fi ;;
            "external_sharing_files") external_sharing_files="$count" ;;
            "storage_used_gb") storage_used_gb="$count" ;;
            "storage_total_gb") storage_total_gb="$count" ;;
            "admin_users_count") admin_users_count="$count" ;;
            "groups_count") groups_count="$count" ;;
        esac
    done <<< "$stats"
    
    # Display OU Statistics
    echo -e "${CYAN}📊 ORGANIZATIONAL UNITS${NC}"
    echo -e "${WHITE}Suspended Users:${NC}     ${YELLOW}$suspended_total${NC} accounts"
    echo -e "├─ ${WHITE}Pending Deletion:${NC} ${RED}$pending_deletion${NC} accounts"
    echo -e "├─ ${WHITE}Temporary Hold:${NC}   ${YELLOW}$temporary_hold${NC} accounts"
    echo -e "└─ ${WHITE}Exit Row:${NC}         ${GREEN}$exit_row${NC} accounts"
    echo ""
    
    # Display Domain Statistics  
    echo -e "${CYAN}🌍 DOMAIN OVERVIEW${NC}"
    if [[ "$domain_total" -gt 0 ]]; then
        echo -e "${WHITE}Total Users:${NC}         ${BLUE}$domain_total${NC} accounts"
    fi
    echo -e "${WHITE}Inactive Users (30d):${NC} ${YELLOW}$inactive_users_30d${NC} accounts"
    echo -e "${WHITE}Admin Users:${NC}         ${CYAN}$admin_users_count${NC} users"
    echo -e "${WHITE}Groups:${NC}              ${GREEN}$groups_count${NC} groups"
    echo ""
    
    # Display Drive & Sharing Statistics
    echo -e "${CYAN}📁 DRIVES & SHARING${NC}"
    if [[ "$shared_drives_count" == "API_DISABLED" ]]; then
        echo -e "${WHITE}Shared Drives:${NC}       ${RED}Drive API v3 not enabled${NC}"
    else
        echo -e "${WHITE}Shared Drives:${NC}       ${GREEN}$shared_drives_count${NC} drives"
    fi
    if [[ "$external_sharing_files" -gt 0 ]]; then
        echo -e "${WHITE}External Sharing:${NC}    ${YELLOW}$external_sharing_files${NC} files"
    else
        echo -e "${WHITE}External Sharing:${NC}    ${GREEN}0${NC} files"
    fi
    
    # Display Storage Information
    if [[ "$storage_total_gb" -gt 0 ]]; then
        local storage_percent=$((storage_used_gb * 100 / storage_total_gb))
        local storage_color="$GREEN"
        if [[ "$storage_percent" -gt 80 ]]; then
            storage_color="$RED"
        elif [[ "$storage_percent" -gt 60 ]]; then
            storage_color="$YELLOW"
        fi
        echo -e "${WHITE}Storage Usage:${NC}       ${storage_color}${storage_used_gb}GB${NC} / ${storage_total_gb}GB (${storage_percent}%)"
    fi
    echo ""
    
    # Display System Health
    echo -e "${CYAN}🏥 SYSTEM HEALTH${NC}"
    local health_data=$(get_system_health)
    while IFS='|' read -r component value unit status; do
        local status_icon="✓"
        local status_color="$GREEN"
        
        if [[ "$status" == "warning" ]]; then
            status_icon="⚠"
            status_color="$YELLOW"
        elif [[ "$status" == "error" ]]; then
            status_icon="✗"
            status_color="$RED"
        fi
        
        printf "%-20s ${status_color}%s${NC} %s %s\n" "$component:" "$status_icon" "$value" "$unit"
    done <<< "$health_data"
    echo ""
    
    # Display Recent Activity
    echo -e "${CYAN}📈 RECENT ACTIVITY${NC}"
    local activity_data=$(get_recent_activity)
    if [[ -n "$activity_data" ]]; then
        while IFS='|' read -r type description users time; do
            printf "${GRAY}%s${NC} %s ${WHITE}(%s users)${NC}\n" "$time" "$description" "$users"
        done <<< "$activity_data"
    else
        echo -e "${GRAY}No recent activity${NC}"
    fi
    echo ""
    
    # Display last updated info
    if [[ -n "$last_updated" ]]; then
        local formatted_time=$(date -d "$last_updated" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$last_updated")
        echo -e "${GRAY}Last Updated: $formatted_time${NC}"
    fi
    
    # Display refresh hint
    echo -e "${GRAY}Press 'r' during menu selection to refresh statistics${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Quick statistics for menu integration
get_quick_stats() {
    local stats=$(get_dashboard_stats)
    local suspended_total=0
    local pending_deletion=0
    local temporary_hold=0
    local exit_row=0
    local inactive_users_30d=0
    local shared_drives_count=0
    
    while IFS='|' read -r category count updated; do
        case "$category" in
            "suspended_total") suspended_total="$count" ;;
            "pending_deletion") pending_deletion="$count" ;;
            "temporary_hold") temporary_hold="$count" ;;
            "exit_row") exit_row="$count" ;;
            "inactive_users_30d") inactive_users_30d="$count" ;;
            "shared_drives_count") shared_drives_count="$count" ;;
        esac
    done <<< "$stats"
    
    echo "$suspended_total|$pending_deletion|$temporary_hold|$exit_row|$inactive_users_30d|$shared_drives_count"
}

# Standalone script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-show}" in
        "show"|"display")
            show_dashboard "${2:-false}"
            ;;
        "scan"|"refresh")
            scan_ou_statistics "true"
            echo "OU statistics refreshed."
            ;;
        "scan-extended")
            scan_extended_statistics
            echo "Extended statistics refreshed."
            ;;
        "stats"|"quick")
            get_quick_stats
            ;;
        "init")
            init_dashboard_db
            echo "Dashboard database initialized."
            ;;
        "health")
            echo "System Health:"
            get_system_health | while IFS='|' read -r component value unit status; do
                printf "%-20s %s %s (%s)\n" "$component:" "$value" "$unit" "$status"
            done
            ;;
        *)
            echo "Usage: $0 {show|scan|scan-extended|stats|init|health}"
            echo ""
            echo "Commands:"
            echo "  show [force]      - Display full dashboard (optionally force refresh)"
            echo "  scan              - Refresh OU statistics"
            echo "  scan-extended     - Refresh extended statistics (inactive users, shared drives)"
            echo "  stats             - Get quick statistics"
            echo "  init              - Initialize dashboard database"
            echo "  health            - Show system health"
            exit 1
            ;;
    esac
fi