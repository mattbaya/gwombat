#!/bin/bash

# Enhanced Security Reports for GWOMBAT
# Leverages GAM7 advanced security capabilities for comprehensive monitoring

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
GAM="${GAM_PATH:-gam}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
DOMAIN="${DOMAIN:-your-domain.edu}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Initialize security reports database
init_security_db() {
    if [[ -f "../security_reports_schema.sql" ]]; then
        sqlite3 "$DB_PATH" < ../security_reports_schema.sql 2>/dev/null || true
        echo "Security reports database initialized."
        log_security "Security reports database initialized" "INFO"
    fi
}

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Security logging function
log_security() {
    local message="$1"
    local level="${2:-INFO}"
    local operation="${3:-security_scan}"
    
    execute_db "
    INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
    VALUES ('$level', '$SESSION_ID', '$operation', '$message', 'security_reports.sh');
    " >/dev/null 2>&1
}

# Check if GAM7 is available and get version
check_gam_version() {
    if ! command -v "$GAM" >/dev/null 2>&1; then
        echo "false|GAM not found"
        return 1
    fi
    
    local gam_version=$($GAM version 2>/dev/null | head -1 || echo "unknown")
    if [[ "$gam_version" == *"7."* ]] || [[ "$gam_version" == *"GAMADV-XS3"* ]]; then
        echo "true|$gam_version"
        return 0
    else
        echo "false|GAM version not supported for advanced security reports: $gam_version"
        return 1
    fi
}

