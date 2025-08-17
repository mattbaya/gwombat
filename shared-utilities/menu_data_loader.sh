#!/bin/bash

# Menu Data Loader for GWOMBAT
# Populates menu database with current menu structure

# Source the database functions
source "$(dirname "$0")/database_functions.sh"

DB_PATH="local-config/account_lifecycle.db"
MENU_DB_PATH="local-config/menu.db"

# Initialize standalone menu database schema
initialize_menu_database() {
    echo "Initializing standalone menu database schema..."
    
    # Apply menu schema to standalone database
    if [[ -f "local-config/menu_schema.sql" ]]; then
        sqlite3 "$MENU_DB_PATH" < "local-config/menu_schema.sql"
        echo "✓ Menu schema applied to $MENU_DB_PATH"
    else
        echo "❌ Menu schema file not found"
        return 1
    fi
}

# Clear existing menu data
clear_menu_data() {
    echo "Clearing existing menu data..."
    sqlite3 "$MENU_DB_PATH" "
        DELETE FROM menu_hierarchy;
        DELETE FROM menu_items;
        DELETE FROM menu_sections;
        DELETE FROM menu_navigation;
        DELETE FROM menu_search_cache;
    "
    echo "✓ Menu data cleared"
}

# Populate menu sections
populate_menu_sections() {
    echo "Populating menu sections..."
    
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_sections (name, display_name, description, section_order, icon, color_code) VALUES
        ('user_group_management', 'User & Group Management', 'User management, groups, suspended account lifecycle', 1, '👥', 'GREEN'),
        ('file_drive_operations', 'File & Drive Operations', 'File management, shared drives, backups', 2, '💾', 'BLUE'),
        ('analysis_discovery', 'Analysis & Discovery', 'Account analysis, file discovery, diagnostics', 3, '🔍', 'BLUE'),
        ('account_list_management', 'Account List Management', 'Account lists, CSV operations, database management', 4, '📋', 'BLUE'),
        ('dashboard_statistics', 'Dashboard & Statistics', 'System overview, statistics, monitoring', 5, '🎯', 'PURPLE'),
        ('reports_monitoring', 'Reports & Monitoring', 'Activity reports, logs, performance monitoring', 6, '📈', 'PURPLE'),
        ('system_administration', 'System Administration', 'System configuration, maintenance, backups', 7, '⚙️', 'PURPLE'),
        ('scuba_compliance', 'SCuBA Compliance Management', 'CISA security baselines, compliance monitoring', 8, '🔐', 'RED'),
        ('configuration_management', 'Configuration Management', 'System setup, domain configuration, external tools', 99, '⚙️', 'CYAN');
    "
    
    echo "✓ Menu sections populated"
}

# Populate menu navigation options
populate_menu_navigation() {
    echo "Populating menu navigation options..."
    
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_navigation (key_char, display_name, description, function_name, icon, nav_order) VALUES
        ('c', 'Configuration Management', 'Setup & Settings', 'configuration_management_menu', '⚙️', 1),
        ('s', 'Search Menu Options', 'Search for menu options by keyword', 'search_menu_options', '🔍', 2),
        ('i', 'Menu Index (Alphabetical)', 'Alphabetical listing of all options', 'show_menu_index', '📋', 3),
        ('m', 'Main menu', 'Return to main menu', 'return_to_main', '🏠', 4),
        ('p', 'Previous menu', 'Return to previous menu', 'return_previous', '⬅️', 5),
        ('x', 'Exit', 'Exit GWOMBAT', 'exit_program', '❌', 6);
    "
    
    echo "✓ Menu navigation populated"
}

