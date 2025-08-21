-- System Overview Menu SQLite Schema
-- Converts hardcoded system_overview_menu to database-driven implementation
-- This should be run against shared-config/menu.db (application-level menu structure)

-- Create system_overview section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('system_overview', 'System Overview', 'Real-time system monitoring and diagnostics', 3, '🎯', 'GREEN', 1);

-- System Overview Options Section
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- System Overview Options (1-5)
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_dashboard', 'System Dashboard', 'Real-time overview with key metrics', 'system_dashboard_view', 1, '🎯', 'dashboard metrics overview real-time status'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_health_check', 'System Health Check', 'Comprehensive system diagnostics', 'system_health_diagnostics', 2, '📊', 'health check diagnostics system status'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'performance_metrics', 'Performance Metrics', 'System performance and response times', 'performance_metrics_view', 3, '📈', 'performance metrics response times speed'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_status_report', 'System Status Report', 'Detailed status of all components', 'system_status_report_generate', 4, '🔍', 'status report components detailed analysis'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'database_overview', 'Database Overview', 'Database status and statistics', 'database_overview_view', 5, '🗄️', 'database sqlite status statistics overview'),

-- Maintenance & Tools Section (6-10)
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_cleanup', 'System Cleanup', 'Clear logs, temp files, old data', 'system_cleanup_operations', 6, '🧹', 'cleanup logs temp files maintenance clear'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'refresh_all_data', 'Refresh All Data', 'Force refresh of all cached data', 'refresh_all_cached_data', 7, '🔄', 'refresh cache data reload update sync'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'quick_health_scan', 'Quick Health Scan', 'Fast system check', 'quick_health_scan_run', 8, '🎯', 'quick health scan fast check diagnostics'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'generate_system_report', 'Generate System Report', 'Comprehensive system report', 'generate_comprehensive_system_report', 9, '📊', 'generate report comprehensive system status'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_maintenance_menu', 'System Maintenance Menu', 'Advanced maintenance options', 'system_maintenance_submenu', 10, '⚙️', 'maintenance advanced options tools system'),

-- Information & Help Section (11-15)
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_information', 'System Information', 'Version, configuration, environment', 'system_information_display', 11, 'ℹ️', 'information version configuration environment details'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'component_status', 'Component Status', 'Status of all GWOMBAT components', 'component_status_check', 12, '📚', 'components status modules tools availability'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'troubleshooting_guide', 'Troubleshooting Guide', 'Common issues and solutions', 'troubleshooting_guide_display', 13, '🏥', 'troubleshooting guide help issues solutions problems'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'system_logs', 'System Logs', 'View recent system activity', 'system_logs_viewer', 14, '📋', 'logs activity recent history events operations'),
((SELECT id FROM menu_sections WHERE name = 'system_overview'), 'environment_check', 'Environment Check', 'Check system requirements', 'environment_requirements_check', 15, '🔍', 'environment requirements check dependencies system setup');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_overview');

-- Verify the data was inserted correctly
SELECT 'System Overview Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_overview') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'System Overview Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'system_overview';