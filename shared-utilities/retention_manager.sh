#!/bin/bash

# GWOMBAT Retention Policy Manager
# Handles automated cleanup of historical data based on retention policies

# Source database functions
source "$(dirname "$0")/database_functions.sh" 2>/dev/null || {
    echo "Error: Cannot source database_functions.sh"
    exit 1
}

# Configuration
RETENTION_LOG="${DATABASE_DIR}/logs/retention-$(date +%Y%m%d).log"
RETENTION_ENABLED=$(get_config_value "retention_cleanup_enabled" "true")

# Logging function
log_retention() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$RETENTION_LOG"
}

# Get retention configuration from database
get_retention_config() {
    local config_key="$1"
    local default_value="$2"
    
    sqlite3 "$DATABASE_PATH" "SELECT value FROM config WHERE key = '$config_key';" 2>/dev/null || echo "$default_value"
}

# Apply retention policy to account operations
cleanup_account_operations() {
    log_retention "INFO" "Starting account operations retention cleanup"
    
    local retention_years=$(get_retention_config "account_operations_retention_years" "7")
    local cutoff_date=$(date -d "$retention_years years ago" '+%Y-%m-%d')
    
    # Count records to be deleted
    local records_to_delete=$(sqlite3 "$DATABASE_PATH" "
        SELECT COUNT(*) FROM account_operations 
        WHERE timestamp < '$cutoff_date' OR retention_until < datetime('now');
    " 2>/dev/null || echo "0")
    
    if [[ "$records_to_delete" -gt 0 ]]; then
        log_retention "INFO" "Deleting $records_to_delete account operation records older than $retention_years years"
        
        sqlite3 "$DATABASE_PATH" "
            DELETE FROM account_operations 
            WHERE timestamp < '$cutoff_date' OR retention_until < datetime('now');
        " 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log_retention "SUCCESS" "Successfully deleted $records_to_delete account operation records"
        else
            log_retention "ERROR" "Failed to delete account operation records"
        fi
    else
        log_retention "INFO" "No account operation records to clean up"
    fi
}

# Apply retention policy to storage size history
cleanup_storage_history() {
    log_retention "INFO" "Starting storage history retention cleanup"
    
    # Get retention policy from storage schema
    local retention_policy=$(sqlite3 "$DATABASE_PATH" "
        SELECT value FROM config WHERE key = 'storage_retention_policy';
    " 2>/dev/null || echo "")
    
    if [[ -z "$retention_policy" ]]; then
        # Default retention: Keep detailed data for 2 years, summarized data for 7 years
        local detailed_cutoff=$(date -d "2 years ago" '+%Y-%m-%d')
        local summary_cutoff=$(date -d "7 years ago" '+%Y-%m-%d')
        
        # Count records in each category
        local detailed_to_delete=$(sqlite3 "$DATABASE_PATH" "
            SELECT COUNT(*) FROM storage_size_history 
            WHERE scan_time < '$detailed_cutoff' AND scan_time >= '$summary_cutoff';
        " 2>/dev/null || echo "0")
        
        local old_to_delete=$(sqlite3 "$DATABASE_PATH" "
            SELECT COUNT(*) FROM storage_size_history 
            WHERE scan_time < '$summary_cutoff';
        " 2>/dev/null || echo "0")
        
        # Archive detailed data to summary (keep only monthly snapshots)
        if [[ "$detailed_to_delete" -gt 0 ]]; then
            log_retention "INFO" "Archiving $detailed_to_delete detailed storage records to monthly summaries"
            
            # Create monthly summary table if it doesn't exist
            sqlite3 "$DATABASE_PATH" "
                CREATE TABLE IF NOT EXISTS storage_size_summary (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    email TEXT NOT NULL,
                    year_month TEXT NOT NULL,
                    avg_total_size_gb REAL,
                    max_total_size_gb REAL,
                    min_total_size_gb REAL,
                    sample_count INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(email, year_month)
                );
            "
            
            # Insert monthly summaries
            sqlite3 "$DATABASE_PATH" "
                INSERT OR REPLACE INTO storage_size_summary 
                (email, year_month, avg_total_size_gb, max_total_size_gb, min_total_size_gb, sample_count)
                SELECT 
                    email,
                    strftime('%Y-%m', scan_time) as year_month,
                    AVG(total_size_gb) as avg_total_size_gb,
                    MAX(total_size_gb) as max_total_size_gb,
                    MIN(total_size_gb) as min_total_size_gb,
                    COUNT(*) as sample_count
                FROM storage_size_history 
                WHERE scan_time < '$detailed_cutoff' AND scan_time >= '$summary_cutoff'
                GROUP BY email, strftime('%Y-%m', scan_time);
            "
            
            # Delete the detailed records after archiving
            sqlite3 "$DATABASE_PATH" "
                DELETE FROM storage_size_history 
                WHERE scan_time < '$detailed_cutoff' AND scan_time >= '$summary_cutoff';
            " 2>/dev/null
            
            log_retention "SUCCESS" "Archived $detailed_to_delete storage records to monthly summaries"
        fi
        
        # Delete very old records
        if [[ "$old_to_delete" -gt 0 ]]; then
            log_retention "INFO" "Deleting $old_to_delete storage records older than 7 years"
            
            sqlite3 "$DATABASE_PATH" "
                DELETE FROM storage_size_history 
                WHERE scan_time < '$summary_cutoff';
            " 2>/dev/null
            
            log_retention "SUCCESS" "Deleted $old_to_delete old storage records"
        fi
    else
        log_retention "INFO" "Custom retention policy found: $retention_policy"
        # Handle custom retention policy (could be implemented based on JSON config)
    fi
}

# Apply retention policy to stage history
cleanup_stage_history() {
    log_retention "INFO" "Starting stage history retention cleanup"
    
    local retention_years=$(get_retention_config "stage_history_retention_years" "5")
    local cutoff_date=$(date -d "$retention_years years ago" '+%Y-%m-%d')
    
    local records_to_delete=$(sqlite3 "$DATABASE_PATH" "
        SELECT COUNT(*) FROM stage_history 
        WHERE changed_at < '$cutoff_date';
    " 2>/dev/null || echo "0")
    
    if [[ "$records_to_delete" -gt 0 ]]; then
        log_retention "INFO" "Deleting $records_to_delete stage history records older than $retention_years years"
        
        sqlite3 "$DATABASE_PATH" "
            DELETE FROM stage_history 
            WHERE changed_at < '$cutoff_date';
        " 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log_retention "SUCCESS" "Successfully deleted $records_to_delete stage history records"
        else
            log_retention "ERROR" "Failed to delete stage history records"
        fi
    else
        log_retention "INFO" "No stage history records to clean up"
    fi
}

# Apply retention policy to operation log
cleanup_operation_log() {
    log_retention "INFO" "Starting operation log retention cleanup"
    
    local retention_years=$(get_retention_config "operation_log_retention_years" "3")
    local cutoff_date=$(date -d "$retention_years years ago" '+%Y-%m-%d')
    
    local records_to_delete=$(sqlite3 "$DATABASE_PATH" "
        SELECT COUNT(*) FROM operation_log 
        WHERE created_at < '$cutoff_date';
    " 2>/dev/null || echo "0")
    
    if [[ "$records_to_delete" -gt 0 ]]; then
        log_retention "INFO" "Deleting $records_to_delete operation log records older than $retention_years years"
        
        sqlite3 "$DATABASE_PATH" "
            DELETE FROM operation_log 
            WHERE created_at < '$cutoff_date';
        " 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            log_retention "SUCCESS" "Successfully deleted $records_to_delete operation log records"
        else
            log_retention "ERROR" "Failed to delete operation log records"
        fi
    else
        log_retention "INFO" "No operation log records to clean up"
    fi
}

# Apply retention policy to security historical data
cleanup_security_history() {
    log_retention "INFO" "Starting security history retention cleanup"
    
    # Clean up old login activities marked as historical
    local login_records=$(sqlite3 "$DATABASE_PATH" "
        SELECT COUNT(*) FROM login_activities 
        WHERE status = 'historical' AND scan_time < datetime('now', '-2 years');
    " 2>/dev/null || echo "0")
    
    if [[ "$login_records" -gt 0 ]]; then
        log_retention "INFO" "Deleting $login_records old login activity records"
        
        sqlite3 "$DATABASE_PATH" "
            DELETE FROM login_activities 
            WHERE status = 'historical' AND scan_time < datetime('now', '-2 years');
        " 2>/dev/null
        
        log_retention "SUCCESS" "Deleted $login_records old login activity records"
    fi
    
    # Clean up old compliance data marked as historical
    local compliance_records=$(sqlite3 "$DATABASE_PATH" "
        SELECT COUNT(*) FROM security_compliance 
        WHERE status = 'historical' AND created_at < datetime('now', '-3 years');
    " 2>/dev/null || echo "0")
    
    if [[ "$compliance_records" -gt 0 ]]; then
        log_retention "INFO" "Deleting $compliance_records old compliance records"
        
        sqlite3 "$DATABASE_PATH" "
            DELETE FROM security_compliance 
            WHERE status = 'historical' AND created_at < datetime('now', '-3 years');
        " 2>/dev/null
        
        log_retention "SUCCESS" "Deleted $compliance_records old compliance records"
    fi
}

# Vacuum database after cleanup
vacuum_database() {
    log_retention "INFO" "Starting database vacuum to reclaim space"
    
    local db_size_before=$(du -k "$DATABASE_PATH" | cut -f1)
    
    sqlite3 "$DATABASE_PATH" "VACUUM;" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        local db_size_after=$(du -k "$DATABASE_PATH" | cut -f1)
        local space_saved=$((db_size_before - db_size_after))
        
        log_retention "SUCCESS" "Database vacuum completed. Space saved: ${space_saved}KB"
    else
        log_retention "ERROR" "Database vacuum failed"
    fi
}

# Generate retention report
generate_retention_report() {
    log_retention "INFO" "Generating retention policy report"
    
    local report_file="${DATABASE_DIR}/reports/retention-report-$(date +%Y%m%d).txt"
    
    cat > "$report_file" << EOF
GWOMBAT Retention Policy Report
Generated: $(date)
===============================================

Current Retention Configuration:
- Account Operations: $(get_retention_config "account_operations_retention_years" "7") years
- Stage History: $(get_retention_config "stage_history_retention_years" "5") years  
- Operation Log: $(get_retention_config "operation_log_retention_years" "3") years
- Storage History: Detailed (2 years), Summary (7 years)
- Security Data: Login Activities (2 years), Compliance (3 years)

Current Data Volumes:
EOF

    # Add current record counts
    sqlite3 "$DATABASE_PATH" "
        SELECT 'Account Operations: ' || COUNT(*) || ' records' FROM account_operations
        UNION ALL
        SELECT 'Stage History: ' || COUNT(*) || ' records' FROM stage_history
        UNION ALL  
        SELECT 'Operation Log: ' || COUNT(*) || ' records' FROM operation_log
        UNION ALL
        SELECT 'Storage History: ' || COUNT(*) || ' records' FROM storage_size_history;
    " 2>/dev/null >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Retention Policy Status: $([ "$RETENTION_ENABLED" = "true" ] && echo "ENABLED" || echo "DISABLED")" >> "$report_file"
    echo "Last Cleanup: $(date)" >> "$report_file"
    
    log_retention "SUCCESS" "Retention report generated: $report_file"
}

# Main retention cleanup function
run_retention_cleanup() {
    if [[ "$RETENTION_ENABLED" != "true" ]]; then
        log_retention "INFO" "Retention cleanup is disabled"
        return 0
    fi
    
    log_retention "INFO" "Starting GWOMBAT retention policy cleanup"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$RETENTION_LOG")"
    
    # Run all cleanup functions
    cleanup_account_operations
    cleanup_storage_history
    cleanup_stage_history
    cleanup_operation_log
    cleanup_security_history
    
    # Vacuum database to reclaim space
    vacuum_database
    
    # Generate report
    generate_retention_report
    
    log_retention "INFO" "GWOMBAT retention policy cleanup completed"
}

# Configuration management functions
set_retention_policy() {
    local table="$1"
    local years="$2"
    
    case "$table" in
        "account_operations")
            sqlite3 "$DATABASE_PATH" "
                INSERT OR REPLACE INTO config (key, value) 
                VALUES ('account_operations_retention_years', '$years');
            "
            log_retention "INFO" "Set account operations retention to $years years"
            ;;
        "stage_history")
            sqlite3 "$DATABASE_PATH" "
                INSERT OR REPLACE INTO config (key, value) 
                VALUES ('stage_history_retention_years', '$years');
            "
            log_retention "INFO" "Set stage history retention to $years years"
            ;;
        "operation_log")
            sqlite3 "$DATABASE_PATH" "
                INSERT OR REPLACE INTO config (key, value) 
                VALUES ('operation_log_retention_years', '$years');
            "
            log_retention "INFO" "Set operation log retention to $years years"
            ;;
        *)
            log_retention "ERROR" "Unknown table: $table"
            return 1
            ;;
    esac
}

enable_retention_cleanup() {
    sqlite3 "$DATABASE_PATH" "
        INSERT OR REPLACE INTO config (key, value) 
        VALUES ('retention_cleanup_enabled', 'true');
    "
    log_retention "INFO" "Retention cleanup enabled"
}

disable_retention_cleanup() {
    sqlite3 "$DATABASE_PATH" "
        INSERT OR REPLACE INTO config (key, value) 
        VALUES ('retention_cleanup_enabled', 'false');
    "
    log_retention "INFO" "Retention cleanup disabled"
}

# Command line interface
case "${1:-}" in
    "run")
        run_retention_cleanup
        ;;
    "report")
        generate_retention_report
        ;;
    "enable")
        enable_retention_cleanup
        ;;
    "disable")
        disable_retention_cleanup
        ;;
    "set")
        if [[ $# -eq 3 ]]; then
            set_retention_policy "$2" "$3"
        else
            echo "Usage: $0 set <table> <years>"
            echo "Tables: account_operations, stage_history, operation_log"
        fi
        ;;
    *)
        echo "GWOMBAT Retention Policy Manager"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  run                     - Run retention cleanup"
        echo "  report                  - Generate retention report"
        echo "  enable                  - Enable automatic retention cleanup"
        echo "  disable                 - Disable automatic retention cleanup"
        echo "  set <table> <years>     - Set retention policy for table"
        echo ""
        echo "Examples:"
        echo "  $0 run"
        echo "  $0 set account_operations 5"
        echo "  $0 report"
        ;;
esac