# Populate User & Group Management menu items
populate_user_group_items() {
    echo "Populating User & Group Management items..."
    
    local section_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'user_group_management';")
    
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($section_id, 'rescan_accounts', 'Re-scan all domain accounts', 'Sync database with current domain state', 'rescan_all_accounts', 1, '🔄', 'scan resync sync domain accounts database'),
        ($section_id, 'list_accounts', 'List all accounts', 'Display accounts with filtering options', 'list_all_accounts_menu', 2, '📊', 'list accounts filter display show'),
        ($section_id, 'calculate_sizes', 'Calculate account storage sizes', 'Analyze storage usage per account', 'calculate_account_sizes_menu', 3, '📏', 'storage size calculate analyze usage quota'),
        ($section_id, 'account_search', 'Account search and diagnostics', 'Find and diagnose specific accounts', 'account_search_diagnostics_menu', 4, '🔍', 'search find diagnose troubleshoot account'),
        ($section_id, 'individual_user', 'Individual user management', 'Manage single user accounts', 'individual_user_management_menu', 5, '👤', 'user individual single manage person'),
        ($section_id, 'bulk_operations', 'Bulk user operations', 'Batch operations on multiple users', 'bulk_user_operations_menu', 6, '📋', 'bulk batch multiple operations mass'),
        ($section_id, 'account_status', 'Account status operations', 'Suspend, restore, and status changes', 'account_status_operations_menu', 7, '🔐', 'suspend restore status enable disable'),
        ($section_id, 'group_operations', 'Group operations', 'Add/remove members, bulk group operations', 'group_operations_menu', 8, '👥', 'group members add remove bulk teams'),
        ($section_id, 'license_management', 'License management', 'Assign, remove, and audit licenses', 'license_management_menu', 9, '📄', 'license assign remove audit subscription'),
        ($section_id, 'scan_suspended', 'Scan All Suspended Accounts', 'Discover and categorize suspended accounts', 'scan_suspended_accounts_direct', 10, '🔍', 'scan suspended discover categorize lifecycle'),
        ($section_id, 'auto_create_lists', 'Auto-Create Stage Lists', 'Create lists from current account stages', 'auto_create_stage_lists_direct', 11, '📝', 'auto create lists stages lifecycle workflow'),
        ($section_id, 'recently_suspended', 'Manage Recently Suspended Accounts', 'Handle newly suspended accounts', 'stage1_recently_suspended_menu', 12, '📋', 'recently suspended new stage1 lifecycle'),
        ($section_id, 'pending_deletion', 'Process Accounts for Pending Deletion', 'Move accounts to deletion pending', 'stage2_pending_deletion_menu', 13, '🔄', 'pending deletion process stage2 lifecycle'),
        ($section_id, 'sharing_analysis', 'File Sharing Analysis & Reports', 'Analyze file sharing before deletion', 'stage3_sharing_analysis_menu', 14, '📊', 'sharing analysis files reports stage3 lifecycle'),
        ($section_id, 'final_decisions', 'Final Decisions', 'Temporary hold or exit row decisions', 'stage4_final_decisions_menu', 15, '🎯', 'final decisions temporary hold exit stage4 lifecycle'),
        ($section_id, 'account_deletion', 'Account Deletion Operations', 'Execute final account deletions', 'stage5_deletion_menu', 16, '🗑️', 'deletion delete remove final stage5 lifecycle'),
        ($section_id, 'status_checker', 'Quick Account Status Checker', 'Check individual account status quickly', 'quick_account_status_checker', 17, '🔍', 'quick status check account verify lifecycle'),
        ($section_id, 'user_statistics', 'User statistics and summaries', 'Generate user statistics reports', 'user_statistics_menu', 18, '📈', 'statistics stats summary reports analytics'),
        ($section_id, 'lifecycle_reports', 'Account lifecycle reports', 'Reports on account lifecycle stages', 'account_lifecycle_reports_menu', 19, '📋', 'lifecycle reports stages workflow audit'),
        ($section_id, 'export_data', 'Export account data to CSV', 'Export account information to files', 'export_account_data_menu', 20, '💾', 'export csv data accounts backup save');
    "
    
    echo "✓ User & Group Management items populated"
}

# Populate File & Drive Operations menu items  
populate_file_drive_items() {
    echo "Populating File & Drive Operations items..."
    
    local section_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'file_drive_operations';")
    
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($section_id, 'file_operations', 'File Operations', 'File management and operations', 'file_operations_menu', 1, '📁', 'file operations manage copy move'),
        ($section_id, 'shared_drives', 'Shared Drive Management', 'Manage shared drives and permissions', 'shared_drive_menu', 2, '🗂️', 'shared drives permissions manage team'),
        ($section_id, 'backup_operations', 'Backup Operations', 'Backup and restore operations', 'backup_operations_menu', 3, '💾', 'backup restore save archive'),
        ($section_id, 'drive_cleanup', 'Drive Cleanup Operations', 'Clean up and organize drives', 'drive_cleanup_menu', 4, '🧹', 'cleanup organize clean drives space'),
        ($section_id, 'permission_mgmt', 'Permission Management', 'Manage file and drive permissions', 'permission_management_menu', 5, '🔐', 'permissions access rights security share');
    "
    
    echo "✓ File & Drive Operations items populated"
}

