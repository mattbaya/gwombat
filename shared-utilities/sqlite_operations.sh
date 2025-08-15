#!/bin/bash

# SQLite Operations Utility Script
# Provides common operations for managing the database

# Load configuration from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi

DB_PATH="${DB_PATH:-./config/gwombat.db}"
GAM="${GAM_PATH:-gam}"

# Helper function to execute database queries
execute_db() {
    sqlite3 "$DB_PATH" "$1"
}

# Function to display usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                     - Initialize database with migration tables"
    echo "  restore-users            - Restore all users that need restoration"
    echo "  restore-session <id>     - Restore users from specific session"
    echo "  list-pending             - List all pending user restorations"
    echo "  list-operations          - List recent file operations"
    echo "  list-analyses            - List recent file analyses"
    echo "  cleanup-old              - Clean up old temporary files and records"
    echo "  export-csv <analysis_id> - Export analysis to CSV files"
    echo "  stats                    - Show database statistics"
    echo ""
}

# Initialize database with migration tables
init_database() {
    echo "Initializing database with migration tables..."
    if [[ -f "../csv_to_sqlite_migration.sql" ]]; then
        sqlite3 "$DB_PATH" < ../csv_to_sqlite_migration.sql
        echo "Database migration completed."
    else
        echo "Error: csv_to_sqlite_migration.sql not found"
        exit 1
    fi
}

# Restore all users that need restoration
restore_all_users() {
    echo "Finding users that need restoration..."
    
    PENDING_COUNT=$(execute_db "SELECT COUNT(*) FROM temp_user_states WHERE restore_needed = 1;")
    
    if [[ "$PENDING_COUNT" -eq 0 ]]; then
        echo "No users need restoration."
        return 0
    fi
    
    echo "Found $PENDING_COUNT users that need restoration."
    echo ""
    
    # Display users to be restored
    echo "Users to be restored to suspended state:"
    execute_db "
    SELECT '  - ' || user_email || ' (unsuspended at ' || changed_at || ')' 
    FROM temp_user_states 
    WHERE restore_needed = 1 
    ORDER BY changed_at;
    "
    
    echo ""
    read -p "Proceed with restoration? (y/N): " confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Generate and execute GAM commands
        echo "Restoring users..."
        execute_db "
        SELECT 'gam update user ' || user_email || ' suspended on'
        FROM temp_user_states 
        WHERE restore_needed = 1;
        " | while read -r gam_command; do
            echo "Executing: $gam_command"
            eval "$gam_command"
        done
        
        # Mark users as restored
        execute_db "
        UPDATE temp_user_states 
        SET restore_needed = 0, restored_at = CURRENT_TIMESTAMP 
        WHERE restore_needed = 1;
        "
        
        echo "Restoration completed."
    else
        echo "Restoration cancelled."
    fi
}

# Restore users from specific session
restore_session_users() {
    local session_id="$1"
    
    if [[ -z "$session_id" ]]; then
        echo "Error: Session ID required"
        echo "Usage: $0 restore-session <session_id>"
        return 1
    fi
    
    echo "Finding users from session $session_id that need restoration..."
    
    PENDING_COUNT=$(execute_db "SELECT COUNT(*) FROM temp_user_states WHERE session_id = '$session_id' AND restore_needed = 1;")
    
    if [[ "$PENDING_COUNT" -eq 0 ]]; then
        echo "No users from session $session_id need restoration."
        return 0
    fi
    
    echo "Found $PENDING_COUNT users from session $session_id that need restoration."
    
    # Display and restore users
    execute_db "
    SELECT 'gam update user ' || user_email || ' suspended on'
    FROM temp_user_states 
    WHERE session_id = '$session_id' AND restore_needed = 1;
    " | while read -r gam_command; do
        echo "Executing: $gam_command"
        eval "$gam_command"
    done
    
    # Mark users as restored
    execute_db "
    UPDATE temp_user_states 
    SET restore_needed = 0, restored_at = CURRENT_TIMESTAMP 
    WHERE session_id = '$session_id' AND restore_needed = 1;
    "
    
    echo "Session $session_id restoration completed."
}

# List pending user restorations
list_pending() {
    echo "Pending user restorations:"
    echo ""
    
    execute_db "
    SELECT 
        user_email,
        original_state || ' -> ' || temporary_state as state_change,
        changed_at,
        session_id
    FROM temp_user_states 
    WHERE restore_needed = 1 
    ORDER BY changed_at DESC;
    " | while IFS='|' read -r email state_change changed_at session_id; do
        echo "  $email ($state_change) - $changed_at - Session: $session_id"
    done
    
    TOTAL=$(execute_db "SELECT COUNT(*) FROM temp_user_states WHERE restore_needed = 1;")
    echo ""
    echo "Total pending restorations: $TOTAL"
}

# List recent file operations
list_operations() {
    echo "Recent file operations:"
    echo ""
    
    execute_db "
    .headers on
    .mode column
    SELECT 
        id,
        operation_type,
        substr(target_id, 1, 20) || '...' as target,
        operation_status,
        created_at,
        substr(session_id, 1, 15) || '...' as session
    FROM file_operations 
    ORDER BY created_at DESC 
    LIMIT 20;
    "
}

