#!/bin/bash

# Temporary Hold Master Script
#
# A comprehensive script that consolidates all temporary hold operations for suspended user accounts into a single interactive tool with preview functionality.
#
# ## Overview
#
# This script automates the process of moving user accounts between different suspension states:
# - Moving from "pending deletion" status to "temporary hold" status
# - Removing "temporary hold" status to restore normal account state
#
# **Add Temporary Hold Operations:**
# 1. **Restore Last Name** - Removes "(PENDING DELETION - CONTACT OIT)" from user's last name
# 2. **Fix Filenames** - Renames files with pending deletion markers
# 3. **Rename All Files** - Adds "(Suspended Account - Temporary Hold)" to all user files
# 4. **Update User Last Name** - Adds suspension marker to user's last name
#
# **Remove Temporary Hold Operations:**
# 1. **Remove Temporary Hold from Last Name** - Removes "(Suspended Account - Temporary Hold)" from user's last name
# 2. **Remove Temporary Hold from All Files** - Removes suspension markers from all file names
#
# ## Features
#
# - **Interactive Menu System** - Choose between single user or batch processing
# - **Bidirectional Operations** - Add or remove temporary hold status
# - **Dry-Run Mode** - Preview changes without making actual modifications
# - **Recovery Mode** - Check for incomplete operations and resume failed batches
# - **Enhanced Confirmation** - Different confirmation levels based on operation risk
# - **Progress Tracking** - Visual progress bars for all operations
# - **Backup Creation** - Automatic backups before making changes
# - **Preview Mode** - Shows detailed summary of all actions before execution
# - **Error Handling** - Validates inputs and checks for required directories
# - **Comprehensive Logging** - Records all operations and changes
# - **Color-coded Output** - Easy-to-read status messages
#
# ## Prerequisites
#
# - GAM (Google Apps Manager) installed at `/usr/local/bin/gam`
# - Access to the following directories:
#   - `/opt/your-path/mjb9/suspended` (script path)
#   - `/opt/your-path/mjb9/listshared` (shared files path)
# - Required script dependencies:
#   - `list-users-files.sh` in the listshared directory
#
# ## Installation
#
# 1. Ensure the script is executable:
#    ```bash
#    chmod +x master-temphold.sh
#    ```
#
# 2. Verify GAM is installed and accessible:
#    ```bash
#    /usr/local/bin/gam version
#    ```
#
# 3. Check that required directories exist and are accessible
#
# ## Usage
#
# ### Interactive Mode
#
# Run the script without arguments to enter interactive mode:
#
# ```bash
# ./master-temphold.sh
# ```
#
# ### Menu Options
#
# 1. **Process single user**
#    - Enter a single username or email address
#    - Choose to add or remove temporary hold
#    - View summary of actions before execution
#    - Confirm before making changes
#
# 2. **Process users from file**
#    - Specify path to file containing usernames (one per line)
#    - Choose to add or remove temporary hold for all users
#    - Preview sample users from file
#    - Batch process all users with selected operation
#
# 3. **Dry-run mode (Preview changes without making them)**
#    - Test operations without making actual changes
#    - Preview single user or batch operations
#    - Simulate file processing and user updates
#    - Choose add or remove operations for testing
#
# 4. **Discovery mode (Query and diagnose accounts)**
#    - Query users in Temporary Hold OU
#    - Query users in Pending Deletion OU  
#    - Query all suspended users across all OUs
#    - Scan active accounts for orphaned pending deletion files
#    - Query users by department/type (Student, Faculty, Staff)
#    - Custom GAM queries with examples
#    - Diagnose specific account consistency
#    - Bulk operations on query results
#    - Bulk cleanup of orphaned files
#    - Check for incomplete operations
#
# 5. **Exit**
#    - Safely exit the script
#
# ### File Format for Batch Processing
#
# Create a text file with one username/email per line:
#
# ```
# user1@domain.com
# user2@domain.com
# user3@domain.com
# ```
#
# - Empty lines and lines starting with `#` are ignored
# - Each user will go through the complete 4-step process
#
# ## Process Details
#
# ### Step 1: Restore Last Name
# - Checks if user's last name contains "(PENDING DELETION - CONTACT OIT)"
# - If found, removes the suffix and restores original last name
# - If not found, skips this step
#
# ### Step 2: Fix Filenames
# - Searches for files with "(PENDING DELETION - CONTACT OIT)" in filename
# - Renames them to include "(Suspended Account - Temporary Hold)"
# - Logs all changes to `tmp/{username}-fixed.txt`
#
# ### Step 3: Rename Shared Files (Security-Focused)
# - Generates comprehensive file list using `list-users-files.sh`
# - **ONLY processes files shared with active your-domain.edu accounts**
# - Skips files shared externally or with already suspended accounts
# - Adds "(Suspended Account - Temporary Hold)" suffix to qualified file names
# - Skips files that already have the suffix
#
# ### Step 4: Update User Last Name
# - Adds "(Suspended Account - Temporary Hold)" to user's last name
# - Skips if suffix already present
#
# ## Output and Logging
#
# ### Log Files Created:
# - `temphold-done.log` - Users successfully processed (temporary hold added)
# - `temphold-removed.log` - Users successfully processed (temporary hold removed)
# - `file-rename-done.txt` - Timestamp log of file rename operations (adding hold)
# - `file-removal-done.txt` - Timestamp log of file removal operations (removing hold)
# - `tmp/{username}-fixed.txt` - Detailed log of specific file changes (adding hold)
# - `tmp/{username}-removal.txt` - Detailed log of specific file changes (removing hold)
#
# ### Temporary Files:
# - `tmp/gam_output_{username}.txt` - GAM query results
# - CSV files in `${SCRIPTPATH}/csv-files/` directory
#
# ## Error Handling
#
# The script includes comprehensive error checking:
#
# - Validates user input
# - Checks file existence for batch processing
# - Verifies required directories exist
# - Handles GAM command failures gracefully
# - Provides clear error messages
#
# ## Color Coding
#
# - 🔵 **Blue**: Headers and informational messages
# - 🟢 **Green**: Success messages and step indicators
# - 🟡 **Yellow**: Warnings and progress indicators
# - 🔴 **Red**: Error messages
#
# ## Safety Features
#
# - **Preview Mode**: Shows exactly what will happen before execution
# - **User Confirmation**: Requires explicit approval before making changes
# - **Non-destructive**: Only adds suffixes, doesn't delete data
# - **Logging**: Complete audit trail of all operations
# - **Validation**: Checks for existing suffixes to prevent duplicates
#
# ## Troubleshooting
#
# ### Common Issues:
#
# 1. **GAM not found**
#    - Verify GAM is installed at `/usr/local/bin/gam`
#    - Check PATH environment variable
#
# 2. **Permission denied**
#    - Ensure script has execute permissions
#    - Check directory access permissions
#
# 3. **Required directories missing**
#    - Verify `/opt/your-path/mjb9/suspended` exists
#    - Verify `/opt/your-path/mjb9/listshared` exists
#
# 4. **list-users-files.sh not found**
#    - Ensure the script exists in the listshared directory
#    - Check execute permissions on the script
#
# ### Debug Mode:
#
# To enable verbose output, you can modify the script to add `set -x` at the top for debugging.
#
# ## Author
#
# Consolidated from multiple individual scripts:
# - `temphold.sh`
# - `restore-lastname.sh`
# - `temphold-filesfix.sh`
# - `temphold-file-rename.sh`
# - `temphold-namechange.sh`
#
# ## Version History
#
# - v1.0 - Initial consolidated version with interactive menu and preview functionality