# Scan user login activities and detect suspicious patterns
scan_login_activities() {
    local start_time=$(date +%s)
    local days_back="${1:-7}" # Default to last 7 days
    
    log_security "Starting login activities scan (${days_back} days)" "INFO" "login_scan"
    
    # Mark old login activities as historical
    execute_db "UPDATE login_activities SET status = 'historical' WHERE scan_time < datetime('now', '-${days_back} days');"
    
    echo -e "${BLUE}📊 Scanning login activities for last ${days_back} days...${NC}"
    
    # Get login reports from GAM7
    local cutoff_date=$(date -d "${days_back} days ago" '+%Y-%m-%d')
    local login_data
    
    # Use GAM7's advanced login reporting
    if login_data=$($GAM report logins start "$cutoff_date" 2>/dev/null); then
        echo "$login_data" | tail -n +2 | while IFS=',' read -r time user_email event_type ip_address user_agent; do
            # Skip empty lines
            [[ -z "$user_email" ]] && continue
            
            # Parse login time
            local login_time=$(echo "$time" | sed 's/T/ /' | cut -d'.' -f1)
            
            # Determine login type
            local login_type="successful"
            local is_suspicious=0
            local risk_score=0
            
            # Check for suspicious patterns
            case "$event_type" in
                *"login_failure"*|*"failed"*)
                    login_type="failed"
                    risk_score=30
                    ;;
                *"suspicious"*|*"unusual"*)
                    login_type="suspicious"
                    is_suspicious=1
                    risk_score=70
                    ;;
            esac
            
            # Basic device type detection from user agent
            local device_type="unknown"
            case "$user_agent" in
                *"Mobile"*|*"Android"*|*"iPhone"*) device_type="mobile" ;;
                *"Windows"*|*"Macintosh"*|*"Linux"*) device_type="desktop" ;;
            esac
            
            # Simple geographic risk assessment (this could be enhanced with IP geolocation)
            if [[ "$ip_address" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
                # Internal IP, lower risk
                risk_score=$((risk_score - 10))
            else
                # External IP, slightly higher risk
                risk_score=$((risk_score + 10))
            fi
            
            # Ensure risk score is within bounds
            [[ $risk_score -lt 0 ]] && risk_score=0
            [[ $risk_score -gt 100 ]] && risk_score=100
            
            # Store login activity
            execute_db "
            INSERT INTO login_activities (
                user_email, login_time, login_type, ip_address, user_agent,
                device_type, is_suspicious, risk_score, session_id
            ) VALUES (
                '$user_email', '$login_time', '$login_type', '$ip_address',
                '$(echo "$user_agent" | tr "'" "''")', '$device_type', $is_suspicious, $risk_score, '$SESSION_ID'
            );"
        done
        
        log_security "Login activities scan completed" "INFO" "login_scan"
    else
        log_security "Failed to retrieve login reports from GAM" "WARNING" "login_scan"
        echo -e "${YELLOW}Warning: Unable to retrieve login reports. GAM7 may not be properly configured.${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update metrics
    local total_logins=$(execute_db "SELECT COUNT(*) FROM login_activities WHERE session_id = '$SESSION_ID';")
    local suspicious_logins=$(execute_db "SELECT COUNT(*) FROM login_activities WHERE is_suspicious = 1 AND session_id = '$SESSION_ID';")
    local failed_logins=$(execute_db "SELECT COUNT(*) FROM login_activities WHERE login_type = 'failed' AND session_id = '$SESSION_ID';")
    
    execute_db "
    INSERT OR REPLACE INTO security_metrics (metric_name, metric_value, metric_category, session_id, status)
    VALUES 
        ('Total Logins Scanned', $total_logins, 'authentication', '$SESSION_ID', 'current'),
        ('Suspicious Logins (${days_back}d)', $suspicious_logins, 'authentication', '$SESSION_ID', 'current'),
        ('Failed Logins (${days_back}d)', $failed_logins, 'authentication', '$SESSION_ID', 'current');
    "
    
    echo -e "${GREEN}✓ Login activities scan completed${NC}"
    echo "  Total logins: $total_logins"
    echo "  Suspicious: $suspicious_logins"
    echo "  Failed: $failed_logins"
    echo "  Duration: ${duration}s"
}

# Scan admin activities for security monitoring
scan_admin_activities() {
    local start_time=$(date +%s)
    local days_back="${1:-1}" # Default to last 1 day for admin activities
    
    log_security "Starting admin activities scan (${days_back} days)" "INFO" "admin_scan"
    
    echo -e "${BLUE}🔐 Scanning admin activities for last ${days_back} days...${NC}"
    
    # Get admin activity reports from GAM7
    local cutoff_date=$(date -d "${days_back} days ago" '+%Y-%m-%d')
    local admin_data
    
    # Use GAM7's admin audit reporting
    if admin_data=$($GAM report admin start "$cutoff_date" 2>/dev/null); then
        echo "$admin_data" | tail -n +2 | while IFS=',' read -r time admin_email event_name target_user ip_address; do
            # Skip empty lines
            [[ -z "$admin_email" ]] && continue
            
            # Parse activity time
            local activity_time=$(echo "$time" | sed 's/T/ /' | cut -d'.' -f1)
            
            # Categorize admin activities
            local activity_type="unknown"
            case "$event_name" in
                *"CREATE_USER"*|*"user_create"*) activity_type="user_create" ;;
                *"SUSPEND_USER"*|*"user_suspend"*) activity_type="user_suspend" ;;
                *"DELETE_USER"*|*"user_delete"*) activity_type="user_delete" ;;
                *"GRANT_ADMIN"*|*"admin_grant"*) activity_type="privilege_grant" ;;
                *"REVOKE_ADMIN"*|*"admin_revoke"*) activity_type="privilege_revoke" ;;
                *"SETTINGS"*|*"settings"*) activity_type="settings_change" ;;
                *"GROUP"*|*"group"*) activity_type="group_management" ;;
                *"OU"*|*"org_unit"*) activity_type="ou_management" ;;
                *) activity_type="other" ;;
            esac
            
            # Determine privilege level (this could be enhanced with actual role checking)
            local privilege_level="admin"
            if [[ "$event_name" == *"SUPER_ADMIN"* ]]; then
                privilege_level="super_admin"
            fi
            
            # Store admin activity
            execute_db "
            INSERT INTO admin_activities (
                admin_email, activity_time, activity_type, target_user, 
                ip_address, privilege_level, session_id,
                action_details
            ) VALUES (
                '$admin_email', '$activity_time', '$activity_type', 
                '$(echo "$target_user" | tr "'" "''")' || '', '$ip_address', '$privilege_level', '$SESSION_ID',
                json_object('event_name', '$event_name', 'raw_data', '$(echo "$time,$admin_email,$event_name,$target_user,$ip_address" | tr "'" "''")')
            );"
        done
        
        log_security "Admin activities scan completed" "INFO" "admin_scan"
    else
        log_security "Failed to retrieve admin reports from GAM" "WARNING" "admin_scan"
        echo -e "${YELLOW}Warning: Unable to retrieve admin reports. GAM7 may not be properly configured.${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update metrics
    local total_admin_actions=$(execute_db "SELECT COUNT(*) FROM admin_activities WHERE session_id = '$SESSION_ID';")
    local privilege_changes=$(execute_db "SELECT COUNT(*) FROM admin_activities WHERE activity_type IN ('privilege_grant', 'privilege_revoke') AND session_id = '$SESSION_ID';")
    
    execute_db "
    INSERT OR REPLACE INTO security_metrics (metric_name, metric_value, metric_category, session_id, status)
    VALUES 
        ('Admin Actions (${days_back}d)', $total_admin_actions, 'admin', '$SESSION_ID', 'current'),
        ('Privilege Changes (${days_back}d)', $privilege_changes, 'admin', '$SESSION_ID', 'current');
    "
    
    echo -e "${GREEN}✓ Admin activities scan completed${NC}"
    echo "  Total admin actions: $total_admin_actions"
    echo "  Privilege changes: $privilege_changes"
    echo "  Duration: ${duration}s"
}

