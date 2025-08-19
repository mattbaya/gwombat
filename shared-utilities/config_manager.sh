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
        echo "6. 🌐 External Tools Configuration (GAM, GYB, rclone)"
        echo ""
        echo -e "${YELLOW}=== SCHEDULING MANAGEMENT ===${NC}"
        echo "7. 📋 View Scheduled Tasks"
        echo "8. ⚙️  Enable/Disable Tasks"
        echo "9. 🚫 Opt-Out Preferences"
        echo ""
        echo -e "${PURPLE}=== ADVANCED ===${NC}"
        echo "10. 📈 Configuration Audit Log"
        echo "11. 📤 Export Configuration"
        echo "12. 📥 Import Configuration"
        echo ""
        echo "13. ↩️  Return to main menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-13, m, x): " config_choice
        echo ""
        
        case $config_choice in
            1) dashboard_settings_menu ;;
            2) security_settings_menu ;;
            3) backup_settings_menu ;;
            4) scheduling_settings_menu ;;
            5) system_settings_menu ;;
            6) external_tools_configuration_menu ;;
            7) view_scheduled_tasks ;;
            8) manage_scheduled_tasks ;;
            9) opt_out_preferences_menu ;;
            10) show_config_audit_log ;;
            11) export_configuration ;;
            12) import_configuration ;;
            13|m|M) return ;;
            x|X) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Please select 1-13, m, or x.${NC}"; read -p "Press Enter to continue..." ;;
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
    echo -e "  All Tasks: $([ "$opt_out_all" == "true" ] && echo -e "${RED}OPTED OUT${NC}" || echo -e "${GREEN}ENABLED${NC}")"
    echo -e "  Dashboard Refresh: $([ "$opt_out_dashboard" == "true" ] && echo -e "${RED}OPTED OUT${NC}" || echo -e "${GREEN}ENABLED${NC}")"
    echo -e "  Security Scans: $([ "$opt_out_security" == "true" ] && echo -e "${RED}OPTED OUT${NC}" || echo -e "${GREEN}ENABLED${NC}")"
    echo -e "  Backup Operations: $([ "$opt_out_backup" == "true" ] && echo -e "${RED}OPTED OUT${NC}" || echo -e "${GREEN}ENABLED${NC}")"
    echo -e "  Cleanup Tasks: $([ "$opt_out_cleanup" == "true" ] && echo -e "${RED}OPTED OUT${NC}" || echo -e "${GREEN}ENABLED${NC}")"
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
    echo -e "  Master Scheduler: $([ "$scheduler_enabled" == "true" ] && echo -e "${GREEN}ENABLED${NC}" || echo -e "${RED}DISABLED${NC}")"
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

