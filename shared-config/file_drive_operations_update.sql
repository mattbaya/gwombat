-- Update File & Drive Operations Menu to match current implementation
-- Remove non-functional items and add CSV Data Export

-- Update existing items to match current menu
UPDATE menu_items SET 
    display_name = 'File Operations',
    description = 'File management, search, and organization tools',
    function_name = 'file_operations_menu',
    icon = '📁',
    keywords = 'file operations management search organization tools'
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') AND item_order = 1;

UPDATE menu_items SET 
    display_name = 'Shared Drive Management',
    description = 'Shared drive operations and team collaboration',
    function_name = 'shared_drive_menu',
    icon = '🗂️',
    keywords = 'shared drive management team collaboration'
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') AND item_order = 2;

UPDATE menu_items SET 
    display_name = 'Backup Operations',
    description = 'File backup, restore, and recovery operations',
    function_name = 'backup_operations_menu',
    icon = '💾',
    keywords = 'backup operations restore recovery file'
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') AND item_order = 3;

UPDATE menu_items SET 
    display_name = 'Permission Management',
    description = 'File and folder permission management',
    function_name = 'permission_management_menu',
    icon = '🔐',
    keywords = 'permission management file folder access control'
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') AND item_order = 4;

-- Replace item 5 with CSV Data Export (remove Drive Cleanup Operations)
UPDATE menu_items SET 
    display_name = 'CSV Data Export',
    description = 'Export user data, shared drives, and account lists to CSV',
    function_name = 'export_data_menu',
    icon = '📊',
    keywords = 'csv data export user shared drives account lists'
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') AND item_order = 5;

-- Verify the updated menu items
SELECT 'Updated File & Drive Operations Menu:' as info;
SELECT item_order, icon, display_name, description, function_name
FROM menu_items 
WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'file_drive_operations') 
  AND is_active = 1 
ORDER BY item_order;