# Scan security compliance (2FA, password policies, etc.)
scan_security_compliance() {
    local start_time=$(date +%s)
    
    log_security "Starting security compliance scan" "INFO" "compliance_scan"
    
    # Mark old compliance data as historical
    execute_db "UPDATE security_compliance SET status = 'historical' WHERE status = 'current';"
    
    echo -e "${BLUE}🛡️  Scanning security compliance...${NC}"
    
    # Get user security settings from GAM7
    local users_data
    if users_data=$($GAM print users fields primaryEmail,isEnforcedIn2Sv,lastLoginTime,recoveryEmail,recoveryPhone 2>/dev/null); then
        local total_users=0
        local twofa_enabled=0
        local recovery_set=0
        
        echo "$users_data" | tail -n +2 | while IFS=',' read -r user_email twofa_enforced last_login recovery_email recovery_phone; do
            # Skip empty lines
            [[ -z "$user_email" ]] && continue
            
            ((total_users++))
            
            # Check 2FA compliance
            local two_factor_enabled=0
            if [[ "$twofa_enforced" == "True" ]] || [[ "$twofa_enforced" == "true" ]]; then
                two_factor_enabled=1
                ((twofa_enabled++))
            fi
            
            # Check recovery info
            local recovery_info_set=0
            if [[ -n "$recovery_email" ]] || [[ -n "$recovery_phone" ]]; then
                recovery_info_set=1
                ((recovery_set++))
            fi
            
            # Calculate compliance score (0-100)
            local compliance_score=0
            [[ $two_factor_enabled -eq 1 ]] && compliance_score=$((compliance_score + 50))
            [[ $recovery_info_set -eq 1 ]] && compliance_score=$((compliance_score + 30))
            [[ -n "$last_login" ]] && compliance_score=$((compliance_score + 20))
            
            # Determine overall compliance status
            local compliance_status="non_compliant"
            if [[ $compliance_score -ge 80 ]]; then
                compliance_status="compliant"
            elif [[ $compliance_score -ge 60 ]]; then
                compliance_status="warning"
            fi
            
            # Store compliance data
            execute_db "
            INSERT INTO security_compliance (
                user_email, compliance_type, compliance_status, compliance_score,
                two_factor_enabled, recovery_info_set, session_id, status,
                issue_details
            ) VALUES (
                '$user_email', 'account_security', '$compliance_status', $compliance_score,
                $two_factor_enabled, $recovery_info_set, '$SESSION_ID', 'current',
                json_object(
                    'twofa_enforced', '$twofa_enforced',
                    'last_login', '$last_login',
                    'recovery_email_set', '$([ -n "$recovery_email" ] && echo "true" || echo "false")',
                    'recovery_phone_set', '$([ -n "$recovery_phone" ] && echo "true" || echo "false")'
                )
            );"
        done
        
        # Calculate percentages and update metrics
        if [[ $total_users -gt 0 ]]; then
            local twofa_percentage=$((twofa_enabled * 100 / total_users))
            local recovery_percentage=$((recovery_set * 100 / total_users))
            
            execute_db "
            INSERT OR REPLACE INTO security_metrics (metric_name, metric_value, metric_percentage, metric_category, total_users, session_id, status)
            VALUES 
                ('2FA Enabled Users', $twofa_enabled, $twofa_percentage, 'authentication', $total_users, '$SESSION_ID', 'current'),
                ('Recovery Info Set', $recovery_set, $recovery_percentage, 'authentication', $total_users, '$SESSION_ID', 'current'),
                ('Total Users Scanned', $total_users, 100, 'overview', $total_users, '$SESSION_ID', 'current');
            "
        fi
        
        log_security "Security compliance scan completed: $total_users users" "INFO" "compliance_scan"
    else
        log_security "Failed to retrieve user security data from GAM" "WARNING" "compliance_scan"
        echo -e "${YELLOW}Warning: Unable to retrieve user security data. GAM7 may not be properly configured.${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo -e "${GREEN}✓ Security compliance scan completed${NC}"
    echo "  Duration: ${duration}s"
}