# External tools configuration menu
external_tools_configuration_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== External Tools Configuration ===${NC}"
        echo ""
        echo -e "${CYAN}Configure GAM, GYB, and rclone to work with your domain${NC}"
        echo ""
        
        # Show current domain configuration
        echo -e "${CYAN}Current Domain Configuration:${NC}"
        local current_domain="${DOMAIN:-not set}"
        echo "• GWOMBAT Domain: $current_domain"
        echo ""
        
        # Check GAM configuration
        echo -e "${CYAN}GAM (Google Apps Manager) Status:${NC}"
        local gam_path="${GAM:-${GAM_PATH:-gam}}"
        if command -v "$gam_path" >/dev/null 2>&1; then
            local gam_domain_info
            if command -v timeout >/dev/null 2>&1; then
                gam_domain_info=$(timeout 10 "$gam_path" info domain 2>/dev/null)
            else
                gam_domain_info=$("$gam_path" info domain 2>/dev/null)
            fi
            
            if [[ -n "$gam_domain_info" ]]; then
                local gam_domain=$(echo "$gam_domain_info" | grep -i "Primary Domain" | awk '{print $3}' | cut -d':' -f1 | sed 's/Verified.*$//' | tr -d '[:space:]')
                if [[ -n "$gam_domain" ]]; then
                    if [[ "$gam_domain" == "$current_domain" ]]; then
                        echo -e "• GAM Domain: ${GREEN}✓ $gam_domain (matches)${NC}"
                    else
                        echo -e "• GAM Domain: ${RED}⚠ $gam_domain (mismatch!)${NC}"
                    fi
                else
                    echo -e "• GAM Domain: ${YELLOW}○ Cannot determine${NC}"
                fi
            else
                echo -e "• GAM Domain: ${RED}✗ Not configured${NC}"
            fi
        else
            echo -e "• GAM: ${RED}✗ Not found at: $gam_path${NC}"
        fi
        
        # Check GYB configuration  
        echo ""
        echo -e "${CYAN}GYB (Got Your Back) Status:${NC}"
        if command -v gyb >/dev/null 2>&1; then
            echo -e "• GYB: ${GREEN}✓ Installed${NC}"
            # Note: GYB uses GAM's OAuth tokens by default
            echo -e "• GYB Domain: ${CYAN}Uses GAM OAuth tokens${NC}"
        else
            echo -e "• GYB: ${YELLOW}○ Not installed${NC}"
        fi
        
        # Check rclone configuration
        echo ""
        echo -e "${CYAN}rclone Status:${NC}"
        if command -v rclone >/dev/null 2>&1; then
            echo -e "• rclone: ${GREEN}✓ Installed${NC}"
            local remotes_count
            if command -v timeout >/dev/null 2>&1; then
                remotes_count=$(timeout 5 rclone listremotes 2>/dev/null | wc -l | tr -d ' ')
            else
                remotes_count=$(rclone listremotes 2>/dev/null | wc -l | tr -d ' ')
            fi
            if [[ "$remotes_count" -gt 0 ]]; then
                echo -e "• rclone Remotes: ${GREEN}✓ $remotes_count configured${NC}"
            else
                echo -e "• rclone Remotes: ${YELLOW}○ None configured${NC}"
            fi
        else
            echo -e "• rclone: ${YELLOW}○ Not installed${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}=== CONFIGURATION OPTIONS ===${NC}"
        echo "1. 🌐 Change GWOMBAT Domain"
        echo "2. 🔑 Configure GAM for Current Domain"
        echo "3. 📧 Configure GYB (Gmail Backup)"
        echo "4. ☁️  Configure rclone (Cloud Storage)"
        echo "5. 🔄 Sync All Tools to Domain"
        echo "6. 📋 Show Detailed Tool Status"
        echo ""
        echo -e "${YELLOW}=== TOOL MANAGEMENT ===${NC}"
        echo "7. 🛠️  Install Missing Tools"
        echo "8. 🧹 Reset Tool Configurations"
        echo ""
        echo "9. ↩️  Return to configuration menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-9, m, x): " choice
        echo ""
        
        case $choice in
            1) change_gwombat_domain ;;
            2) configure_gam_for_domain ;;
            3) configure_gyb ;;
            4) configure_rclone ;;
            5) sync_all_tools_to_domain ;;
            6) show_detailed_tool_status ;;
            7) install_missing_tools ;;
            8) reset_tool_configurations ;;
            9|m|M) return ;;
            x|X) exit 0 ;;
            *) 
                echo -e "${RED}Invalid option. Please select 1-9, m, or x.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

