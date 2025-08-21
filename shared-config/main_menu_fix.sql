-- Fix Main Menu SQLite Structure
-- Add missing backup section and ensure proper 1-9 numbering

-- Add missing Backup & Recovery section (option 8)
INSERT OR REPLACE INTO menu_sections (id, name, display_name, description, section_order, icon, color_code, is_active) VALUES
(8, 'backup_recovery', 'Backup & Recovery', 'Gmail backup, Drive backup, and system recovery operations', 8, '💾', 'CYAN', 1);

-- Update existing sections to ensure proper ordering
UPDATE menu_sections SET section_order = 1 WHERE id = 1; -- User & Group Management
UPDATE menu_sections SET section_order = 2 WHERE id = 2; -- File & Drive Operations  
UPDATE menu_sections SET section_order = 3 WHERE id = 3; -- Analysis & Discovery
UPDATE menu_sections SET section_order = 4 WHERE id = 4; -- Account List Management
UPDATE menu_sections SET section_order = 5 WHERE id = 5; -- Dashboard & Statistics
UPDATE menu_sections SET section_order = 6 WHERE id = 6; -- Reports & Monitoring
UPDATE menu_sections SET section_order = 7 WHERE id = 7; -- System Administration
UPDATE menu_sections SET section_order = 8 WHERE id = 8; -- Backup & Recovery
UPDATE menu_sections SET section_order = 9 WHERE id = 9; -- SCuBA Compliance Management

-- Ensure SCuBA Compliance section exists and has correct ID
UPDATE menu_sections SET id = 9, section_order = 9 WHERE name = 'scuba_compliance';

-- Verify the main menu structure
SELECT 'Main Menu Sections (1-9):' as info;
SELECT id, section_order, icon, display_name, description 
FROM menu_sections 
WHERE id BETWEEN 1 AND 9 AND is_active = 1 
ORDER BY section_order;

-- Show navigation options
SELECT 'Navigation Options:' as info;
SELECT key_char, icon, display_name 
FROM menu_navigation 
WHERE is_active = 1 
ORDER BY nav_order;