# Scan OAuth applications and user grants
scan_oauth_applications() {
    local start_time=$(date +%s)
    
    log_security "Starting OAuth applications scan" "INFO" "oauth_scan"
    
    echo -e "${BLUE}🔗 Scanning OAuth applications...${NC}"
    
    # Get OAuth applications from GAM7
    local oauth_data
    if oauth_data=$($GAM print oauth 2>/dev/null); then
        echo "$oauth_data" | tail -n +2 | while IFS=',' read -r client_id app_name app_type scopes; do
            # Skip empty lines
            [[ -z "$client_id" ]] && continue
            
            # Analyze scope risk level
            local high_risk_scopes=0
            local risk_level="low"
            
            # Check for high-risk scopes
            case "$scopes" in
                *"admin.directory"*|*"admin.reports"*|*"admin.datatransfer"*)
                    high_risk_scopes=$((high_risk_scopes + 3))
                    risk_level="critical"
                    ;;
                *"drive"*|*"gmail.readonly"*|*"calendar"*)
                    high_risk_scopes=$((high_risk_scopes + 2))
                    [[ "$risk_level" == "low" ]] && risk_level="medium"
                    ;;
                *"userinfo"*|*"profile"*)
                    high_risk_scopes=$((high_risk_scopes + 1))
                    [[ "$risk_level" == "low" ]] && risk_level="low"
                    ;;
            esac
            
            # Determine if app is likely internal
            local is_internal=0
            if [[ "$app_name" == *"$DOMAIN"* ]] || [[ "$client_id" == *".googleusercontent.com" ]]; then
                is_internal=1
                # Lower risk for internal apps
                [[ "$risk_level" == "critical" ]] && risk_level="high"
                [[ "$risk_level" == "high" ]] && risk_level="medium"
            fi
            
            # Store OAuth application data
            execute_db "
            INSERT OR REPLACE INTO oauth_applications (
                app_id, app_name, app_type, client_id, scopes,
                high_risk_scopes, risk_level, is_internal, session_id
            ) VALUES (
                '$client_id', '$(echo "$app_name" | tr "'" "''")', '$app_type', '$client_id',
                '$(echo "$scopes" | tr "'" "''")', $high_risk_scopes, '$risk_level', $is_internal, '$SESSION_ID'
            );"
        done
        
        log_security "OAuth applications scan completed" "INFO" "oauth_scan"
    else
        log_security "Failed to retrieve OAuth applications from GAM" "WARNING" "oauth_scan"
        echo -e "${YELLOW}Warning: Unable to retrieve OAuth applications. GAM7 may not be properly configured.${NC}"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Update metrics
    local total_apps=$(execute_db "SELECT COUNT(*) FROM oauth_applications WHERE session_id = '$SESSION_ID';")
    local high_risk_apps=$(execute_db "SELECT COUNT(*) FROM oauth_applications WHERE risk_level IN ('high', 'critical') AND session_id = '$SESSION_ID';")
    
    execute_db "
    INSERT OR REPLACE INTO security_metrics (metric_name, metric_value, metric_category, session_id, status)
    VALUES 
        ('OAuth Apps Total', $total_apps, 'access', '$SESSION_ID', 'current'),
        ('High Risk OAuth Apps', $high_risk_apps, 'access', '$SESSION_ID', 'current');
    "
    
    echo -e "${GREEN}✓ OAuth applications scan completed${NC}"
    echo "  Total apps: $total_apps"
    echo "  High risk apps: $high_risk_apps"
    echo "  Duration: ${duration}s"
}

