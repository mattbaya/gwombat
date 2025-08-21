-- Statistics Submenu SQLite Schema
-- Converts statistics_menu() to fully database-driven implementation
-- This creates the statistics submenu section under dashboard_statistics

-- Create statistics submenu section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('statistics_submenu', 'Statistics & Metrics', 'Comprehensive statistics and performance metrics', 10, '📊', 'CYAN', 1);

-- Statistics Submenu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- Core Statistics (1-5)
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'domain_overview', 'Domain Overview Statistics', 'Comprehensive domain metrics and account distribution', 'domain_overview_statistics', 1, '📊', 'domain overview statistics metrics accounts distribution'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'user_account', 'User Account Statistics', 'Active, suspended, lifecycle stages analytics', 'user_account_statistics', 2, '👥', 'user account statistics active suspended lifecycle stages'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'historical_trends', 'Historical Trends', 'Account changes and patterns over time', 'historical_trends_statistics', 3, '📈', 'historical trends patterns changes time analytics'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'storage_analytics', 'Storage Analytics', 'Storage usage patterns and growth trends', 'storage_analytics_statistics', 4, '💾', 'storage analytics usage patterns growth trends'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'group_statistics', 'Group Statistics', 'Groups, memberships, and distribution analysis', 'group_statistics_analysis', 5, '📋', 'group statistics memberships distribution analysis'),

-- Performance Metrics (6-8)
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'system_performance', 'System Performance', 'Response times and operation speeds analysis', 'system_performance_metrics', 6, '⚡', 'system performance response times operation speeds metrics'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'database_performance', 'Database Performance', 'Query performance and database growth rates', 'database_performance_metrics', 7, '📊', 'database performance query growth rates metrics'),
((SELECT id FROM menu_sections WHERE name = 'statistics_submenu'), 'gam_operations', 'GAM Operation Metrics', 'Command success rates and timing analysis', 'gam_operation_metrics', 8, '🔧', 'gam operations metrics command success rates timing');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'statistics_submenu');

-- Verify the data was inserted correctly
SELECT 'Statistics Submenu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'statistics_submenu') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'Statistics Submenu Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'statistics_submenu';