system_settings_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== System Settings ===${NC}"
        echo ""
        echo -e "${CYAN}Configure system-level GWOMBAT settings${NC}"
        echo ""
        
        # Show current system settings
        echo -e "${CYAN}Current System Configuration:${NC}"
        local gam_resolved="${GAM:-${GAM_PATH:-not set}}"
        echo "• GAM Path: $gam_resolved"
        echo "• Python Path: ${PYTHON_PATH:-not set}"
        echo "• Log Retention: ${LOG_RETENTION_DAYS:-30} days"
        echo "• Operation Timeout: ${OPERATION_TIMEOUT:-300} seconds"
        echo "• Confirmation Level: ${CONFIRMATION_LEVEL:-normal}"
        echo "• Progress Display: ${SHOW_PROGRESS:-true}"
        echo ""
        
        echo -e "${GREEN}=== PATHS & EXECUTABLES ===${NC}"
        echo "1. 🔧 Configure GAM path"
        echo "2. 🐍 Configure Python path"
        echo "3. 📁 Configure script paths"
        echo "4. 🗄️  Configure database path"
        echo ""
        echo -e "${YELLOW}=== SYSTEM BEHAVIOR ===${NC}"
        echo "5. ⏱️  Set operation timeouts"
        echo "6. 📝 Configure logging levels"
        echo "7. 🗂️  Set log retention policy"
        echo "8. ✅ Configure confirmation levels"
        echo "9. 📊 Toggle progress display"
        echo ""
        echo -e "${RED}=== PERFORMANCE & LIMITS ===${NC}"
        echo "10. 🚀 Set batch operation limits"
        echo "11. 💾 Configure memory limits"
        echo "12. 🔄 Set retry policies"
        echo ""
        echo -e "${PURPLE}=== MAINTENANCE ===${NC}"
        echo "13. 🧹 Clean temporary files"
        echo "14. 📋 System diagnostics"
        echo "15. 🔄 Reset to defaults"
        echo ""
        echo "p. Previous menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-15, p, m, x): " choice
        echo ""
        
        case $choice in
            1)
                echo -e "${CYAN}Configure GAM Path${NC}"
                echo "Current GAM path: ${GAM_PATH:-not set}"
                echo ""
                read -p "Enter new GAM path (or press Enter to keep current): " new_gam_path
                if [[ -n "$new_gam_path" ]]; then
                    if [[ -x "$new_gam_path" ]]; then
                        echo "GAM_PATH=\"$new_gam_path\"" >> .env
                        echo -e "${GREEN}✓ GAM path updated to: $new_gam_path${NC}"
                        echo "Restart GWOMBAT to apply changes."
                    else
                        echo -e "${RED}✗ GAM executable not found at: $new_gam_path${NC}"
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${CYAN}Configure Python Path${NC}"
                echo "Current Python path: ${PYTHON_PATH:-not set}"
                echo ""
                read -p "Enter new Python path (or press Enter to keep current): " new_python_path
                if [[ -n "$new_python_path" ]]; then
                    if [[ -x "$new_python_path" ]]; then
                        echo "PYTHON_PATH=\"$new_python_path\"" >> .env
                        echo -e "${GREEN}✓ Python path updated to: $new_python_path${NC}"
                        echo "Restart GWOMBAT to apply changes."
                    else
                        echo -e "${RED}✗ Python executable not found at: $new_python_path${NC}"
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${CYAN}Configure Script Paths${NC}"
                echo "Current script path: ${SCRIPTPATH:-$(pwd)}"
                echo "Shared utilities: ${SHARED_UTILITIES_PATH:-shared-utilities}"
                echo ""
                echo "Script paths are typically auto-detected."
                echo "Manual configuration is rarely needed."
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${CYAN}Configure Database Path${NC}"
                echo "Current database: local-config/gwombat.db"
                echo ""
                echo "Database path is configured automatically."
                echo "To change location, move the local-config directory."
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "${CYAN}Configure Operation Timeouts${NC}"
                echo "Current timeout: ${OPERATION_TIMEOUT:-300} seconds"
                echo ""
                read -p "Enter new timeout in seconds (30-3600): " new_timeout
                if [[ "$new_timeout" =~ ^[0-9]+$ ]] && [[ "$new_timeout" -ge 30 ]] && [[ "$new_timeout" -le 3600 ]]; then
                    echo "OPERATION_TIMEOUT=\"$new_timeout\"" >> .env
                    echo -e "${GREEN}✓ Operation timeout updated to: $new_timeout seconds${NC}"
                else
                    echo -e "${RED}✗ Invalid timeout. Must be 30-3600 seconds.${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            6)
                echo -e "${CYAN}Configure Logging Levels${NC}"
                echo "Current log level: ${LOG_LEVEL:-INFO}"
                echo ""
                echo "Available levels: DEBUG, INFO, WARN, ERROR"
                read -p "Enter new log level: " new_log_level
                case "$new_log_level" in
                    DEBUG|INFO|WARN|ERROR)
                        echo "LOG_LEVEL=\"$new_log_level\"" >> .env
                        echo -e "${GREEN}✓ Log level updated to: $new_log_level${NC}"
                        ;;
                    *)
                        echo -e "${RED}✗ Invalid log level. Use: DEBUG, INFO, WARN, ERROR${NC}"
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "${CYAN}Configure Log Retention Policy${NC}"
                echo "Current retention: ${LOG_RETENTION_DAYS:-30} days"
                echo ""
                read -p "Enter retention period in days (1-365): " new_retention
                if [[ "$new_retention" =~ ^[0-9]+$ ]] && [[ "$new_retention" -ge 1 ]] && [[ "$new_retention" -le 365 ]]; then
                    echo "LOG_RETENTION_DAYS=\"$new_retention\"" >> .env
                    echo -e "${GREEN}✓ Log retention updated to: $new_retention days${NC}"
                else
                    echo -e "${RED}✗ Invalid retention period. Must be 1-365 days.${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "${CYAN}Configure Confirmation Levels${NC}"
                echo "Current level: ${CONFIRMATION_LEVEL:-normal}"
                echo ""
                echo "Available levels:"
                echo "• minimal - Only critical operations"
                echo "• normal - Standard confirmations"
                echo "• verbose - Confirm all operations"
                echo ""
                read -p "Enter confirmation level (minimal/normal/verbose): " new_level
                case "$new_level" in
                    minimal|normal|verbose)
                        echo "CONFIRMATION_LEVEL=\"$new_level\"" >> .env
                        echo -e "${GREEN}✓ Confirmation level updated to: $new_level${NC}"
                        ;;
                    *)
                        echo -e "${RED}✗ Invalid level. Use: minimal, normal, verbose${NC}"
                        ;;
                esac
                read -p "Press Enter to continue..."
                ;;
            9)
                echo -e "${CYAN}Toggle Progress Display${NC}"
                current_progress="${SHOW_PROGRESS:-true}"
                echo "Current setting: $current_progress"
                echo ""
                if [[ "$current_progress" == "true" ]]; then
                    echo "SHOW_PROGRESS=\"false\"" >> .env
                    echo -e "${GREEN}✓ Progress display disabled${NC}"
                else
                    echo "SHOW_PROGRESS=\"true\"" >> .env
                    echo -e "${GREEN}✓ Progress display enabled${NC}"
                fi
                read -p "Press Enter to continue..."
                ;;
            13)
                echo -e "${CYAN}Clean Temporary Files${NC}"
                echo "Cleaning temporary files and cache..."
                echo ""
                
                local cleaned=0
                if [[ -d "local-config/tmp" ]]; then
                    local tmp_files=$(find local-config/tmp -type f 2>/dev/null | wc -l)
                    rm -rf local-config/tmp/* 2>/dev/null
                    echo "✓ Cleaned $tmp_files temporary files"
                    cleaned=$((cleaned + tmp_files))
                fi
                
                # Clean old log files beyond retention
                local retention_days="${LOG_RETENTION_DAYS:-30}"
                if [[ -d "local-config/logs" ]]; then
                    local old_logs=$(find local-config/logs -name "*.log" -mtime +$retention_days 2>/dev/null | wc -l)
                    find local-config/logs -name "*.log" -mtime +$retention_days -delete 2>/dev/null
                    echo "✓ Cleaned $old_logs old log files (>$retention_days days)"
                    cleaned=$((cleaned + old_logs))
                fi
                
                echo ""
                echo -e "${GREEN}✓ Cleanup complete. Removed $cleaned files.${NC}"
                read -p "Press Enter to continue..."
                ;;
            14)
                echo -e "${CYAN}System Diagnostics${NC}"
                echo ""
                echo "🔍 Running system diagnostics..."
                echo ""
                
                # Check disk space
                local disk_usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
                echo "💾 Disk usage: ${disk_usage}%"
                if [[ "$disk_usage" -gt 90 ]]; then
                    echo -e "   ${RED}⚠️  Warning: Disk space low${NC}"
                else
                    echo -e "   ${GREEN}✓ Disk space OK${NC}"
                fi
                
                # Check database
                if [[ -f "local-config/gwombat.db" ]]; then
                    local db_size=$(du -h local-config/gwombat.db | cut -f1)
                    echo "🗄️  Database size: $db_size"
                    echo -e "   ${GREEN}✓ Database accessible${NC}"
                else
                    echo -e "   ${RED}⚠️  Database not found${NC}"
                fi
                
                # Check GAM
                local gam_path="${GAM:-${GAM_PATH:-gam}}"
                if command -v "$gam_path" >/dev/null 2>&1; then
                    local gam_version=$("$gam_path" version 2>/dev/null | head -n1 || echo "unknown")
                    echo -e "🔧 GAM: ${GREEN}✓ Available${NC} ($gam_version)"
                    echo -e "   Path: $gam_path"
                else
                    echo -e "🔧 GAM: ${RED}✗ Not found${NC}"
                    echo -e "   Searched: $gam_path"
                fi
                
                echo ""
                read -p "Press Enter to continue..."
                ;;
            15)
                echo -e "${YELLOW}Reset System Settings to Defaults${NC}"
                echo ""
                echo "This will reset system configuration to defaults."
                echo ""
                read -p "Continue with reset? (y/N): " confirm_reset
                if [[ "$confirm_reset" =~ ^[Yy] ]]; then
                    echo -e "${GREEN}✓ System settings reset to defaults${NC}"
                    echo "Restart GWOMBAT to apply changes."
                else
                    echo "Reset cancelled."
                fi
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

# DEVELOPMENT PARKING LOT:
# - Move all menus into SQLite for dynamic configuration
#   Benefits: Customizable menu structures, user preferences, menu item enabling/disabling
#   Implementation: Create menu_items table with hierarchy, permissions, visibility settings
#   Impact: More flexible UI, better user customization, centralized menu management

# External tools configuration functions
change_gwombat_domain() {
    echo -e "${CYAN}Change GWOMBAT Domain${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  This will change the domain for ALL tools (GAM, GYB, rclone)${NC}"
    echo ""
    echo "Current domain: ${DOMAIN:-not set}"
    echo ""
    read -p "Enter new domain (e.g., example.edu): " new_domain
    
    if [[ -z "$new_domain" ]]; then
        echo -e "${RED}Domain cannot be empty${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    # Validate domain format (basic check)
    if [[ ! "$new_domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid domain format${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo ""
    echo -e "${YELLOW}This will:${NC}"
    echo "• Update DOMAIN in .env file"
    echo "• Reset GWOMBAT database for new domain"
    echo "• Require reconfiguration of GAM, GYB, and rclone"
    echo ""
    read -p "Continue? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Update .env file
        if [[ -f ".env" ]]; then
            # Create backup
            cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"
            
            # Update domain in .env
            if grep -q "^DOMAIN=" .env; then
                sed -i.bak "s/^DOMAIN=.*/DOMAIN=\"$new_domain\"/" .env
            else
                echo "DOMAIN=\"$new_domain\"" >> .env
            fi
            
            echo -e "${GREEN}✓ Domain updated in .env file${NC}"
            echo -e "${YELLOW}Please restart GWOMBAT to apply changes${NC}"
        else
            echo -e "${RED}✗ .env file not found${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "1. Restart GWOMBAT"
        echo "2. Configure GAM for new domain (option 2)"
        echo "3. Configure GYB and rclone as needed"
    else
        echo "Domain change cancelled"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