# Generate comprehensive security report
generate_security_report() {
    local report_type="${1:-full}" # full, summary, alerts
    local output_file="${2:-reports/security_report_$(date +%Y%m%d_%H%M%S).txt}"
    
    mkdir -p "$(dirname "$output_file")"
    
    echo -e "${CYAN}📋 Generating security report: $report_type${NC}"
    
    {
        echo "=========================================="
        echo "         GWOMBAT SECURITY REPORT"
        echo "=========================================="
        echo "Generated: $(date)"
        echo "Report Type: $report_type"
        echo "Session ID: $SESSION_ID"
        echo ""
        
        # Security Health Summary
        echo "=== SECURITY HEALTH SUMMARY ==="
        execute_db "
        SELECT 
            metric_category as 'Category',
            printf('%.1f%%', avg_percentage) as 'Average Score',
            metric_count as 'Metrics',
            last_updated as 'Last Updated'
        FROM security_health_summary
        ORDER BY metric_category;
        " | column -t -s '|'
        echo ""
        
        # Recent Security Alerts
        echo "=== RECENT SECURITY ALERTS (24h) ==="
        local alerts_exist=$(execute_db "SELECT COUNT(*) FROM recent_security_alerts;")
        if [[ "$alerts_exist" -gt 0 ]]; then
            execute_db "
            SELECT 
                alert_type as 'Alert Type',
                severity as 'Severity',
                alert_count as 'Count',
                unresolved_count as 'Unresolved',
                latest_alert as 'Latest'
            FROM recent_security_alerts
            ORDER BY severity DESC, alert_count DESC;
            " | column -t -s '|'
        else
            echo "No security alerts in the last 24 hours."
        fi
        echo ""
        
        # Compliance Summary
        echo "=== COMPLIANCE SUMMARY ==="
        execute_db "
        SELECT 
            compliance_type as 'Type',
            compliance_status as 'Status',
            user_count as 'Users',
            printf('%.1f%%', percentage) as 'Percentage',
            printf('%.0f', avg_score) as 'Avg Score'
        FROM compliance_summary
        ORDER BY compliance_type, compliance_status;
        " | column -t -s '|'
        echo ""
        
        if [[ "$report_type" == "full" ]]; then
            # Suspicious Activity Details
            echo "=== SUSPICIOUS ACTIVITY SUMMARY ==="
            execute_db "
            SELECT 
                activity_type as 'Activity Type',
                incident_count as 'Incidents',
                affected_users as 'Users Affected',
                latest_incident as 'Latest Incident'
            FROM suspicious_activity_summary
            WHERE incident_count > 0
            ORDER BY incident_count DESC;
            " | column -t -s '|'
            echo ""
            
            # Admin Activity Summary
            echo "=== ADMIN ACTIVITY SUMMARY (24h) ==="
            local admin_activity_exists=$(execute_db "SELECT COUNT(*) FROM admin_activity_summary;")
            if [[ "$admin_activity_exists" -gt 0 ]]; then
                execute_db "
                SELECT 
                    admin_email as 'Admin',
                    activity_type as 'Activity',
                    action_count as 'Actions',
                    users_affected as 'Users Affected',
                    latest_action as 'Latest Action'
                FROM admin_activity_summary
                ORDER BY action_count DESC
                LIMIT 20;
                " | column -t -s '|'
            else
                echo "No admin activity in the last 24 hours."
            fi
            echo ""
            
            # Top Security Metrics
            echo "=== KEY SECURITY METRICS ==="
            execute_db "
            SELECT 
                metric_name as 'Metric',
                metric_value as 'Value',
                CASE WHEN metric_percentage IS NOT NULL 
                     THEN printf('%.1f%%', metric_percentage) 
                     ELSE '-' END as 'Percentage',
                metric_category as 'Category'
            FROM security_metrics 
            WHERE status = 'current' 
            ORDER BY metric_category, metric_name;
            " | column -t -s '|'
        fi
        
        echo ""
        echo "=========================================="
        echo "Report generated by GWOMBAT Security Reports"
        echo "For questions or issues, check the system logs"
        echo "=========================================="
        
    } > "$output_file"
    
    echo -e "${GREEN}✓ Security report generated: $output_file${NC}"
    
    # Also display summary on screen
    if [[ "$report_type" == "summary" ]] || [[ "$report_type" == "alerts" ]]; then
        echo ""
        echo -e "${CYAN}=== SECURITY SUMMARY ===${NC}"
        cat "$output_file"
    fi
}

