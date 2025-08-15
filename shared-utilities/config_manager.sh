#!/bin/bash

# Configuration Management for GWOMBAT
# Handles dashboard settings, scheduling configuration, and user preferences with opt-out capabilities

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
CURRENT_USER="${USER:-unknown}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Initialize configuration management database
init_config_db() {
    if [[ -f "../config_management_schema.sql" ]]; then
        sqlite3 "$DB_PATH" < ../config_management_schema.sql 2>/dev/null || true
        echo "Configuration management database initialized."
        log_config "Configuration management database initialized" "INFO"
    fi
}

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Configuration logging function
log_config() {
    local message="$1"
    local level="${2:-INFO}"
    local operation="${3:-config_management}"
    
    execute_db "
    INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
    VALUES ('$level', '$SESSION_ID', '$operation', '$message', 'config_manager.sh');
    " >/dev/null 2>&1
}

# Get configuration value
get_config() {
    local section="$1"
    local key="$2"
    local default_value="$3"
    
    local value=$(execute_db "SELECT config_value FROM gwombat_config WHERE config_section = '$section' AND config_key = '$key';")
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Set configuration value with audit logging
set_config() {
    local section="$1"
    local key="$2"
    local value="$3"
    local changed_by="${4:-$CURRENT_USER}"
    local reason="${5:-Manual configuration change}"
    
    # Get current value for audit
    local old_value=$(get_config "$section" "$key" "")
    
    # Update or insert configuration
    execute_db "
    INSERT OR REPLACE INTO gwombat_config (config_section, config_key, config_value, last_modified, modified_by)
    VALUES ('$section', '$key', '$value', CURRENT_TIMESTAMP, '$changed_by');
    "
    
    # Log the change
    execute_db "
    INSERT INTO config_audit_log (config_section, config_key, old_value, new_value, changed_by, change_reason, session_id)
    VALUES ('$section', '$key', '$old_value', '$value', '$changed_by', '$reason', '$SESSION_ID');
    "
    
    log_config "Configuration changed: $section.$key = $value (was: $old_value)" "INFO" "config_change"
}

# Get user preference
get_preference() {
    local category="$1"
    local key="$2"
    local user_email="${3:-NULL}"
    local default_value="$4"
    
    local where_clause="preference_category = '$category' AND preference_key = '$key'"
    if [[ "$user_email" != "NULL" ]]; then
        where_clause="$where_clause AND user_email = '$user_email'"
    else
        where_clause="$where_clause AND user_email IS NULL"
    fi
    
    local value=$(execute_db "SELECT preference_value FROM user_preferences WHERE $where_clause;")
    
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default_value"
    fi
}

# Set user preference
set_preference() {
    local category="$1"
    local key="$2"
    local value="$3"
    local user_email="${4:-NULL}"
    local description="$5"
    
    if [[ "$user_email" == "NULL" ]]; then
        execute_db "
        INSERT OR REPLACE INTO user_preferences (preference_category, preference_key, preference_value, user_email, description, last_modified)
        VALUES ('$category', '$key', '$value', NULL, '$description', CURRENT_TIMESTAMP);
        "
    else
        execute_db "
        INSERT OR REPLACE INTO user_preferences (preference_category, preference_key, preference_value, user_email, description, last_modified)
        VALUES ('$category', '$key', '$value', '$user_email', '$description', CURRENT_TIMESTAMP);
        "
    fi
    
    log_config "Preference changed: $category.$key = $value (user: $user_email)" "INFO" "preference_change"
}

# Check if scheduling is enabled (master switch)
is_scheduling_enabled() {
    local scheduler_enabled=$(get_config "scheduling" "scheduler_enabled" "false")
    local opt_out_all=$(get_preference "scheduling" "opt_out_all_tasks" "NULL" "false")
    
    if [[ "$scheduler_enabled" == "true" ]] && [[ "$opt_out_all" == "false" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Check if specific task type is allowed
is_task_type_allowed() {
    local task_type="$1"
    
    # Check global scheduler setting first
    if [[ "$(is_scheduling_enabled)" == "false" ]]; then
        echo "false"
        return
    fi
    
    # Check specific opt-out preferences
    case "$task_type" in
        "dashboard_refresh")
            local opt_out=$(get_preference "scheduling" "opt_out_dashboard_refresh" "NULL" "false")
            ;;
        "security_scan")
            local opt_out=$(get_preference "scheduling" "opt_out_security_scans" "NULL" "false")
            ;;
        "backup_operation")
            local opt_out=$(get_preference "scheduling" "opt_out_backup_operations" "NULL" "false")
            ;;
        "cleanup")
            local opt_out=$(get_preference "scheduling" "opt_out_cleanup_tasks" "NULL" "false")
            ;;
        *)
            local opt_out="false"
            ;;
    esac
    
    if [[ "$opt_out" == "false" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Enable/disable scheduled task with opt-out check
toggle_scheduled_task() {
    local task_name="$1"
    local enable="$2" # true/false
    local force="${3:-false}" # Override opt-out checks
    
    if [[ "$enable" == "true" ]] && [[ "$force" == "false" ]]; then
        # Check if this task type is allowed
        local task_type=$(execute_db "SELECT task_type FROM scheduled_tasks WHERE task_name = '$task_name';")
        if [[ "$(is_task_type_allowed "$task_type")" == "false" ]]; then
            echo "Task $task_name cannot be enabled: scheduling disabled or user opted out"
            return 1
        fi
    fi
    
    local enabled_value=0
    [[ "$enable" == "true" ]] && enabled_value=1
    
    execute_db "
    UPDATE scheduled_tasks 
    SET is_enabled = $enabled_value, updated_at = CURRENT_TIMESTAMP
    WHERE task_name = '$task_name';
    "
    
    log_config "Task $task_name $([ "$enable" == "true" ] && echo "enabled" || echo "disabled")" "INFO" "task_management"
}

# Show configuration menu
show_config_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== 🔧 Configuration Management ===${NC}"
        echo ""
        
        # Show current scheduling status
        local scheduling_status=$(is_scheduling_enabled)
        local status_color="$RED"
        local status_text="DISABLED"
        if [[ "$scheduling_status" == "true" ]]; then
            status_color="$GREEN"
            status_text="ENABLED"
        fi
        echo -e "${CYAN}Scheduling Status:${NC} ${status_color}$status_text${NC}"
        echo ""
        
        echo -e "${GREEN}=== CONFIGURATION OPTIONS ===${NC}"
        echo "1. 📊 Dashboard Settings"
        echo "2. 🔒 Security Settings" 
        echo "3. 💾 Backup Settings"
        echo "4. ⏰ Scheduling Settings"
        echo "5. 🔧 System Settings"
        echo ""
        echo -e "${YELLOW}=== SCHEDULING MANAGEMENT ===${NC}"
        echo "6. 📋 View Scheduled Tasks"
        echo "7. ⚙️  Enable/Disable Tasks"
        echo "8. 🚫 Opt-Out Preferences"
        echo ""
        echo -e "${PURPLE}=== ADVANCED ===${NC}"
        echo "9. 📈 Configuration Audit Log"
        echo "10. 📤 Export Configuration"
        echo "11. 📥 Import Configuration"
        echo ""
        echo "12. ↩️  Return to main menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-12, m, x): " config_choice
        echo ""
        
        case $config_choice in
            1) dashboard_settings_menu ;;
            2) security_settings_menu ;;
            3) backup_settings_menu ;;
            4) scheduling_settings_menu ;;
            5) system_settings_menu ;;
            6) view_scheduled_tasks ;;
            7) manage_scheduled_tasks ;;
            8) opt_out_preferences_menu ;;
            9) show_config_audit_log ;;
            10) export_configuration ;;
            11) import_configuration ;;
            12|m|M) return ;;
            x|X) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Please select 1-12, m, or x.${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Dashboard settings submenu
dashboard_settings_menu() {
    echo -e "${CYAN}📊 Dashboard Settings${NC}"
    echo ""
    
    # Show current values
    local ou_interval=$(get_config "dashboard" "ou_scan_interval_minutes" "30")
    local extended_interval=$(get_config "dashboard" "extended_stats_interval_minutes" "60")
    local cache_enabled=$(get_config "dashboard" "cache_enabled" "true")
    local auto_refresh=$(get_config "dashboard" "auto_refresh_enabled" "false")
    local quick_stats=$(get_config "dashboard" "show_quick_stats" "true")
    
    echo "Current Settings:"
    echo "  OU Scan Interval: $ou_interval minutes"
    echo "  Extended Stats Interval: $extended_interval minutes"
    echo "  Cache Enabled: $cache_enabled"
    echo "  Auto Refresh: $auto_refresh"
    echo "  Show Quick Stats: $quick_stats"
    echo ""
    
    echo "1. Change OU scan interval"
    echo "2. Change extended stats interval"
    echo "3. Toggle cache enabled/disabled"
    echo "4. Toggle auto refresh enabled/disabled"
    echo "5. Toggle quick stats display"
    echo "6. Reset to defaults"
    echo "7. Return to config menu"
    echo ""
    read -p "Select option (1-7): " choice
    
    case $choice in
        1)
            read -p "Enter OU scan interval in minutes (current: $ou_interval): " new_interval
            if [[ "$new_interval" =~ ^[0-9]+$ ]] && [[ "$new_interval" -gt 0 ]]; then
                set_config "dashboard" "ou_scan_interval_minutes" "$new_interval" "$CURRENT_USER" "Dashboard OU scan interval changed"
                echo -e "${GREEN}OU scan interval updated to $new_interval minutes${NC}"
            else
                echo -e "${RED}Invalid interval. Must be a positive number.${NC}"
            fi
            ;;
        2)
            read -p "Enter extended stats interval in minutes (current: $extended_interval): " new_interval
            if [[ "$new_interval" =~ ^[0-9]+$ ]] && [[ "$new_interval" -gt 0 ]]; then
                set_config "dashboard" "extended_stats_interval_minutes" "$new_interval" "$CURRENT_USER" "Dashboard extended stats interval changed"
                echo -e "${GREEN}Extended stats interval updated to $new_interval minutes${NC}"
            else
                echo -e "${RED}Invalid interval. Must be a positive number.${NC}"
            fi
            ;;
        3)
            local new_value="true"
            [[ "$cache_enabled" == "true" ]] && new_value="false"
            set_config "dashboard" "cache_enabled" "$new_value" "$CURRENT_USER" "Dashboard cache setting toggled"
            echo -e "${GREEN}Cache enabled set to $new_value${NC}"
            ;;
        4)
            local new_value="true"
            [[ "$auto_refresh" == "true" ]] && new_value="false"
            set_config "dashboard" "auto_refresh_enabled" "$new_value" "$CURRENT_USER" "Dashboard auto refresh toggled"
            echo -e "${GREEN}Auto refresh set to $new_value${NC}"
            ;;
        5)
            local new_value="true"
            [[ "$quick_stats" == "true" ]] && new_value="false"
            set_config "dashboard" "show_quick_stats" "$new_value" "$CURRENT_USER" "Dashboard quick stats display toggled"
            echo -e "${GREEN}Quick stats display set to $new_value${NC}"
            ;;
        6)
            set_config "dashboard" "ou_scan_interval_minutes" "30" "$CURRENT_USER" "Reset to default"
            set_config "dashboard" "extended_stats_interval_minutes" "60" "$CURRENT_USER" "Reset to default"
            set_config "dashboard" "cache_enabled" "true" "$CURRENT_USER" "Reset to default"
            set_config "dashboard" "auto_refresh_enabled" "false" "$CURRENT_USER" "Reset to default"
            set_config "dashboard" "show_quick_stats" "true" "$CURRENT_USER" "Reset to default"
            echo -e "${GREEN}Dashboard settings reset to defaults${NC}"
            ;;
        7) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Opt-out preferences menu