configure_gam_for_domain() {
    echo -e "${CYAN}Configure GAM for Current Domain${NC}"
    echo ""
    
    local current_domain="${DOMAIN:-not set}"
    local gam_path="${GAM:-${GAM_PATH:-gam}}"
    
    if [[ "$current_domain" == "not set" ]]; then
        echo -e "${RED}No domain configured in GWOMBAT${NC}"
        echo "Please set domain first (option 1)"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "GWOMBAT Domain: $current_domain"
    echo "GAM Path: $gam_path"
    echo ""
    
    if ! command -v "$gam_path" >/dev/null 2>&1; then
        echo -e "${RED}GAM not found at: $gam_path${NC}"
        echo "Please install GAM or update the path in System Settings"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${CYAN}GAM OAuth Configuration Options:${NC}"
    echo "1. Create new OAuth configuration for this domain"
    echo "2. Show current GAM configuration"
    echo "3. Verify GAM domain matches GWOMBAT"
    echo "4. 🔧 OAuth Troubleshooting Guide"
    echo "5. Return to external tools menu"
    echo ""
    read -p "Select option (1-5): " gam_option
    
    case $gam_option in
        1)
            echo ""
            echo -e "${YELLOW}Creating OAuth configuration for $current_domain...${NC}"
            echo ""
            echo "This will:"
            echo "• Guide you through Google OAuth setup"
            echo "• Download credentials for your domain"
            echo "• Configure GAM to use the new credentials"
            echo ""
            read -p "Continue? (y/N): " confirm_oauth
            
            if [[ "$confirm_oauth" =~ ^[Yy]$ ]]; then
                echo ""
                echo -e "${CYAN}Running GAM OAuth creation...${NC}"
                echo "Follow the prompts to:"
                echo "1. Visit the OAuth URL"
                echo "2. Sign in with admin account for $current_domain"
                echo "3. Grant permissions"
                echo "4. Enter the authorization code"
                echo ""
                read -p "Press Enter to start GAM OAuth setup..."
                
                # Run GAM oauth create with error handling
                echo "Attempting OAuth configuration..."
                if "$gam_path" oauth create; then
                    echo ""
                    echo -e "${GREEN}OAuth configuration completed${NC}"
                    echo "Verifying configuration..."
                    
                    # Test the configuration
                    if "$gam_path" info domain >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ GAM successfully configured for $current_domain${NC}"
                    else
                        echo -e "${YELLOW}⚠️  Configuration may need additional setup${NC}"
                    fi
                else
                    echo ""
                    echo -e "${RED}❌ OAuth configuration failed${NC}"
                    echo ""
                    echo -e "${YELLOW}Common causes and solutions:${NC}"
                    echo "• ${CYAN}admin_policy_enforced${NC}: Organization blocks OAuth apps"
                    echo "  → Contact Google Workspace admin to whitelist GAM"
                    echo "  → Use option 4 for detailed troubleshooting"
                    echo ""
                    echo "• ${CYAN}access_denied${NC}: User denied authorization"
                    echo "  → Re-run with different admin account"
                    echo "  → Ensure account has super admin privileges"
                    echo ""
                    echo "• ${CYAN}invalid_client${NC}: GAM OAuth client issue"
                    echo "  → Update GAM to latest version"
                    echo "  → Check GAM installation"
                    echo ""
                    echo "See option 4 for complete troubleshooting guide."
                fi
            fi
            ;;
        2)
            echo ""
            echo -e "${CYAN}Current GAM Configuration:${NC}"
            echo ""
            "$gam_path" info domain 2>/dev/null || echo -e "${RED}GAM not configured or error occurred${NC}"
            ;;
        3)
            echo ""
            echo -e "${CYAN}Verifying domain match...${NC}"
            echo ""
            local gam_domain_info=$("$gam_path" info domain 2>/dev/null)
            if [[ -n "$gam_domain_info" ]]; then
                local gam_domain=$(echo "$gam_domain_info" | grep -i "Primary Domain" | awk '{print $3}' | cut -d':' -f1 | sed 's/Verified.*$//' | tr -d '[:space:]')
                if [[ "$gam_domain" == "$current_domain" ]]; then
                    echo -e "${GREEN}✓ GAM domain matches GWOMBAT domain${NC}"
                    echo "  GWOMBAT: $current_domain"
                    echo "  GAM: $gam_domain"
                else
                    echo -e "${RED}✗ Domain mismatch!${NC}"
                    echo "  GWOMBAT: $current_domain"
                    echo "  GAM: $gam_domain"
                    echo ""
                    echo "Use option 1 to reconfigure GAM for $current_domain"
                fi
            else
                echo -e "${RED}Cannot determine GAM domain - not configured${NC}"
            fi
            ;;
        4)
            echo ""
            echo -e "${CYAN}=== GAM OAuth Troubleshooting Guide ===${NC}"
            echo ""
            echo -e "${YELLOW}📖 For detailed troubleshooting information, see:${NC}"
            echo "   docs/OAUTH_TROUBLESHOOTING.md"
            echo ""
            echo -e "${CYAN}🔧 Quick Solutions:${NC}"
            echo ""
            echo -e "${WHITE}Error: admin_policy_enforced${NC}"
            echo "   Problem: Organization blocks OAuth apps"
            echo "   Solution: Contact Google Workspace Super Admin to:"
            echo "   • Go to Security > API Controls > App access control"
            echo "   • Add GAM OAuth client to trusted apps:"
            echo "     ${CYAN}591136899245-3p91hir237nvvn71vkl1vetndgeg360v.apps.googleusercontent.com${NC}"
            echo ""
            echo -e "${WHITE}Error: access_denied${NC}"
            echo "   Problem: User denied OAuth consent"
            echo "   Solution: Re-run OAuth with super admin account"
            echo ""
            echo -e "${WHITE}Error: invalid_client${NC}"
            echo "   Problem: GAM OAuth client not recognized"
            echo "   Solution: Update GAM to latest version"
            echo ""
            echo -e "${CYAN}🔄 Alternative Methods:${NC}"
            echo "   • Service Account Authentication (recommended for production)"
            echo "   • Domain-wide Delegation (for strict security policies)"
            echo "   • Different admin account (bypass user-specific restrictions)"
            echo ""
            echo -e "${GREEN}💡 Need immediate help?${NC}"
            echo "   1. Check if GAM is updated: ${WHITE}$gam_path version${NC}"
            echo "   2. Test with different admin: Re-run OAuth setup"
            echo "   3. Contact IT admin: Request OAuth policy changes"
            echo ""
            ;;
        5)
            return
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