# Show security dashboard
show_security_dashboard() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                        🔒 SECURITY DASHBOARD                               ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check GAM7 availability
    local gam_status=$(check_gam_version)
    IFS='|' read -r gam_available gam_info <<< "$gam_status"
    
    if [[ "$gam_available" == "false" ]]; then
        echo -e "${RED}⚠️  GAM7 not available: $gam_info${NC}"
        echo -e "${YELLOW}Enhanced security reports require GAM7 (GAMADV-XS3)${NC}"
        echo ""
        return 1
    else
        echo -e "${GREEN}✓ GAM7 Available: $gam_info${NC}"
        echo ""
    fi
    
    # Get latest security metrics
    local metrics=$(execute_db "
    SELECT metric_name, metric_value, metric_percentage, metric_category 
    FROM security_metrics 
    WHERE status = 'current' 
    ORDER BY metric_category, metric_name;
    ")
    
    if [[ -n "$metrics" ]]; then
        # Parse and display metrics by category
        echo -e "${CYAN}🛡️  AUTHENTICATION & ACCESS${NC}"
        echo "$metrics" | grep "|authentication|" | while IFS='|' read -r name value percentage category; do
            local display_value="$value"
            if [[ -n "$percentage" ]] && [[ "$percentage" != "null" ]]; then
                display_value="$value (${percentage}%)"
            fi
            printf "%-30s ${WHITE}%s${NC}\n" "$name:" "$display_value"
        done
        echo ""
        
        echo -e "${CYAN}🔐 ADMIN ACTIVITIES${NC}"
        echo "$metrics" | grep "|admin|" | while IFS='|' read -r name value percentage category; do
            local display_value="$value"
            printf "%-30s ${WHITE}%s${NC}\n" "$name:" "$display_value"
        done
        echo ""
        
        echo -e "${CYAN}🔗 ACCESS CONTROL${NC}"
        echo "$metrics" | grep "|access|" | while IFS='|' read -r name value percentage category; do
            local display_value="$value"
            printf "%-30s ${WHITE}%s${NC}\n" "$name:" "$display_value"
        done
        echo ""
    fi
    
    # Show recent alerts
    echo -e "${CYAN}🚨 RECENT SECURITY ALERTS${NC}"
    local recent_alerts=$(execute_db "
    SELECT alert_type, severity, COUNT(*) as count, MAX(detection_time) as latest
    FROM security_alerts 
    WHERE detection_time > datetime('now', '-24 hours')
    GROUP BY alert_type, severity
    ORDER BY severity DESC, count DESC;
    ")
    
    if [[ -n "$recent_alerts" ]]; then
        echo "$recent_alerts" | while IFS='|' read -r alert_type severity count latest; do
            local severity_color="$WHITE"
            case "$severity" in
                "critical") severity_color="$RED" ;;
                "high") severity_color="$RED" ;;
                "medium") severity_color="$YELLOW" ;;
                "low") severity_color="$GREEN" ;;
            esac
            printf "${severity_color}%-20s${NC} %-10s ${WHITE}%s${NC} alerts (latest: %s)\n" "$alert_type" "$severity" "$count" "$latest"
        done
    else
        echo -e "${GREEN}No security alerts in the last 24 hours${NC}"
    fi
    echo ""
    
    # Show compliance summary
    echo -e "${CYAN}📊 COMPLIANCE OVERVIEW${NC}"
    local compliance_data=$(execute_db "
    SELECT compliance_status, COUNT(*) as user_count, 
           ROUND(AVG(compliance_score), 1) as avg_score
    FROM security_compliance 
    WHERE status = 'current'
    GROUP BY compliance_status
    ORDER BY compliance_status;
    ")
    
    if [[ -n "$compliance_data" ]]; then
        echo "$compliance_data" | while IFS='|' read -r status count avg_score; do
            local status_color="$WHITE"
            case "$status" in
                "compliant") status_color="$GREEN" ;;
                "warning") status_color="$YELLOW" ;;
                "non_compliant") status_color="$RED" ;;
            esac
            printf "${status_color}%-15s${NC} ${WHITE}%s${NC} users (avg score: %.1f/100)\n" "$status" "$count" "$avg_score"
        done
    else
        echo -e "${GRAY}No compliance data available - run security compliance scan${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GRAY}Last updated: $(date)${NC}"
    echo -e "${GRAY}Use 'r' to refresh or run individual scans from the security menu${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Get security statistics for menu integration