# Master Temporary Hold Script
# Consolidates all temphold operations with menu system and preview functionality

# Variables now loaded via load_configuration() function

# Organizational Unit paths
OU_TEMPHOLD="/Suspended Accounts/Suspended - Temporary Hold"
OU_PENDING_DELETION="/Suspended Accounts/Suspended - Pending Deletion"  
OU_SUSPENDED="/Suspended Accounts"
OU_ACTIVE="/your-domain.edu"

# Google Drive Label IDs for pending deletion
LABEL_ID="xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb"

# Advanced Logging and Reporting Configuration
LOG_DIR="./logs"
BACKUP_DIR="./backups"
REPORT_DIR="./reports"
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$REPORT_DIR"

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
CONFIG_FILE="./config/temphold-config.json"
CONFIG_DIR="./config"
mkdir -p "$CONFIG_DIR"

# Load configuration from file or set defaults
load_configuration() {
    # Set default values
    DEFAULT_GAM_PATH="/usr/local/bin/gam"
    DEFAULT_SCRIPT_PATH="/Users/mjb9/mjb9-gamera/suspended/temphold-master"
    #DEFAULT_SCRIPT_PATH="/opt/your-path/mjb9/suspended/"
    DEFAULT_SHARED_UTILITIES_PATH="shared-utilities"
    DEFAULT_PROGRESS_ENABLED="true"
    DEFAULT_CONFIRMATION_LEVEL="normal"
    DEFAULT_LOG_RETENTION_DAYS="30"
    DEFAULT_BACKUP_RETENTION_DAYS="90"
    DEFAULT_OPERATION_TIMEOUT="300"
    
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
  "description": "Temporary Hold Master Script Configuration",
  "created": "$(date -Iseconds)",
  "settings": {
    "gam_path": "/usr/local/bin/gam",
    "script_path": "/opt/your-path/mjb9/suspended",
    "listshared_path": "/opt/your-path/mjb9/listshared",
    "progress_enabled": "true",
    "confirmation_level": "normal",
    "log_retention_days": "30",
    "backup_retention_days": "90",
    "operation_timeout": "300"
  },
  "organizational_units": {
    "temphold": "/Suspended Accounts/Suspended - Temporary Hold",
    "pending_deletion": "/Suspended Accounts/Suspended - Pending Deletion",
    "suspended": "/Suspended Accounts",
    "active": "/your-domain.edu"
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
echo "Script Version: Master Temporary Hold Script v2.0" >> "$LOG_FILE"
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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
            grep -o "add_temphold\|remove_temphold\|add_pending\|remove_pending" "$OPERATION_LOG" 2>/dev/null | sort | uniq -c | sort -nr || echo "No operations found"
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
        echo "8. View backup files"
        echo "9. Configuration management"
        echo "10. Audit file ownership locations"
        echo "11. Return to main menu"
        echo ""
        read -p "Select an option (1-11): " report_choice
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
            6)
                echo -e "${CYAN}Cleaning up logs older than 30 days...${NC}"
                cleanup_logs 30
                echo -e "${GREEN}Cleanup completed${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
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
            8)
                echo -e "${CYAN}Recent backup files:${NC}"
                if [[ -d "$BACKUP_DIR" ]]; then
                    ls -la "$BACKUP_DIR" | tail -10
                    echo ""
                    echo -e "${YELLOW}(Showing 10 most recent backups)${NC}"
                else
                    echo "No backup directory found"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            9)
                configuration_menu
                ;;
            10)
                audit_file_ownership_menu
                ;;
            11)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-11.${NC}"
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
        echo -e "${CYAN}Current Configuration:${NC}"
        echo "GAM Path: $GAM"
        echo "Script Path: $SCRIPTPATH"
        echo "Shared Utilities Path: $SHARED_UTILITIES_PATH"
        echo "Progress Enabled: $PROGRESS_ENABLED"
        echo "Confirmation Level: $CONFIRMATION_LEVEL"
        echo "Log Retention: $LOG_RETENTION_DAYS days"
        echo "Backup Retention: $BACKUP_RETENTION_DAYS days"
        echo "Operation Timeout: $OPERATION_TIMEOUT seconds"
        echo ""
        echo "Configuration Options:"
        echo "1. View full configuration file"
        echo "2. Create default configuration file"
        echo "3. Edit GAM path"
        echo "4. Edit script paths"
        echo "5. Toggle progress display"
        echo "6. Change confirmation level"
        echo "7. Set log retention"
        echo "8. Set backup retention"
        echo "9. Test configuration"
        echo "10. Reset to defaults"
        echo "11. Return to previous menu"
        echo ""
        read -p "Select an option (1-11): " config_choice
        echo ""
        
        case $config_choice in
            1)
                echo -e "${CYAN}Configuration file contents:${NC}"
                if [[ -f "$CONFIG_FILE" ]]; then
                    cat "$CONFIG_FILE"
                else
                    echo "No configuration file found at $CONFIG_FILE"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${CYAN}Creating default configuration file...${NC}"
                create_default_config
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
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
            4)
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
            5)
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
            6)
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
            7)
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
            8)
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
            9)
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
            10)
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
            11)
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-11.${NC}"
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

# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${BLUE}=== Suspended Account Lifecycle Management ===${NC}"
    echo ""
    echo -e "${YELLOW}Account Lifecycle Stages:${NC}"
    echo -e "${CYAN}1. Recently Suspended ${NC}→ 2. Pending Deletion → 3. Share Analysis → 4. Final Decisions → 5. Deletion${NC}"
    echo ""
    echo -e "${GREEN}=== LIFECYCLE OPERATIONS ===${NC}"
    echo "1. 📋 Stage 1: Manage Recently Suspended Accounts"
    echo "2. 🔄 Stage 2: Process Pending Deletion (Rename & Label)"
    echo "3. 📊 Stage 3: File Sharing Analysis & Reports"
    echo "4. 🎯 Stage 4: Final Decisions (Exit Row / Temporary Hold)"
    echo "5. 🗑️  Stage 5: Account Deletion Operations"
    echo ""
    echo -e "${BLUE}=== UTILITIES & TOOLS ===${NC}"
    echo "6. 🔍 Discovery & Query Tools"
    echo "7. 🛠️  Administrative Tools & Cleanup"
    echo "8. 📈 Reports & Monitoring"
    echo "9. ❌ Exit"
    echo ""
    read -p "Select an option (1-9): " choice
    echo ""
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
            1) echo "add_temphold"; break ;;
            2) echo "remove_temphold"; break ;;
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
        echo -e "${CYAN}Org Unit:${NC} /your-domain.edu (simulated)"
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
        
        # Add @your-domain.edu if just username provided
        if [[ "$user_input" != *"@"* ]]; then
            user_input="${user_input}@your-domain.edu"
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
        
        # Add @your-domain.edu if just username provided
        if [[ "$user_input" != *"@"* ]]; then
            user_input="${user_input}@your-domain.edu"
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
        "add_temphold")
            if [[ "$lastname" == *"(Suspended Account - Temporary Hold)"* ]]; then
                echo -e "${YELLOW}Warning: User $user already has temporary hold marker. Skip? (y/n)${NC}"
                read -p "> " skip
                [[ "$skip" =~ ^[Yy] ]] && return 2  # Return 2 for skip
            fi
            ;;
        "remove_temphold")
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
    echo "   - Filter for files shared with active your-domain.edu accounts ONLY"
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
    echo "   - Add user to temphold-done.log"
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
    echo "   - Choose destination: Pending Deletion, Suspended, or your-domain.edu"
    echo "   - Move user to selected organizational unit"
    echo "   - If moving to your-domain.edu, offer to restore groups from backup"
    echo ""
    echo -e "${GREEN}4. Logging:${NC}"
    echo "   - Add user to temphold-removed.log"
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
    echo "   - Choose destination: Pending Deletion, Suspended, or your-domain.edu"
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
                "add_temphold")
                    show_summary "$user"
                    process_user "$user"
                    ;;
                "remove_temphold")
                    show_removal_summary "$user"
                    remove_temphold_user "$user"
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
                "add_temphold")
                    process_users_from_file "$file_path"
                    ;;
                "remove_temphold")
                    remove_temphold_users_from_file "$file_path"
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
    local admin_user="gamadmin@your-domain.edu"
    echo -e "${CYAN}Adding admin access to shared drive...${NC}"
    if ! $GAM user "$admin_user" add drivefileacl "$drive_id" user "$admin_user" role editor asadmin 2>/dev/null; then
        echo -e "${RED}Error: Failed to add admin access to shared drive${NC}"
        return 1
    fi
    
    # Create temporary file for file list
    local tempfile=$(mktemp)
    local logfile="logs/${drive_id}-cleanup.txt"
    
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
        
        echo "$files_with_markers" | while IFS=, read -r owner fileid filename; do
            ((count++))
            local new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            
            if [[ "$new_filename" != "$filename" ]]; then
                echo -e "${CYAN}[$count/$total_files] Processing: $filename${NC}"
                
                if $GAM user "$owner" update drivefile "$fileid" newfilename "$new_filename" 2>/dev/null; then
                    echo -e "${GREEN}Renamed: $filename -> $new_filename${NC}"
                    echo "SUCCESS: $fileid,$filename,$new_filename" >> "$logfile"
                    ((success_count++))
                    
                    # Remove pending deletion label if it exists
                    if [[ -n "$fileid" ]]; then
                        $GAM user gamadmin process filedrivelabels "$fileid" deletelabelfield xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb 62BB395EC6 2>/dev/null | grep -q "Deleted" && echo "Label removed" || true
                    fi
                else
                    echo -e "${RED}Failed to rename: $filename${NC}"
                    echo "ERROR: $fileid,$filename,Failed to rename" >> "$logfile"
                fi
            else
                ((skip_count++))
            fi
        done
        
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

shared_drive_cleanup_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== Shared Drive & Account Management Operations ===${NC}"
        echo ""
        echo -e "${GREEN}=== SHARED DRIVE OPERATIONS ===${NC}"
        echo "1. Clean shared drive (remove all pending deletion markers)"
        echo "2. Remove pending deletion markers (interactive)"
        echo "3. Grant gamadmin access to shared drive files"
        echo "4. Create archived shared drive for user"
        echo ""
        echo -e "${GREEN}=== ACCOUNT ANALYSIS ===${NC}"
        echo "5. Analyze accounts with no file sharing"
        echo "6. File activity analysis (recent vs old files)"
        echo "7. Transfer file ownership to gamadmin"
        echo ""
        echo -e "${GREEN}=== GROUP & DATE MANAGEMENT ===${NC}"
        echo "8. Backup/restore user group memberships"
        echo "9. Restore file modification dates"
        echo ""
        echo "10. Dry-run: Preview cleanup operations"
        echo "11. Return to administrative tools menu"
        echo ""
        read -p "Select an option (1-11): " cleanup_choice
        echo ""
        
        case $cleanup_choice in
            1)
                read -p "Enter shared drive ID: " drive_id
                if [[ -n "$drive_id" ]]; then
                    cleanup_shared_drive "$drive_id" false
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            2)
                read -p "Enter shared drive ID: " drive_id
                if [[ -n "$drive_id" ]]; then
                    remove_pending_from_shared_drive "$drive_id" false
                    echo ""
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}Drive ID cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            3)
                read -p "Enter shared drive ID for preview: " drive_id
                if [[ -n "$drive_id" ]]; then
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
                read -p "Enter shared drive ID: " drive_id
                if [[ -n "$drive_id" ]]; then
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
            6)
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
            7)
                read -p "Enter user email: " user_email
                if [[ -n "$user_email" ]]; then
                    echo -e "${YELLOW}This will transfer ALL files from $user_email to gamadmin${NC}"
                    read -p "Are you sure? (yes/no): " confirm
                    if [[ "$confirm" == "yes" ]]; then
                        transfer_ownership_to_gamadmin "$user_email"
                    else
                        echo "Operation cancelled"
                    fi
                    read -p "Press Enter to continue..."
                else
                    echo -e "${RED}User email cannot be empty${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            8)
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
            9)
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
            10)
                read -p "Enter shared drive ID for preview: " drive_id
                if [[ -n "$drive_id" ]]; then
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
            11)
                return
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-11.${NC}"
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
    
    local gam_command="$GAM user $username collect orphans targetuserfoldername \"$target_folder\""
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
    echo -e "${GREEN}Found $active_count files shared with active your-domain.edu accounts${NC}"
    
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
    tail -n +2 "$shared_with_emails_csv" | cut -d, -f8 | grep "@your-domain.edu" | sort -u > "$temp_emails"
    
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
    echo -e "${GREEN}Found $active_count active your-domain.edu recipients${NC}"
    
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
        
        echo "Total files shared with active your-domain.edu accounts: $total_shared"
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
    for report in reports/*_files_from_*.csv; do
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
    local combined_report="reports/${recipient_email}_combined_pending_files.csv"
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
    local summary_file="reports/${recipient_email}_summary.txt"
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
        echo "active your-domain.edu users, generating detailed reports."
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
            6)
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
            7)
                echo -e "${CYAN}File Sharing Analysis Statistics${NC}"
                echo ""
                
                # Count analysis files
                local user_analyses=$(ls listshared/*_all_files.csv 2>/dev/null | wc -l)
                local sharing_analyses=$(ls listshared/*_shared_files.csv 2>/dev/null | wc -l)
                local active_analyses=$(ls listshared/*_active-shares.csv 2>/dev/null | wc -l)
                local recipient_reports=$(ls reports/*_files_from_*.csv 2>/dev/null | wc -l)
                
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
            8)
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
    echo "12. Return to main menu"
    echo ""
    read -p "Select an option (1-12): " discovery_choice
    
    case $discovery_choice in
        1) 
            query_temphold_users
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
    esac
    
    DISCOVERY_MODE=false
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Function to check for incomplete operations
check_incomplete_operations() {
    echo -e "${YELLOW}Checking for incomplete operations...${NC}"
    
    # Check for partial log entries
    if [[ -f "${SCRIPTPATH}/temphold-done.log" ]]; then
        echo "Users in temphold-done.log: $(wc -l < "${SCRIPTPATH}/temphold-done.log")"
    fi
    
    if [[ -f "${SCRIPTPATH}/temphold-removed.log" ]]; then
        echo "Users in temphold-removed.log: $(wc -l < "${SCRIPTPATH}/temphold-removed.log")"
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
        if [[ "$permissions" == *"@your-domain.edu"* ]] || [[ "$permissions" == *"anyone"* ]]; then
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
        local file_info=$($GAM user "gamadmin@your-domain.edu" show fileinfo "$current_id" fields name,parents 2>/dev/null)
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
    
    echo "Filtering for files shared with active your-domain.edu accounts..."
    
    # Create header for output file
    head -n 1 "$input_file" > "$output_file"
    
    # Process each line and check if shared with active users
    tail -n +2 "$input_file" | while IFS=',' read -r line; do
        local shared_with=$(echo "$line" | cut -d',' -f8)
        local has_active_share=false
        
        # Extract email addresses from sharing permissions
        local emails=$(echo "$shared_with" | grep -oE '[a-zA-Z0-9._%+-]+@williams\.edu')
        
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
    echo "Found $active_count files shared with active your-domain.edu accounts"
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

# Function to transfer ownership of files to gamadmin
transfer_ownership_to_gamadmin() {
    local user_email="$1"
    local dry_run="${2:-false}"
    
    echo -e "${GREEN}Transferring file ownership from $user_email to gamadmin...${NC}"
    
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
            if [[ "$owner_email" != *"@your-domain.edu" ]]; then
                echo "  External file detected - copying instead of transferring: $file_name"
                $GAM user gamadmin@your-domain.edu add drivefile copy "$file_id" parentname "Copied Files from External Accounts"
            else
                $GAM user "$user_email" add drivefileacl "$file_id" user gamadmin@your-domain.edu role owner transferownership true
            fi
        done
    else
        echo -e "${CYAN}[DRY-RUN] Would transfer ownership of all files from $user_email to gamadmin${NC}"
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
    local csv_output="${SCRIPTPATH}/csv-files/accounts_no_sharing_$(date +%Y%m%d_%H%M).csv"
    
    echo -e "${GREEN}Analyzing accounts with no file sharing...${NC}"
    echo "owner,hasSharingFiles,totalFiles,totalStorage" > "$csv_output"
    
    local user_list=""
    case $scope in
        "suspended")
            user_list=$($GAM print users query "isSuspended=true" fields email | tail -n +2 | cut -d',' -f1)
            ;;
        "ou")
            user_list=$($GAM print users query "orgUnitPath='/Suspended Accounts'" fields email | tail -n +2 | cut -d',' -f1)
            ;;
    esac
    
    local counter=0
    local total_users=$(echo "$user_list" | wc -l)
    
    echo "$user_list" | while read user_email; do
        ((counter++))
        show_progress $counter $total_users "Analyzing: $user_email"
        
        # Check if user has any shared files
        local shared_files=$($GAM user "$user_email" print filelist query "shared=true" fields id | tail -n +2 | wc -l)
        local total_files=$($GAM user "$user_email" print filelist fields id | tail -n +2 | wc -l)
        local storage_used=$($GAM info user "$user_email" 2>/dev/null | grep "Storage Used:" | cut -d' ' -f3 || echo "0")
        
        local has_sharing="No"
        [[ $shared_files -gt 0 ]] && has_sharing="Yes"
        
        echo "$user_email,$has_sharing,$total_files,$storage_used" >> "$csv_output"
        
        if [[ $shared_files -eq 0 ]]; then
            echo "$user_email" >> "${SCRIPTPATH}/csv-files/candidates_for_deletion.txt"
        fi
    done
    
    echo -e "${GREEN}Analysis complete. Results saved to:${NC}"
    echo "- $csv_output"
    echo "- ${SCRIPTPATH}/csv-files/candidates_for_deletion.txt"
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
        local activity_date=$($GAM user gamadmin@your-domain.edu show driveactivity "$file_id" 2>/dev/null | \
                              grep -E "time.*$(date -d "$target_date" +%Y)" | head -1 | \
                              grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || echo "$target_date")
        
        # Update the file with the restored date
        $GAM user "$user_email" update drivefile "$file_id" modifiedtime "$activity_date"
    done
    
    echo -e "${GREEN}Date restoration completed${NC}"
}

# Function to manage shared drives operations
shared_drive_operations() {
    local operation="$1"
    local drive_id="$2"
    local user_email="$3"
    
    case $operation in
        "remove_pending_labels")
            echo -e "${GREEN}Removing pending deletion labels from shared drive...${NC}"
            $GAM user gamadmin@your-domain.edu print filelist query "parents in '$drive_id'" \
                fields id,name | tail -n +2 | while IFS=',' read -r file_id file_name; do
                if [[ "$file_name" == *"PENDING DELETION"* ]] || [[ "$file_name" == *"Suspended Account - Temporary Hold"* ]]; then
                    local new_name=$(echo "$file_name" | sed -E 's/ \(PENDING DELETION - CONTACT OIT\)//g' | \
                                    sed -E 's/ \(Suspended Account - Temporary Hold\)//g')
                    echo "  Cleaning: $file_name -> $new_name"
                    $GAM user gamadmin@your-domain.edu update drivefile "$file_id" name "$new_name"
                fi
            done
            ;;
        "grant_admin_access")
            echo -e "${GREEN}Granting gamadmin access to all files in shared drive...${NC}"
            $GAM user gamadmin@your-domain.edu print filelist query "parents in '$drive_id'" \
                fields id | tail -n +2 | while read file_id; do
                $GAM user gamadmin@your-domain.edu add drivefileacl "$file_id" user gamadmin@your-domain.edu role writer
            done
            ;;
        "create_user_drive")
            echo -e "${GREEN}Creating shared drive for user: $user_email${NC}"
            local drive_name="${user_email} - Archived Files"
            local new_drive_id=$($GAM create shareddrive "$drive_name" adminmanaged)
            echo "Created shared drive: $new_drive_id"
            
            # Grant access to gamadmin
            $GAM update shareddrive "$new_drive_id" add organizer gamadmin@your-domain.edu
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
    echo "3. your-domain.edu (reactivate account)"
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
    local groups=$($GAM print groups member "$user" 2>/dev/null | tail -n +2 | grep your-domain.edu || true)
    
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
query_temphold_users() {
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
            
            ((users_processed++))
            echo "Processing $username ($file_count files)..."
            
            # Read each file ID and clean it up
            while IFS=, read -r owner fileid filename; do
                if [[ -n "$fileid" && "$fileid" != "id" ]]; then
                    ((files_processed++))
                    
                    # Remove pending deletion suffix from filename
                    local new_filename=${filename//" (PENDING DELETION - CONTACT OIT)"/}
                    if [[ "$new_filename" != "$filename" ]]; then
                        execute_command "$GAM user \"$username\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Clean filename: $filename"
                    fi
                    
                    # Remove drive label
                    execute_command "$GAM user $username process filedrivelabels $fileid deletelabelfield $LABEL_ID $FIELD_ID" "Remove drive label"
                    
                    echo "Cleaned: $fileid" >> "${SCRIPTPATH}/logs/orphaned-files-cleaned.txt"
                fi
            done < "$scan_file"
        fi
    done
    
    echo ""
    echo -e "${GREEN}Bulk cleanup complete!${NC}"
    echo "Users processed: $users_processed"
    echo "Files cleaned: $files_processed"
    echo "Log saved to: ${SCRIPTPATH}/logs/orphaned-files-cleaned.txt"
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
            1) bulk_process_users "$result_file" "add_temphold" ;;
            2) bulk_process_users "$result_file" "remove_temphold" ;;
            3) bulk_process_users "$result_file" "add_pending" ;;
            4) bulk_process_users "$result_file" "remove_pending" ;;
            5) bulk_diagnose_users "$result_file" ;;
            6) echo "Bulk operation cancelled." ;;
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
            "add_temphold") process_user "$user" ;;
            "remove_temphold") remove_temphold_user "$user" ;;
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
            echo "$user" >> "${SCRIPTPATH}/logs/inconsistent-users.txt"
        fi
        rm -f /tmp/diagnosis_$user.txt
    done < "$user_file"
    
    echo ""
    echo -e "${GREEN}Bulk diagnosis complete!${NC}"
    echo "Users diagnosed: $user_count"
    echo "Consistent accounts: $consistent_users"
    echo "Inconsistent accounts: $inconsistent_users"
    
    if [[ $inconsistent_users -gt 0 ]]; then
        echo "Inconsistent users logged to: ${SCRIPTPATH}/logs/inconsistent-users.txt"
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
        temphold_files=$($GAM user "$user" show filelist id name | grep -c "(Suspended Account - Temporary Hold)")
        echo "Files with suffix: $temphold_files"
        files_with_suffix=$temphold_files
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
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 3: Adding drive labels to files for $user_email_full${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would add Education Plus license temporarily${NC}"
        echo -e "${CYAN}[DRY-RUN] Would add drive labels to all files${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove Education Plus license${NC}"
        return 0
    fi
    
    # Add Education Plus license temporarily for drive labels
    execute_command "$GAM user $user_email_full add license \"Google Workspace for Education Plus\"" "Add temporary license"
    echo "Waiting 30 seconds for license to take effect..."
    sleep 30
    
    CSV_DIR="${SCRIPTPATH}/csv-files"
    UNIQUE_FILE="${CSV_DIR}/${user_email}_unique_files.csv"
    LOG_FILE="${SCRIPTPATH}/logs/${user_email}_drive-labels.txt"
    
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
            execute_command "$GAM user $user_email_full process filedrivelabels $file_id addlabelfield $LABEL_ID $FIELD_ID selection $SELECTION_ID" "Add label to file"
        fi
    done < "$UNIQUE_FILE"
    
    # Remove the temporary license
    execute_command "$GAM user $user_email_full delete license \"Google Workspace for Education Plus\"" "Remove temporary license"
    
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
    echo -e "${GREEN}Step 4: Removing user from all groups for $user${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query user groups for: $user${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove user from all groups${NC}"
        echo "Simulated: User would be removed from 8 groups"
        return 0
    fi
    
    # Get list of groups user is a member of
    groups=$($GAM print groups member $user 2>/dev/null | grep your-domain.edu)
    
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

# Function to fix filenames (from temphold-filesfix.sh)
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

# Function to rename all files (from temphold-file-rename.sh)
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
        echo "$user_email,123abc,Document1.pdf,activeuser1@your-domain.edu,reader" >> "$INPUT_FILE"
        echo "$user_email,456def,Document2.pdf,activeuser2@your-domain.edu,writer" >> "$INPUT_FILE"
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
    
    # Filter for files shared with active your-domain.edu accounts ONLY
    # Exclude external domains and already suspended accounts
    echo "Filtering for files shared with active your-domain.edu accounts..."
    
    # Generate list of files shared ONLY with active your-domain.edu accounts
    # This excludes files shared with external domains or already suspended users
    awk -F, '
    NR==1 {next}  # Skip header
    $4 ~ /@williams\.edu$/ && $4 !~ /suspended|pending|temporary/ {
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
    echo "  Files shared with active your-domain.edu accounts: $shared_count"
    echo "  Files shared externally or with suspended accounts: $external_files"
    echo ""
    
    if [[ $shared_count -eq 0 ]]; then
        echo -e "${GREEN}✓ No files are shared with active your-domain.edu accounts.${NC}"
        echo -e "${CYAN}This is ideal for security - no internal sharing to protect.${NC}"
        echo -e "${CYAN}Only files already marked as pending deletion were processed.${NC}"
        log_info "User $user_email_full has no files shared with active your-domain.edu accounts - optimal security state"
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

# Function to update user last name (from temphold-namechange.sh)
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
remove_temphold_lastname() {
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
remove_temphold_from_files() {
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
remove_temphold_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Removing temporary hold from user: $user ===${NC}"
    echo ""
    
    # Step 1: Remove temporary hold from lastname
    show_progress 1 3 "Removing temporary hold from lastname"
    remove_temphold_lastname "$user"
    echo ""
    
    # Step 2: Remove temporary hold from all files
    show_progress 2 3 "Removing temporary hold from all files"
    remove_temphold_from_files "$user"
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
        echo "$user" >> "${SCRIPTPATH}/temphold-removed.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$user" >> "${SCRIPTPATH}/file-removal-done.txt"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user removal${NC}"
    fi
    echo -e "${GREEN}Temporary hold removed from user $user successfully.${NC}"
    echo ""
}

# Function to remove temporary hold from multiple users from file
remove_temphold_users_from_file() {
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
            remove_temphold_user "$user"
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
    
    log_info "Starting add_temphold operation for user: $user" "console"
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
        echo "$user" >> "${SCRIPTPATH}/temphold-done.log"
        log_operation "add_temphold" "$user" "SUCCESS" "Temporary hold added successfully"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user to temphold-done.log${NC}"
        log_operation "add_temphold" "$user" "DRY-RUN" "Dry-run mode - no changes made"
    fi
    
    end_operation_timer "add_temphold" 1
    log_info "Completed add_temphold operation for user: $user" "console"
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
        echo "6. Return to main menu"
        echo ""
        read -p "Select an option (1-6): " stage1_choice
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
                local export_file="reports/suspended_accounts_$(date +%Y%m%d_%H%M%S).csv"
                mkdir -p reports
                query_all_suspended_users > "$export_file"
                echo -e "${GREEN}Exported to: $export_file${NC}"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6) return ;;
            *) 
                echo -e "${RED}Invalid option. Please select 1-6.${NC}"
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
        echo "7. Return to main menu"
        echo ""
        read -p "Select an option (1-7): " stage2_choice
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
            6) 
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
            7) return ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7.${NC}"
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
        echo -e "${CYAN}Analyze files shared by pending deletion accounts with active your-domain.edu users.${NC}"
        echo -e "${CYAN}Generate reports for active users about files they're receiving from suspended accounts.${NC}"
        echo ""
        echo "1. Analyze single user's file sharing"
        echo "2. Analyze multiple users (batch processing)"
        echo "3. Generate report for active user (what they're receiving)"
        echo "4. Update shared filenames with pending deletion labels"
        echo "5. Bulk analysis of all pending deletion users"
        echo "6. View analysis statistics"
        echo "7. Clean up analysis files"
        echo "8. Return to main menu"
        echo ""
        read -p "Select an option (1-8): " stage3_choice
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
                local recipient_reports=$(ls reports/*_files_from_*.csv 2>/dev/null | wc -l)
                
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
            8) return ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-8.${NC}"
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
        echo "7. Return to main menu"
        echo ""
        read -p "Select an option (1-7): " stage4_choice
        echo ""
        
        case $stage4_choice in
            1)
                user=$(get_user_input)
                show_summary "$user"
                if enhanced_confirm "move to temporary hold" 1 "normal"; then
                    create_backup "$user" "add_temphold"
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
                    create_backup "$user" "remove_temphold"
                    remove_temphold_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4) 
                query_temphold_users
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Querying users in Exit Row OU...${NC}"
                $GAM print users query "orgUnitPath:'/Suspended Accounts/Suspended - Exit Row'" fields primaryemail,givenname,familyname,suspended,lastlogintime
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
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
            7) return ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-7.${NC}"
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
        echo "6. Return to main menu"
        echo ""
        read -p "Select an option (1-6): " stage5_choice
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
                    
                    local audit_file="reports/${username}_pre_deletion_audit_$(date +%Y%m%d_%H%M%S).txt"
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
                local temphold_count=$(query_temphold_users | tail -n +2 | wc -l)
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
            6) return ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-6.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Main script execution
main() {
    while true; do
        show_main_menu
        choice=$?
        
        case $choice in
            1)
                stage1_recently_suspended_menu
                ;;
            2)
                stage2_pending_deletion_menu
                ;;
            3)
                stage3_sharing_analysis_menu
                ;;
            4)
                stage4_final_decisions_menu
                ;;
            5)
                stage5_deletion_operations_menu
                ;;
            6)
                discovery_mode
                ;;
            7)
                # Administrative tools
                while true; do
                    clear
                    echo -e "${BLUE}=== Administrative Tools & Cleanup ===${NC}"
                    echo ""
                    echo "1. Shared Drive cleanup operations"
                    echo "2. License management operations"
                    echo "3. File ownership audit"
                    echo "4. Check for incomplete operations"
                    echo "5. Dry-run mode (preview any operation)"
                    echo "6. Return to main menu"
                    echo ""
                    read -p "Select an option (1-6): " admin_choice
                    echo ""
                    
                    case $admin_choice in
                        1) shared_drive_cleanup_menu ;;
                        2) license_management_menu ;;
                        3) audit_file_ownership_menu ;;
                        4) check_incomplete_operations ;;
                        5) dry_run_mode ;;
                        6) break ;;
                        *)
                            echo -e "${RED}Invalid option. Please select 1-6.${NC}"
                            read -p "Press Enter to continue..."
                            ;;
                    esac
                done
                ;;
            8)
                reports_and_cleanup_menu
                ;;
            9)
                echo -e "${BLUE}Goodbye!${NC}"
                log_info "Session ended by user"
                echo "=== SESSION END: $(date) ===" >> "$LOG_FILE"
                generate_daily_report
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-9.${NC}"
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
