-- Shared Drive Management Menu SQLite Schema
-- Creates shared_drives section with comprehensive shared drive operations

-- Create shared_drives section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('shared_drives', 'Shared Drive Management', 'Shared drive operations and team collaboration management', 21, '🗂️', 'BLUE', 1);

-- Shared Drive Management Menu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- Drive Operations (1-4)
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'list_shared_drives', 'List Shared Drives', 'View all shared drives in the domain', 'list_shared_drives', 1, '📋', 'list shared drives view domain all'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'create_shared_drive', 'Create Shared Drive', 'Create new shared drive with initial settings', 'create_shared_drive', 2, '➕', 'create shared drive new settings'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'modify_shared_drive', 'Modify Shared Drive', 'Change shared drive settings and configuration', 'modify_shared_drive', 3, '✏️', 'modify shared drive settings configuration change'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'delete_shared_drive', 'Delete Shared Drive', 'Remove shared drive after confirmation', 'delete_shared_drive', 4, '🗑️', 'delete shared drive remove confirmation'),

-- Member Management (5-8)
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'list_drive_members', 'List Drive Members', 'View members and permissions for specific drive', 'list_drive_members', 5, '👥', 'list drive members view permissions specific'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'add_drive_members', 'Add Drive Members', 'Add users or groups to shared drive', 'add_drive_members', 6, '👤', 'add drive members users groups shared'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'remove_drive_members', 'Remove Drive Members', 'Remove users or groups from shared drive', 'remove_drive_members', 7, '👤', 'remove drive members users groups shared'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'change_member_roles', 'Change Member Roles', 'Modify user roles and permissions in drive', 'change_member_roles', 8, '🔄', 'change member roles permissions modify user drive'),

-- Drive Administration (9-12)
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'set_drive_restrictions', 'Set Drive Restrictions', 'Configure sharing and access restrictions', 'set_drive_restrictions', 9, '🔒', 'set drive restrictions sharing access configure'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'backup_drive_settings', 'Backup Drive Settings', 'Export drive configuration and member list', 'backup_drive_settings', 10, '💾', 'backup drive settings export configuration member list'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'restore_drive_settings', 'Restore Drive Settings', 'Import and apply drive configuration', 'restore_drive_settings', 11, '📥', 'restore drive settings import apply configuration'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'audit_drive_access', 'Audit Drive Access', 'Review drive access patterns and permissions', 'audit_drive_access', 12, '🔍', 'audit drive access patterns permissions review'),

-- Bulk Operations (13-15)
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'bulk_member_changes', 'Bulk Member Changes', 'Apply member changes across multiple drives', 'bulk_member_changes', 13, '📦', 'bulk member changes multiple drives apply'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'mass_drive_creation', 'Mass Drive Creation', 'Create multiple drives from template or CSV', 'mass_drive_creation', 14, '🏭', 'mass drive creation multiple template csv'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'bulk_permission_sync', 'Bulk Permission Sync', 'Synchronize permissions across drives', 'bulk_permission_sync', 15, '🔄', 'bulk permission sync synchronize drives'),

-- Reports & Analytics (16-20)
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'drive_usage_report', 'Drive Usage Report', 'Generate storage and activity usage reports', 'drive_usage_report', 16, '📊', 'drive usage report storage activity generate'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'member_access_report', 'Member Access Report', 'Report on member access patterns across drives', 'member_access_report', 17, '📈', 'member access report patterns drives'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'drive_security_scan', 'Drive Security Scan', 'Scan for security issues and external sharing', 'drive_security_scan', 18, '🛡️', 'drive security scan issues external sharing'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'compliance_audit', 'Compliance Audit', 'Check drives against organizational policies', 'compliance_audit', 19, '📋', 'compliance audit drives organizational policies check'),
((SELECT id FROM menu_sections WHERE name = 'shared_drives'), 'export_drive_inventory', 'Export Drive Inventory', 'Export complete drive inventory to CSV', 'export_drive_inventory', 20, '📄', 'export drive inventory complete csv');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'shared_drives');

-- Verify the data was inserted correctly
SELECT 'Shared Drive Management Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'shared_drives') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'Shared Drive Management Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'shared_drives';