get_security_stats() {
    local alerts_24h=$(execute_db "SELECT COUNT(*) FROM security_alerts WHERE detection_time > datetime('now', '-24 hours');")
    local compliance_rate=$(execute_db "SELECT COALESCE(ROUND(AVG(CASE WHEN compliance_status = 'compliant' THEN 100 ELSE 0 END), 1), 0) FROM security_compliance WHERE status = 'current';")
    local failed_logins=$(execute_db "SELECT COUNT(*) FROM failed_logins WHERE attempt_time > datetime('now', '-24 hours');")
    local admin_actions=$(execute_db "SELECT COUNT(*) FROM admin_activities WHERE activity_time > datetime('now', '-24 hours');")
    local high_risk_oauth=$(execute_db "SELECT COUNT(*) FROM oauth_applications WHERE risk_level IN ('high', 'critical');")
    
    echo "$alerts_24h|$compliance_rate|$failed_logins|$admin_actions|$high_risk_oauth"
}

# Command line interface
case "${1:-status}" in
    "init")
        init_security_db
        ;;
    "scan-logins")
        days="${2:-7}"
        scan_login_activities "$days"
        ;;
    "scan-admin")
        days="${2:-1}"
        scan_admin_activities "$days"
        ;;
    "scan-compliance")
        scan_security_compliance
        ;;
    "scan-oauth")
        scan_oauth_applications
        ;;
    "scan-all")
        echo -e "${CYAN}Running comprehensive security scan...${NC}"
        scan_login_activities "${2:-7}"
        scan_admin_activities "${2:-1}"
        scan_security_compliance
        scan_oauth_applications
        echo -e "${GREEN}✓ Comprehensive security scan completed${NC}"
        ;;
    "dashboard"|"show")
        show_security_dashboard
        ;;
    "report")
        generate_security_report "${2:-summary}" "${3}"
        ;;
    "stats")
        get_security_stats
        ;;
    "check-gam")
        gam_status=$(check_gam_version)
        echo "$gam_status"
        ;;
    *)
        echo "Usage: $0 {init|scan-logins|scan-admin|scan-compliance|scan-oauth|scan-all|dashboard|report|stats|check-gam}"
        echo ""
        echo "Commands:"
        echo "  init                     - Initialize security reports database"
        echo "  scan-logins [days]       - Scan login activities (default: 7 days)"
        echo "  scan-admin [days]        - Scan admin activities (default: 1 day)"
        echo "  scan-compliance          - Scan security compliance (2FA, passwords, etc.)"
        echo "  scan-oauth               - Scan OAuth applications and grants"
        echo "  scan-all [days]          - Run all security scans"
        echo "  dashboard                - Show security dashboard"
        echo "  report [type] [file]     - Generate security report (summary/full/alerts)"
        echo "  stats                    - Get security statistics for dashboard"
        echo "  check-gam                - Check GAM7 availability"
        exit 1
        ;;
esac