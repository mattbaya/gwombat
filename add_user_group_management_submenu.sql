-- Create user_group_management section for submenu items
INSERT OR IGNORE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active)
VALUES ('user_group_management', 'User & Group Management', 'Comprehensive user and group administration tools', 1, '👥', 'BLUE', 1);

-- Clear existing items for user_group_management section if any
DELETE FROM menu_items WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'user_group_management');

-- Insert new menu items for user & group management
INSERT INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords)
VALUES
    -- Account Discovery & Scanning
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'rescan_domain_accounts', 'Re-scan All Domain Accounts', 'Sync database with current domain accounts', 'rescan_domain_accounts', 1, '🔄', 'rescan sync domain accounts database'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'list_all_accounts', 'List All Accounts', 'View all accounts with filtering options', 'list_all_accounts_menu', 2, '📊', 'list accounts filter view'),
    
    -- Storage Management
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'calculate_storage_sizes', 'Calculate Account Storage Sizes', 'Calculate and update storage sizes for accounts', 'calculate_account_sizes_menu', 3, '📏', 'calculate storage sizes accounts'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'view_storage_sizes', 'View Account Storage Sizes', 'View storage sizes with filtering and sorting', 'view_account_storage_sizes_menu', 4, '📊', 'view storage sizes filter sort'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'storage_history', 'Storage Size History & Trends', 'View historical storage data and trends', 'storage_size_history_menu', 5, '📈', 'storage history trends historical'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'storage_analytics', 'Storage Change Analytics', 'Analyze storage changes over time', 'storage_change_analytics_menu', 6, '📋', 'storage analytics changes analysis'),
    
    -- Account Tools
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'account_search_diagnostics', 'Account Search and Diagnostics', 'Search and diagnose account issues', 'account_search_diagnostics_menu', 7, '🔍', 'account search diagnostics troubleshoot'),
    
    -- Account Management
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'individual_user_mgmt', 'Individual User Management', 'Manage individual user accounts', 'individual_user_management_menu', 8, '👤', 'individual user management single'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'bulk_user_operations', 'Bulk User Operations', 'Perform bulk operations on multiple users', 'bulk_user_operations_menu', 9, '📋', 'bulk user operations mass multiple'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'account_status_operations', 'Account Status Operations', 'Suspend, restore, and manage account status', 'account_status_operations_menu', 10, '🔐', 'account status suspend restore'),
    
    -- Group & License Management
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'group_operations', 'Group Operations', 'Add/remove members and bulk group operations', 'group_operations_menu', 11, '👥', 'group operations members bulk'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'license_management', 'License Management', 'Assign, remove, and audit user licenses', 'license_management_menu', 12, '📄', 'license management assign remove audit'),
    
    -- Suspended Account Lifecycle
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'scan_suspended_accounts', 'Scan All Suspended Accounts', 'Discover and categorize suspended accounts', 'scan_suspended_accounts', 13, '🔍', 'scan suspended accounts discover categorize'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'auto_create_stage_lists', 'Auto-Create Stage Lists', 'Create stage lists from current accounts', 'auto_create_stage_lists', 14, '📝', 'auto create stage lists accounts'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'manage_recently_suspended', 'Manage Recently Suspended Accounts', 'Manage recently suspended user accounts', 'manage_recently_suspended', 15, '📋', 'manage recently suspended accounts'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'process_pending_deletion', 'Process Accounts for Pending Deletion', 'Process accounts marked for deletion', 'process_pending_deletion', 16, '🔄', 'process pending deletion accounts'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'file_sharing_analysis', 'File Sharing Analysis & Reports', 'Analyze file sharing patterns and generate reports', 'file_sharing_analysis_menu', 17, '📊', 'file sharing analysis reports'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'final_decisions', 'Final Decisions (Hold/Exit)', 'Make final decisions on account status', 'final_decisions', 18, '🎯', 'final decisions hold exit temporary'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'account_deletion', 'Account Deletion Operations', 'Permanently delete user accounts', 'account_deletion', 19, '🗑️', 'account deletion operations permanent'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'quick_status_checker', 'Quick Account Status Checker', 'Quickly check account status', 'quick_status_checker', 20, '🔍', 'quick account status checker'),
    
    -- Reports & Analytics
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'user_statistics', 'User Statistics and Summaries', 'Generate user statistics and summaries', 'user_statistics_menu', 21, '📈', 'user statistics summaries reports'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'lifecycle_reports', 'Account Lifecycle Reports', 'Generate account lifecycle reports', 'account_lifecycle_reports_menu', 22, '📋', 'account lifecycle reports analysis'),
    ((SELECT id FROM menu_sections WHERE name = 'user_group_management'), 'export_account_data', 'Export Account Data to CSV', 'Export account data in CSV format', 'export_account_data_menu', 23, '💾', 'export account data csv download');

-- Update main menu to link to user_group_management section instead of function
-- Note: Main menu is still hardcoded but will be converted later