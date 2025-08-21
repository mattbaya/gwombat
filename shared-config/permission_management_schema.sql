-- Permission Management Menu SQLite Schema
-- Creates permission_management section with comprehensive file and folder permission operations

-- Create permission_management section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('permission_management', 'Permission Management', 'File and folder permission management and security operations', 20, '🔐', 'RED', 1);

-- Permission Management Menu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- File Permissions (1-5)
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'check_file_permissions', 'Check File Permissions', 'View detailed permissions for specific files', 'check_file_permissions', 1, '🔍', 'check file permissions view details'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'modify_file_permissions', 'Modify File Permissions', 'Change permissions for individual files', 'modify_file_permissions', 2, '✏️', 'modify file permissions change individual'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'grant_file_access', 'Grant File Access', 'Grant access to users or groups for files', 'grant_file_access', 3, '➕', 'grant file access users groups'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'revoke_file_access', 'Revoke File Access', 'Remove access from users or groups for files', 'revoke_file_access', 4, '➖', 'revoke file access remove users groups'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'transfer_file_ownership', 'Transfer File Ownership', 'Change file ownership to different users', 'transfer_file_ownership', 5, '🔄', 'transfer file ownership change owner'),

-- Folder Permissions (6-9)
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'check_folder_permissions', 'Check Folder Permissions', 'View detailed permissions for folders and subfolders', 'check_folder_permissions', 6, '📁', 'check folder permissions view details subfolders'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'modify_folder_permissions', 'Modify Folder Permissions', 'Change permissions for folders recursively', 'modify_folder_permissions', 7, '📝', 'modify folder permissions change recursive'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'grant_folder_access', 'Grant Folder Access', 'Grant access to users or groups for folders', 'grant_folder_access', 8, '🎁', 'grant folder access users groups'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'revoke_folder_access', 'Revoke Folder Access', 'Remove access from users or groups for folders', 'revoke_folder_access', 9, '🚫', 'revoke folder access remove users groups'),

-- Drive Permissions (10-13)
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'check_drive_permissions', 'Check Drive Permissions', 'View permissions for shared drives', 'check_drive_permissions', 10, '🗂️', 'check drive permissions shared view'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'modify_drive_permissions', 'Modify Drive Permissions', 'Change shared drive permissions and roles', 'modify_drive_permissions', 11, '⚙️', 'modify drive permissions shared roles'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'grant_drive_access', 'Grant Drive Access', 'Add users or groups to shared drives', 'grant_drive_access', 12, '🔓', 'grant drive access shared users groups add'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'revoke_drive_access', 'Revoke Drive Access', 'Remove users or groups from shared drives', 'revoke_drive_access', 13, '🔒', 'revoke drive access shared users groups remove'),

-- Security Operations (14-17)
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'audit_permissions', 'Audit Permissions', 'Comprehensive permission audit and reporting', 'audit_permissions', 14, '🔍', 'audit permissions comprehensive reporting security'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'detect_public_files', 'Detect Public Files', 'Find files with public or external sharing', 'detect_public_files', 15, '🌐', 'detect public files external sharing security'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'security_scan', 'Security Scan', 'Scan for permission vulnerabilities and risks', 'security_scan', 16, '🛡️', 'security scan vulnerabilities risks permission'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'compliance_check', 'Compliance Check', 'Check permissions against security policies', 'compliance_check', 17, '📋', 'compliance check permissions security policies'),

-- Batch Operations (18-20)
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'batch_permission_changes', 'Batch Permission Changes', 'Apply permission changes to multiple files/folders', 'batch_permission_changes', 18, '📦', 'batch permission changes multiple files folders'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'bulk_ownership_transfer', 'Bulk Ownership Transfer', 'Transfer ownership for multiple items at once', 'bulk_ownership_transfer', 19, '🔄', 'bulk ownership transfer multiple items'),
((SELECT id FROM menu_sections WHERE name = 'permission_management'), 'export_permissions_report', 'Export Permissions Report', 'Export detailed permissions report to CSV', 'export_permissions_report', 20, '📊', 'export permissions report csv detailed');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'permission_management');

-- Verify the data was inserted correctly
SELECT 'Permission Management Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'permission_management') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'Permission Management Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'permission_management';