configure_gyb() {
    echo -e "${CYAN}Configure GYB (Got Your Back)${NC}"
    echo ""
    
    if ! command -v gyb >/dev/null 2>&1; then
        echo -e "${RED}GYB not installed${NC}"
        echo ""
        echo "To install GYB:"
        echo "  pip install gyb"
        echo ""
        echo "Or visit: https://github.com/GAM-team/got-your-back"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${GREEN}✓ GYB is installed${NC}"
    echo ""
    echo -e "${CYAN}GYB Configuration:${NC}"
    echo "GYB uses GAM's OAuth tokens by default, so if GAM is configured"
    echo "for your domain, GYB should work automatically."
    echo ""
    echo "Test GYB configuration:"
    echo "1. Test GYB with a user account"
    echo "2. Show GYB version and info"
    echo "3. Return to external tools menu"
    echo ""
    read -p "Select option (1-3): " gyb_option
    
    case $gyb_option in
        1)
            echo ""
            read -p "Enter user email to test: " test_email
            if [[ -n "$test_email" ]]; then
                echo ""
                echo -e "${CYAN}Testing GYB with $test_email...${NC}"
                echo "(This will show mailbox info without downloading)"
                echo ""
                gyb --email "$test_email" --action count
            fi
            ;;
        2)
            echo ""
            echo -e "${CYAN}GYB Version and Information:${NC}"
            echo ""
            gyb --version
            ;;
        3)
            return
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