# Populate remaining sections with placeholder items
populate_remaining_sections() {
    echo "Populating remaining menu sections..."
    
    # Analysis & Discovery
    local analysis_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'analysis_discovery';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($analysis_id, 'account_analysis', 'Account Analysis', 'Comprehensive account analysis tools', 'account_analysis_menu', 1, '🔍', 'analysis analyze accounts discover search'),
        ($analysis_id, 'file_discovery', 'File Discovery', 'Discover and analyze files', 'file_discovery_menu', 2, '📄', 'files discover find search analyze'),
        ($analysis_id, 'diagnostics', 'System Diagnostics', 'System health and diagnostics', 'system_diagnostics_menu', 3, '🔧', 'diagnostics health check system troubleshoot');
    "
    
    # Account List Management
    local list_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'account_list_management';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($list_id, 'manage_lists', 'Manage Account Lists', 'Create and manage account lists', 'account_list_management_menu', 1, '📋', 'lists manage create accounts groups'),
        ($list_id, 'csv_operations', 'CSV Import/Export', 'Import and export CSV data', 'csv_operations_menu', 2, '📊', 'csv import export data spreadsheet'),
        ($list_id, 'database_ops', 'Database Operations', 'Database maintenance and operations', 'database_operations_menu', 3, '🗃️', 'database maintenance operations sqlite');
    "
    
    # Dashboard & Statistics  
    local dashboard_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'dashboard_statistics';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($dashboard_id, 'overview', 'System Overview', 'System status and overview', 'system_overview_menu', 1, '🎯', 'overview dashboard status system summary'),
        ($dashboard_id, 'statistics', 'Statistics & Metrics', 'System statistics and metrics', 'statistics_menu', 2, '📊', 'statistics metrics stats analytics data'),
        ($dashboard_id, 'monitoring', 'Real-time Monitoring', 'Monitor system performance', 'monitoring_menu', 3, '📈', 'monitoring realtime performance watch');
    "
    
    # Reports & Monitoring
    local reports_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'reports_monitoring';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($reports_id, 'activity_reports', 'Activity Reports', 'Generate activity reports', 'activity_reports_menu', 1, '📈', 'activity reports generate audit trail'),
        ($reports_id, 'log_management', 'Log Management', 'View and manage system logs', 'log_management_menu', 2, '📝', 'logs management view audit trail'),
        ($reports_id, 'performance', 'Performance Reports', 'System performance analysis', 'performance_reports_menu', 3, '⚡', 'performance analysis speed optimization');
    "
    
    # System Administration
    local admin_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'system_administration';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($admin_id, 'system_config', 'System Configuration', 'Configure system settings', 'system_configuration_menu', 1, '⚙️', 'configuration settings system admin setup'),
        ($admin_id, 'maintenance', 'System Maintenance', 'System maintenance operations', 'system_maintenance_menu', 2, '🔧', 'maintenance repair fix system cleanup'),
        ($admin_id, 'backup_system', 'System Backup', 'Backup system configuration', 'system_backup_menu', 3, '💾', 'backup system configuration save archive');
    "
    
    # SCuBA Compliance
    local scuba_id=$(sqlite3 "$MENU_DB_PATH" "SELECT id FROM menu_sections WHERE name = 'scuba_compliance';")
    sqlite3 "$MENU_DB_PATH" "
        INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
        ($scuba_id, 'baseline_check', 'Baseline Compliance Check', 'Check CISA baseline compliance', 'scuba_baseline_menu', 1, '🔐', 'baseline compliance cisa security check'),
        ($scuba_id, 'policy_management', 'Policy Management', 'Manage security policies', 'policy_management_menu', 2, '📋', 'policy security manage rules compliance'),
        ($scuba_id, 'audit_reports', 'Security Audit Reports', 'Generate security audit reports', 'security_audit_menu', 3, '📊', 'audit security reports compliance cisa');
    "
    
    echo "✓ Remaining sections populated"
}

# Main execution
main() {
    echo "=== GWOMBAT Menu Database Loader ==="
    echo ""
    
    # Create standalone menu database (no dependency on main database)
    echo "Creating standalone menu database at $MENU_DB_PATH..."
    
    initialize_menu_database
    clear_menu_data
    populate_menu_sections
    populate_menu_navigation
    populate_user_group_items
    populate_file_drive_items
    populate_remaining_sections
    
    echo ""
    echo "✓ Menu database population complete!"
    echo ""
    
    # Show summary
    echo "Summary:"
    sqlite3 "$MENU_DB_PATH" "
        SELECT 'Sections: ' || COUNT(*) FROM menu_sections WHERE is_active = 1;
    "
    sqlite3 "$MENU_DB_PATH" "
        SELECT 'Menu Items: ' || COUNT(*) FROM menu_items WHERE is_active = 1;
    "
    sqlite3 "$MENU_DB_PATH" "
        SELECT 'Navigation Options: ' || COUNT(*) FROM menu_navigation WHERE is_active = 1;
    "
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi