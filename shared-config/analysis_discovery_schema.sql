-- Analysis & Discovery Menu SQLite Schema
-- Creates analysis_discovery section with comprehensive analysis and diagnostic tools

-- Create analysis_discovery section
INSERT OR REPLACE INTO menu_sections (name, display_name, description, section_order, icon, color_code, is_active) VALUES
('analysis_discovery', 'Analysis & Discovery', 'Comprehensive analysis tools and data discovery operations', 23, '🔍', 'CYAN', 1);

-- Analysis & Discovery Menu Items
INSERT OR REPLACE INTO menu_items (section_id, name, display_name, description, function_name, item_order, icon, keywords) VALUES
-- Analysis Tools (1-3)
((SELECT id FROM menu_sections WHERE name = 'analysis_discovery'), 'account_analysis', 'Account Analysis', 'Comprehensive account analysis and diagnostic tools', 'account_analysis_menu', 1, '🔍', 'account analysis diagnostic tools comprehensive'),
((SELECT id FROM menu_sections WHERE name = 'analysis_discovery'), 'file_discovery', 'File Discovery', 'Discover and analyze files across the domain', 'file_discovery_menu', 2, '📄', 'file discovery analyze domain search'),
((SELECT id FROM menu_sections WHERE name = 'analysis_discovery'), 'system_diagnostics', 'System Diagnostics', 'System diagnostics and troubleshooting tools', 'system_diagnostics_menu', 3, '🔧', 'system diagnostics troubleshooting tools repair'),

-- Legacy Tools (4)
((SELECT id FROM menu_sections WHERE name = 'analysis_discovery'), 'legacy_discovery', 'Legacy Discovery Mode', 'Legacy discovery tools and deprecated functions', 'discovery_mode', 4, '🗂️', 'legacy discovery mode deprecated tools old');

-- Mark all items as active
UPDATE menu_items SET is_active = 1 WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'analysis_discovery');

-- Verify the data was inserted correctly
SELECT 'Analysis & Discovery Menu Items:' as info;
SELECT item_order, icon, display_name, description 
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'analysis_discovery') 
  AND is_active = 1 
ORDER BY item_order;

SELECT 'Analysis & Discovery Section:' as info;
SELECT name, display_name, description, icon 
FROM menu_sections 
WHERE name = 'analysis_discovery';