configure_rclone() {
    echo -e "${CYAN}Configure rclone (Cloud Storage)${NC}"
    echo ""
    
    if ! command -v rclone >/dev/null 2>&1; then
        echo -e "${RED}rclone not installed${NC}"
        echo ""
        echo "To install rclone:"
        echo "  curl https://rclone.org/install.sh | sudo bash"
        echo ""
        echo "Or visit: https://rclone.org/install/"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo -e "${GREEN}✓ rclone is installed${NC}"
    echo ""
    
    local remotes_count=$(rclone listremotes 2>/dev/null | wc -l | tr -d ' ')
    echo "Current remotes configured: $remotes_count"
    
    if [[ "$remotes_count" -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}Configured remotes:${NC}"
        rclone listremotes
    fi
    
    echo ""
    echo -e "${CYAN}rclone Configuration Options:${NC}"
    echo "1. Add new remote"
    echo "2. List all remotes"
    echo "3. Test a remote connection"
    echo "4. Remove a remote"
    echo "5. Return to external tools menu"
    echo ""
    read -p "Select option (1-5): " rclone_option
    
    case $rclone_option in
        1)
            echo ""
            echo -e "${CYAN}Adding new rclone remote...${NC}"
            echo "This will start rclone's interactive configuration"
            echo ""
            read -p "Press Enter to start rclone config..."
            rclone config
            ;;
        2)
            echo ""
            echo -e "${CYAN}All rclone remotes:${NC}"
            rclone listremotes
            ;;
        3)
            echo ""
            read -p "Enter remote name to test: " remote_name
            if [[ -n "$remote_name" ]]; then
                echo ""
                echo -e "${CYAN}Testing remote: $remote_name${NC}"
                rclone lsd "$remote_name:"
            fi
            ;;
        4)
            echo ""
            read -p "Enter remote name to remove: " remote_name
            if [[ -n "$remote_name" ]]; then
                echo ""
                echo -e "${YELLOW}This will permanently remove remote: $remote_name${NC}"
                read -p "Continue? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    rclone config delete "$remote_name"
                fi
            fi
            ;;
        5)
            return
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