opt_out_preferences_menu() {
    echo -e "${CYAN}🚫 Opt-Out Preferences${NC}"
    echo ""
    echo "These settings allow you to disable specific types of scheduled tasks."
    echo "Individual users can opt out without affecting system-wide settings."
    echo ""
    
    # Show current opt-out status
    local opt_out_all=$(get_preference "scheduling" "opt_out_all_tasks" "NULL" "false")
    local opt_out_dashboard=$(get_preference "scheduling" "opt_out_dashboard_refresh" "NULL" "false")
    local opt_out_security=$(get_preference "scheduling" "opt_out_security_scans" "NULL" "false")
    local opt_out_backup=$(get_preference "scheduling" "opt_out_backup_operations" "NULL" "false")
    local opt_out_cleanup=$(get_preference "scheduling" "opt_out_cleanup_tasks" "NULL" "false")
    
    echo "Current Opt-Out Status:"
    echo "  All Tasks: $([ "$opt_out_all" == "true" ] && echo "${RED}OPTED OUT${NC}" || echo "${GREEN}ENABLED${NC}")"
    echo "  Dashboard Refresh: $([ "$opt_out_dashboard" == "true" ] && echo "${RED}OPTED OUT${NC}" || echo "${GREEN}ENABLED${NC}")"
    echo "  Security Scans: $([ "$opt_out_security" == "true" ] && echo "${RED}OPTED OUT${NC}" || echo "${GREEN}ENABLED${NC}")"
    echo "  Backup Operations: $([ "$opt_out_backup" == "true" ] && echo "${RED}OPTED OUT${NC}" || echo "${GREEN}ENABLED${NC}")"
    echo "  Cleanup Tasks: $([ "$opt_out_cleanup" == "true" ] && echo "${RED}OPTED OUT${NC}" || echo "${GREEN}ENABLED${NC}")"
    echo ""
    
    echo "1. Toggle opt-out from ALL scheduled tasks"
    echo "2. Toggle opt-out from dashboard refresh tasks"
    echo "3. Toggle opt-out from security scan tasks"
    echo "4. Toggle opt-out from backup operation tasks"
    echo "5. Toggle opt-out from cleanup tasks"
    echo "6. Reset all opt-outs (enable all)"
    echo "7. Return to config menu"
    echo ""
    read -p "Select option (1-7): " choice
    
    case $choice in
        1)
            local new_value="true"
            [[ "$opt_out_all" == "true" ]] && new_value="false"
            set_preference "scheduling" "opt_out_all_tasks" "$new_value" "NULL" "Global opt-out from all scheduled tasks"
            echo -e "${GREEN}Opt-out from all tasks set to $new_value${NC}"
            if [[ "$new_value" == "true" ]]; then
                echo -e "${YELLOW}⚠️  All scheduled tasks are now disabled for this system${NC}"
            fi
            ;;
        2)
            local new_value="true"
            [[ "$opt_out_dashboard" == "true" ]] && new_value="false"
            set_preference "scheduling" "opt_out_dashboard_refresh" "$new_value" "NULL" "Opt-out from automatic dashboard refreshes"
            echo -e "${GREEN}Opt-out from dashboard refresh set to $new_value${NC}"
            ;;
        3)
            local new_value="true"
            [[ "$opt_out_security" == "true" ]] && new_value="false"
            set_preference "scheduling" "opt_out_security_scans" "$new_value" "NULL" "Opt-out from automatic security scans"
            echo -e "${GREEN}Opt-out from security scans set to $new_value${NC}"
            ;;
        4)
            local new_value="true"
            [[ "$opt_out_backup" == "true" ]] && new_value="false"
            set_preference "scheduling" "opt_out_backup_operations" "$new_value" "NULL" "Opt-out from automatic backup operations"
            echo -e "${GREEN}Opt-out from backup operations set to $new_value${NC}"
            ;;
        5)
            local new_value="true"
            [[ "$opt_out_cleanup" == "true" ]] && new_value="false"
            set_preference "scheduling" "opt_out_cleanup_tasks" "$new_value" "NULL" "Opt-out from automatic cleanup tasks"
            echo -e "${GREEN}Opt-out from cleanup tasks set to $new_value${NC}"
            ;;
        6)
            set_preference "scheduling" "opt_out_all_tasks" "false" "NULL" "Reset opt-outs - enable all"
            set_preference "scheduling" "opt_out_dashboard_refresh" "false" "NULL" "Reset opt-outs - enable all"
            set_preference "scheduling" "opt_out_security_scans" "false" "NULL" "Reset opt-outs - enable all"
            set_preference "scheduling" "opt_out_backup_operations" "false" "NULL" "Reset opt-outs - enable all"
            set_preference "scheduling" "opt_out_cleanup_tasks" "false" "NULL" "Reset opt-outs - enable all"
            echo -e "${GREEN}All opt-outs reset - scheduled tasks are now enabled (if scheduler is enabled)${NC}"
            ;;
        7) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# View scheduled tasks
view_scheduled_tasks() {
    echo -e "${CYAN}📋 Scheduled Tasks Overview${NC}"
    echo ""
    
    local tasks_data=$(execute_db "
    SELECT 
        task_name,
        task_description,
        task_type,
        schedule_pattern,
        CASE WHEN is_enabled = 1 THEN 'Enabled' ELSE 'Disabled' END as status,
        CASE 
            WHEN next_run IS NULL THEN 'Never'
            WHEN next_run <= datetime('now') THEN 'Ready'
            ELSE strftime('%Y-%m-%d %H:%M', next_run)
        END as next_run,
        COALESCE(success_rate, 0) as success_rate
    FROM active_scheduled_tasks
    UNION ALL
    SELECT 
        task_name,
        task_description,
        task_type,
        schedule_pattern,
        'Disabled' as status,
        'N/A' as next_run,
        0 as success_rate
    FROM scheduled_tasks 
    WHERE is_enabled = 0
    ORDER BY status DESC, task_type, task_name;
    ")
    
    if [[ -n "$tasks_data" ]]; then
        printf "%-25s %-15s %-10s %-15s %-12s %-8s\n" "Task Name" "Type" "Status" "Schedule" "Next Run" "Success%"
        echo "---------------------------------------------------------------------------------------------"
        echo "$tasks_data" | while IFS='|' read -r name description type pattern status next_run success_rate; do
            local status_color="$RED"
            [[ "$status" == "Enabled" ]] && status_color="$GREEN"
            
            printf "%-25s %-15s ${status_color}%-10s${NC} %-15s %-12s %-8s\n" \
                "$name" "$type" "$status" "$pattern" "$next_run" "${success_rate}%"
        done
    else
        echo "No scheduled tasks found."
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Show scheduling settings menu  
scheduling_settings_menu() {
    echo -e "${CYAN}⏰ Scheduling Settings${NC}"
    echo ""
    
    local scheduler_enabled=$(get_config "scheduling" "scheduler_enabled" "false")
    local max_concurrent=$(get_config "scheduling" "max_concurrent_tasks" "3")
    local task_timeout=$(get_config "scheduling" "task_timeout_minutes" "30")
    local log_retention=$(get_config "scheduling" "log_retention_days" "30")
    
    echo "Current Settings:"
    echo "  Master Scheduler: $([ "$scheduler_enabled" == "true" ] && echo "${GREEN}ENABLED${NC}" || echo "${RED}DISABLED${NC}")"
    echo "  Max Concurrent Tasks: $max_concurrent"
    echo "  Task Timeout: $task_timeout minutes"
    echo "  Log Retention: $log_retention days"
    echo ""
    
    echo -e "${YELLOW}⚠️  IMPORTANT: Users can still opt-out of individual task types even if scheduler is enabled${NC}"
    echo ""
    
    echo "1. Toggle master scheduler (enable/disable ALL scheduling)"
    echo "2. Change max concurrent tasks"
    echo "3. Change task timeout"
    echo "4. Change log retention period"
    echo "5. Return to config menu"
    echo ""
    read -p "Select option (1-5): " choice
    
    case $choice in
        1)
            local new_value="true"
            [[ "$scheduler_enabled" == "true" ]] && new_value="false"
            set_config "scheduling" "scheduler_enabled" "$new_value" "$CURRENT_USER" "Master scheduler toggled"
            echo -e "${GREEN}Master scheduler set to $new_value${NC}"
            if [[ "$new_value" == "true" ]]; then
                echo -e "${CYAN}✓ Scheduled tasks can now run (subject to individual opt-out preferences)${NC}"
            else
                echo -e "${YELLOW}⚠️  All scheduled tasks are now disabled system-wide${NC}"
            fi
            ;;
        2)
            read -p "Enter max concurrent tasks (current: $max_concurrent): " new_max
            if [[ "$new_max" =~ ^[0-9]+$ ]] && [[ "$new_max" -gt 0 ]] && [[ "$new_max" -le 10 ]]; then
                set_config "scheduling" "max_concurrent_tasks" "$new_max" "$CURRENT_USER" "Max concurrent tasks changed"
                echo -e "${GREEN}Max concurrent tasks updated to $new_max${NC}"
            else
                echo -e "${RED}Invalid value. Must be between 1 and 10.${NC}"
            fi
            ;;
        3)
            read -p "Enter task timeout in minutes (current: $task_timeout): " new_timeout
            if [[ "$new_timeout" =~ ^[0-9]+$ ]] && [[ "$new_timeout" -gt 0 ]]; then
                set_config "scheduling" "task_timeout_minutes" "$new_timeout" "$CURRENT_USER" "Task timeout changed"
                echo -e "${GREEN}Task timeout updated to $new_timeout minutes${NC}"
            else
                echo -e "${RED}Invalid timeout. Must be a positive number.${NC}"
            fi
            ;;
        4)
            read -p "Enter log retention in days (current: $log_retention): " new_retention
            if [[ "$new_retention" =~ ^[0-9]+$ ]] && [[ "$new_retention" -gt 0 ]]; then
                set_config "scheduling" "log_retention_days" "$new_retention" "$CURRENT_USER" "Log retention changed"
                echo -e "${GREEN}Log retention updated to $new_retention days${NC}"
            else
                echo -e "${RED}Invalid retention period. Must be a positive number.${NC}"
            fi
            ;;
        5) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Placeholder functions for other menus (to be implemented)
