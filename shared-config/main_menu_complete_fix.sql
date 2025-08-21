-- Complete Main Menu Fix - Proper 1-9 mapping for main loop

-- Update Configuration Management to be navigation-only (not main section)
UPDATE menu_sections SET id = 99, section_order = 99 WHERE name = 'configuration_management';

-- Add SCuBA Compliance as section 9
INSERT OR REPLACE INTO menu_sections (id, name, display_name, description, section_order, icon, color_code, is_active) VALUES
(9, 'scuba_compliance', 'SCuBA Compliance Management', 'CISA security baseline monitoring and compliance reporting', 9, '🔐', 'RED', 1);

-- Verify final structure
SELECT 'Final Main Menu Structure (1-9):' as info;
SELECT id, section_order, icon, display_name, name 
FROM menu_sections 
WHERE id BETWEEN 1 AND 9 AND is_active = 1 
ORDER BY id;