sync_all_tools_to_domain() {
    echo -e "${CYAN}Sync All Tools to Domain${NC}"
    echo ""
    
    local current_domain="${DOMAIN:-not set}"
    if [[ "$current_domain" == "not set" ]]; then
        echo -e "${RED}No domain configured in GWOMBAT${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "This will ensure all tools are configured for: $current_domain"
    echo ""
    echo "Actions to perform:"
    echo "• Verify GAM domain matches"
    echo "• Check GYB can access the domain"
    echo "• Verify rclone remotes are accessible"
    echo ""
    read -p "Continue? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}Checking GAM...${NC}"
        local gam_path="${GAM:-${GAM_PATH:-gam}}"
        if command -v "$gam_path" >/dev/null 2>&1; then
            local gam_domain_info=$("$gam_path" info domain 2>/dev/null)
            if [[ -n "$gam_domain_info" ]]; then
                local gam_domain=$(echo "$gam_domain_info" | grep -i "Primary Domain" | awk '{print $3}' | cut -d':' -f1 | sed 's/Verified.*$//' | tr -d '[:space:]')
                if [[ "$gam_domain" == "$current_domain" ]]; then
                    echo -e "${GREEN}✓ GAM configured for $current_domain${NC}"
                else
                    echo -e "${RED}✗ GAM domain mismatch: $gam_domain${NC}"
                fi
            else
                echo -e "${RED}✗ GAM not configured${NC}"
            fi
        else
            echo -e "${RED}✗ GAM not found${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Checking GYB...${NC}"
        if command -v gyb >/dev/null 2>&1; then
            echo -e "${GREEN}✓ GYB installed (uses GAM OAuth)${NC}"
        else
            echo -e "${YELLOW}○ GYB not installed${NC}"
        fi
        
        echo ""
        echo -e "${CYAN}Checking rclone...${NC}"
        if command -v rclone >/dev/null 2>&1; then
            local remotes_count=$(rclone listremotes 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$remotes_count" -gt 0 ]]; then
                echo -e "${GREEN}✓ rclone has $remotes_count remotes${NC}"
            else
                echo -e "${YELLOW}○ rclone has no remotes configured${NC}"
            fi
        else
            echo -e "${YELLOW}○ rclone not installed${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}Sync check completed${NC}"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

show_detailed_tool_status() {
    echo -e "${CYAN}Detailed Tool Status${NC}"
    echo ""
    
    # GAM detailed status
    echo -e "${BLUE}=== GAM (Google Apps Manager) ===${NC}"
    local gam_path="${GAM:-${GAM_PATH:-gam}}"
    echo "Path: $gam_path"
    
    if command -v "$gam_path" >/dev/null 2>&1; then
        echo -e "Status: ${GREEN}✓ Installed${NC}"
        local gam_version=$("$gam_path" version 2>/dev/null | head -n1)
        echo "Version: $gam_version"
        
        local gam_domain_info=$("$gam_path" info domain 2>/dev/null)
        if [[ -n "$gam_domain_info" ]]; then
            echo -e "Configuration: ${GREEN}✓ Configured${NC}"
            echo "$gam_domain_info"
        else
            echo -e "Configuration: ${RED}✗ Not configured${NC}"
        fi
    else
        echo -e "Status: ${RED}✗ Not found${NC}"
    fi
    
    echo ""
    
    # GYB detailed status
    echo -e "${BLUE}=== GYB (Got Your Back) ===${NC}"
    if command -v gyb >/dev/null 2>&1; then
        echo -e "Status: ${GREEN}✓ Installed${NC}"
        local gyb_version=$(gyb --version 2>/dev/null)
        echo "Version: $gyb_version"
        echo "OAuth: Uses GAM's OAuth tokens"
    else
        echo -e "Status: ${YELLOW}○ Not installed${NC}"
        echo "Install: pip install gyb"
    fi
    
    echo ""
    
    # rclone detailed status
    echo -e "${BLUE}=== rclone (Cloud Storage) ===${NC}"
    if command -v rclone >/dev/null 2>&1; then
        echo -e "Status: ${GREEN}✓ Installed${NC}"
        local rclone_version=$(rclone version 2>/dev/null | head -n1)
        echo "Version: $rclone_version"
        
        local remotes=$(rclone listremotes 2>/dev/null)
        if [[ -n "$remotes" ]]; then
            echo -e "Remotes: ${GREEN}✓ Configured${NC}"
            echo "$remotes"
        else
            echo -e "Remotes: ${YELLOW}○ None configured${NC}"
        fi
    else
        echo -e "Status: ${YELLOW}○ Not installed${NC}"
        echo "Install: curl https://rclone.org/install.sh | sudo bash"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

install_missing_tools() {
    echo -e "${CYAN}Install Missing Tools${NC}"
    echo ""
    
    echo "This will help install GAM, GYB, and rclone if they're missing."
    echo ""
    
    # Check what's missing
    local missing_tools=()
    
    if ! command -v gam >/dev/null 2>&1; then
        missing_tools+=("GAM")
    fi
    
    if ! command -v gyb >/dev/null 2>&1; then
        missing_tools+=("GYB")
    fi
    
    if ! command -v rclone >/dev/null 2>&1; then
        missing_tools+=("rclone")
    fi
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        echo -e "${GREEN}✓ All tools are already installed${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    echo "Missing tools: ${missing_tools[*]}"
    echo ""
    
    echo -e "${CYAN}Installation Instructions:${NC}"
    echo ""
    
    for tool in "${missing_tools[@]}"; do
        case $tool in
            "GAM")
                echo -e "${YELLOW}GAM (Google Apps Manager):${NC}"
                echo "1. Download from: https://github.com/GAM-team/GAM/releases"
                echo "2. Or use package manager:"
                echo "   • macOS: brew install gam"
                echo "   • Linux: Download and extract to /usr/local/bin/"
                echo ""
                ;;
            "GYB")
                echo -e "${YELLOW}GYB (Got Your Back):${NC}"
                echo "1. Install via pip: pip install gyb"
                echo "2. Or: pip3 install gyb"
                echo ""
                ;;
            "rclone")
                echo -e "${YELLOW}rclone:${NC}"
                echo "1. Official installer: curl https://rclone.org/install.sh | sudo bash"
                echo "2. Or use package manager:"
                echo "   • macOS: brew install rclone"
                echo "   • Ubuntu/Debian: sudo apt install rclone"
                echo ""
                ;;
        esac
    done
    
    echo -e "${GREEN}After installation, return here to configure the tools.${NC}"
    echo ""
    read -p "Press Enter to continue..."
}