security_settings_menu() {
    echo -e "${YELLOW}Security settings menu - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

backup_settings_menu() {
    echo -e "${YELLOW}Backup settings menu - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

system_settings_menu() {
    echo -e "${YELLOW}System settings menu - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

manage_scheduled_tasks() {
    echo -e "${YELLOW}Task management interface - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

show_config_audit_log() {
    echo -e "${YELLOW}Configuration audit log - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

export_configuration() {
    echo -e "${YELLOW}Configuration export - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

import_configuration() {
    echo -e "${YELLOW}Configuration import - implementation pending${NC}"
    read -p "Press Enter to continue..."
}

# Command line interface
case "${1:-menu}" in
    "init")
        init_config_db
        ;;
    "menu")
        show_config_menu
        ;;
    "get")
        get_config "$2" "$3" "$4"
        ;;
    "set")
        set_config "$2" "$3" "$4" "$5" "$6"
        ;;
    "get-pref")
        get_preference "$2" "$3" "$4" "$5"
        ;;
    "set-pref")
        set_preference "$2" "$3" "$4" "$5" "$6"
        ;;
    "is-scheduling-enabled")
        is_scheduling_enabled
        ;;
    "is-task-allowed")
        is_task_type_allowed "$2"
        ;;
    "toggle-task")
        toggle_scheduled_task "$2" "$3" "$4"
        ;;
    *)
        echo "Usage: $0 {init|menu|get|set|get-pref|set-pref|is-scheduling-enabled|is-task-allowed|toggle-task}"
        echo ""
        echo "Commands:"
        echo "  init                           - Initialize configuration database"
        echo "  menu                          - Show configuration management menu"
        echo "  get <section> <key> [default] - Get configuration value"
        echo "  set <section> <key> <value>   - Set configuration value"
        echo "  get-pref <cat> <key> [user]   - Get user preference"
        echo "  set-pref <cat> <key> <value>  - Set user preference"
        echo "  is-scheduling-enabled         - Check if scheduling is enabled"
        echo "  is-task-allowed <type>        - Check if task type is allowed"
        echo "  toggle-task <name> <enable>   - Enable/disable scheduled task"
        exit 1
        ;;
esac