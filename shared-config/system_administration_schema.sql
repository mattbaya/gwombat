-- System Administration Menu SQLite Schema
-- Creates system_administration section with system configuration and maintenance tools

-- Create system_administration section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('system_administration', 'System Administration', 'System configuration, maintenance, and administrative tools', 24, '⚙️', 'GREEN', 1);

-- System Administration Menu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- Configuration & Setup (1-2)
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'configuration_management', 'Configuration Management', 'System configuration and settings management', 'configuration_menu', 1, '⚙️', 'configuration management settings system setup'),
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'dry_run_preview', 'Dry-run & Preview Modes', 'Test operations without making changes', 'dry_run_mode', 2, '🔍', 'dry run preview test operations safe'),

-- Maintenance & Health (3-4)
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'system_health', 'System Health & Maintenance', 'Check incomplete operations and system health', 'check_incomplete_operations', 3, '🛠️', 'system health maintenance check operations status'),
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'backup_management', 'Backup Management', 'View and manage system backup files', 'view_backup_files', 4, '💾', 'backup management files view system'),

-- Auditing & Dependencies (5-6)
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'file_ownership_audit', 'File Ownership Audit', 'Audit file ownership and permissions', 'audit_file_ownership_menu', 5, '📋', 'file ownership audit permissions check'),
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'system_dependencies', 'Check System Dependencies', 'Verify system dependencies and requirements', 'check_system_dependencies', 6, '🔧', 'system dependencies check requirements verify'),

-- Data Management (7)
((SELECT id FROM menu_sections WHERE name = 'system_administration'), 'retention_management', 'Data Retention Management', 'Manage data retention policies and cleanup', 'retention_management_menu', 7, '🗂️', 'data retention management policies cleanup');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_administration');

-- Verify the data was inserted correctly
SELECT 'System Administration Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_administration') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'System Administration Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'system_administration';