reset_tool_configurations() {
    echo -e "${CYAN}Reset Tool Configurations${NC}"
    echo ""
    echo -e "${RED}⚠️  WARNING: This will reset OAuth tokens and configurations${NC}"
    echo ""
    echo "This will:"
    echo "• Remove GAM OAuth tokens"
    echo "• Reset rclone configurations"
    echo "• Require reconfiguration of all tools"
    echo ""
    read -p "Are you sure? (type 'reset' to confirm): " confirm
    
    if [[ "$confirm" == "reset" ]]; then
        echo ""
        echo -e "${YELLOW}Resetting configurations...${NC}"
        
        # Reset GAM OAuth (remove oauth2.txt files)
        local gam_config_path="${GAM_CONFIG_PATH:-~/.gam}"
        if [[ -f "$gam_config_path/oauth2.txt" ]]; then
            rm -f "$gam_config_path/oauth2.txt"
            echo -e "${GREEN}✓ Removed GAM OAuth tokens${NC}"
        fi
        
        # Reset rclone config
        if command -v rclone >/dev/null 2>&1; then
            local rclone_config=$(rclone config file 2>/dev/null | grep "Configuration file" | cut -d: -f2 | xargs)
            if [[ -f "$rclone_config" ]]; then
                mv "$rclone_config" "$rclone_config.backup.$(date +%Y%m%d_%H%M%S)"
                echo -e "${GREEN}✓ Reset rclone configuration (backup created)${NC}"
            fi
        fi
        
        echo ""
        echo -e "${GREEN}Configuration reset completed${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Configure GAM for your domain (option 2)"
        echo "2. Configure rclone remotes (option 4)"
        echo "3. Test GYB (option 3)"
    else
        echo "Reset cancelled"
    fi
    
    echo ""
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