# List recent file analyses
list_analyses() {
    echo "Recent file analyses:"
    echo ""
    
    execute_db "
    .headers on
    .mode column
    SELECT 
        id,
        user_email,
        analysis_type,
        cutoff_days,
        total_files,
        recent_files,
        old_files,
        report_generated_at
    FROM file_analysis_reports 
    ORDER BY report_generated_at DESC 
    LIMIT 20;
    "
}

# Clean up old records
cleanup_old() {
    echo "Cleaning up old records..."
    
    # Clean up completed operations older than 30 days
    DELETED_OPS=$(execute_db "
    DELETE FROM file_operations 
    WHERE operation_status = 'completed' 
    AND created_at < datetime('now', '-30 days');
    SELECT changes();
    ")
    
    # Clean up restored user states older than 7 days
    DELETED_STATES=$(execute_db "
    DELETE FROM temp_user_states 
    WHERE restore_needed = 0 
    AND restored_at < datetime('now', '-7 days');
    SELECT changes();
    ")
    
    # Clean up old file analysis reports (keep last 100 per user)
    execute_db "
    DELETE FROM file_analysis_reports 
    WHERE id NOT IN (
        SELECT id FROM (
            SELECT id, ROW_NUMBER() OVER (PARTITION BY user_email ORDER BY report_generated_at DESC) as rn
            FROM file_analysis_reports
        ) WHERE rn <= 100
    );
    "
    
    # Vacuum database
    execute_db "VACUUM;"
    
    echo "Cleanup completed:"
    echo "  - Removed $DELETED_OPS old file operations"
    echo "  - Removed $DELETED_STATES old user state records"
    echo "  - Vacuumed database"
}

# Export analysis to CSV
export_csv() {
    local analysis_id="$1"
    
    if [[ -z "$analysis_id" ]]; then
        echo "Error: Analysis ID required"
        echo "Usage: $0 export-csv <analysis_id>"
        return 1
    fi
    
    # Get analysis info
    ANALYSIS_INFO=$(execute_db "
    SELECT user_email, analysis_type, cutoff_days, report_generated_at 
    FROM file_analysis_reports 
    WHERE id = $analysis_id;
    ")
    
    if [[ -z "$ANALYSIS_INFO" ]]; then
        echo "Error: Analysis ID $analysis_id not found"
        return 1
    fi
    
    IFS='|' read -r user_email analysis_type cutoff_days report_date <<< "$ANALYSIS_INFO"
    
    echo "Exporting analysis $analysis_id for $user_email..."
    
    TEMP_DIR="${SCRIPT_TEMP_PATH:-./tmp}"
    mkdir -p "$TEMP_DIR"
    
    # Export files
    execute_db "
    .headers on
    .mode csv
    .output '$TEMP_DIR/${user_email}_analysis_${analysis_id}.csv'
    SELECT 
        file_id,
        file_name,
        file_size,
        mime_type,
        modified_time,
        file_category
    FROM file_records 
    WHERE analysis_id = $analysis_id
    ORDER BY file_category, modified_time DESC;
    .output stdout
    "
    
    echo "Exported to: $TEMP_DIR/${user_email}_analysis_${analysis_id}.csv"
}

# Show database statistics
show_stats() {
    echo "Database Statistics:"
    echo ""
    
    execute_db "
    SELECT 
        'Total Accounts: ' || COUNT(*) 
    FROM accounts
    UNION ALL
    SELECT 
        'Active Account Lists: ' || COUNT(*) 
    FROM account_lists WHERE is_active = 1
    UNION ALL
    SELECT 
        'File Operations: ' || COUNT(*) 
    FROM file_operations
    UNION ALL
    SELECT 
        'Pending Restorations: ' || COUNT(*) 
    FROM temp_user_states WHERE restore_needed = 1
    UNION ALL
    SELECT 
        'File Analysis Reports: ' || COUNT(*) 
    FROM file_analysis_reports
    UNION ALL
    SELECT 
        'File Records: ' || COUNT(*) 
    FROM file_records;
    "
    
    echo ""
    echo "Recent Activity:"
    
    execute_db "
    SELECT 
        'Operations Today: ' || COUNT(*) 
    FROM file_operations 
    WHERE date(created_at) = date('now')
    UNION ALL
    SELECT 
        'Analyses Today: ' || COUNT(*) 
    FROM file_analysis_reports 
    WHERE date(report_generated_at) = date('now');
    "
}

# Main command processing
case "$1" in
    "init")
        init_database
        ;;
    "restore-users")
        restore_all_users
        ;;
    "restore-session")
        restore_session_users "$2"
        ;;
    "list-pending")
        list_pending
        ;;
    "list-operations")
        list_operations
        ;;
    "list-analyses")
        list_analyses
        ;;
    "cleanup-old")
        cleanup_old
        ;;
    "export-csv")
        export_csv "$2"
        ;;
    "stats")
        show_stats
        ;;
    *)
        show_usage
        exit 1
        ;;
esac