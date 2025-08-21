-- Backup Operations Main Menu SQLite Schema
-- Creates backup_operations_main section with comprehensive backup and recovery operations

-- Create backup_operations_main section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('backup_operations_main', 'Backup & Recovery', 'Gmail backup, Drive backup, and system recovery operations', 22, '💾', 'CYAN', 1);

-- Backup Operations Main Menu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- Remote Storage Configuration (1)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'configure_remote_storage', 'Configure Remote Storage', 'Set up cloud storage backends for backups', 'configure_remote_storage', 1, '☁️', 'configure remote storage cloud backends backups setup'),

-- Backup Policy Management (2-4)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'create_backup_policy', 'Create Backup Policy', 'Define new backup policies and schedules', 'create_backup_policy', 2, '📝', 'create backup policy define schedules new'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'manage_backup_policies', 'Manage Backup Policies', 'View and modify existing backup policies', 'manage_backup_policies', 3, '⚙️', 'manage backup policies view modify existing'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'schedule_backups', 'Schedule Backups', 'Set up automated backup scheduling', 'schedule_backups', 4, '⏰', 'schedule backups automated setup cron'),

-- Backup Analysis & Execution (5-6)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'analyze_backup_needs', 'Analyze Backup Needs', 'Assess what needs to be backed up', 'analyze_backup_needs', 5, '🔍', 'analyze backup needs assess what backed up'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'execute_backup_now', 'Execute Backup Now', 'Run immediate backup operation', 'execute_backup_now', 6, '▶️', 'execute backup now run immediate operation'),

-- Restore Operations (7-8)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'restore_from_backup', 'Restore from Backup', 'Restore data from backup archives', 'restore_from_backup', 7, '📥', 'restore backup archives data recovery'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'selective_restore', 'Selective Restore', 'Restore specific files or accounts', 'selective_restore', 8, '🎯', 'selective restore specific files accounts targeted'),

-- Verification & Integrity (9-10)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'verify_backup_integrity', 'Verify Backup Integrity', 'Check backup completeness and integrity', 'verify_backup_integrity', 9, '✅', 'verify backup integrity check completeness'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'test_restore_process', 'Test Restore Process', 'Test restore procedures without affecting data', 'test_restore_process', 10, '🧪', 'test restore process procedures dry run'),

-- Monitoring & Reports (11-15)
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'backup_status_dashboard', 'Backup Status Dashboard', 'View overall backup system status', 'backup_status_dashboard', 11, '📊', 'backup status dashboard overview system'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'backup_history_report', 'Backup History Report', 'View backup operation history and logs', 'backup_history_report', 12, '📈', 'backup history report operation logs'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'storage_usage_analysis', 'Storage Usage Analysis', 'Analyze backup storage consumption', 'storage_usage_analysis', 13, '💾', 'storage usage analysis consumption backup'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'backup_alerts_config', 'Backup Alerts Configuration', 'Configure backup failure and success alerts', 'backup_alerts_config', 14, '🔔', 'backup alerts configuration failure success notifications'),
((SELECT id FROM menu_sections WHERE name = 'backup_operations_main'), 'export_backup_inventory', 'Export Backup Inventory', 'Export complete backup inventory report', 'export_backup_inventory', 15, '📄', 'export backup inventory report complete');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'backup_operations_main');

-- Verify the data was inserted correctly
SELECT 'Backup Operations Main Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'backup_operations_main') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'Backup Operations Main Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'backup_operations_main';