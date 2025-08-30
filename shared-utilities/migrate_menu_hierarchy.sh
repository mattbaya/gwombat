#!/bin/bash
# GWOMBAT Menu System Migration Script
# Migrates from flat menu structure to hierarchical parent-child system

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Database paths
OLD_DB="$PARENT_DIR/shared-config/menu.db"
NEW_DB="$PARENT_DIR/shared-config/menu_hierarchical.db"
BACKUP_DB="$PARENT_DIR/shared-config/menu_backup_$(date +%Y%m%d_%H%M%S).db"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== GWOMBAT Menu System Migration ===${NC}"
echo ""

# Check if old database exists
if [[ ! -f "$OLD_DB" ]]; then
    echo -e "${RED}Error: Original menu database not found at $OLD_DB${NC}"
    exit 1
fi

# Create backup
echo -e "${YELLOW}Creating backup of existing menu database...${NC}"
cp "$OLD_DB" "$BACKUP_DB"
echo -e "${GREEN}✓ Backup created: $BACKUP_DB${NC}"

# Create new database with hierarchical schema
echo -e "${YELLOW}Creating new hierarchical database...${NC}"
sqlite3 "$NEW_DB" < "$PARENT_DIR/shared-config/hierarchical_menu_schema.sql"
echo -e "${GREEN}✓ New database structure created${NC}"

# Migrate data
echo -e "${YELLOW}Migrating menu data to hierarchical structure...${NC}"

sqlite3 "$NEW_DB" <<EOF
ATTACH DATABASE '$OLD_DB' AS old_db;

-- First, insert root level items (main menu sections)
INSERT INTO menu_items_v2 (
    parent_id, name, display_name, description, icon, color_code, 
    item_type, function_name, sort_order, is_visible, is_active, keywords
)
SELECT 
    NULL as parent_id,  -- Root level
    name,
    display_name,
    description,
    icon,
    color_code,
    'menu' as item_type,  -- These are all menu containers
    name || '_menu' as function_name,  -- Convention: section_name + _menu
    section_order as sort_order,
    is_active as is_visible,
    is_active,
    '' as keywords
FROM old_db.menu_sections
WHERE name NOT IN ('system_overview', 'statistics_submenu', 'account_analysis_submenu')  -- These are submenus
ORDER BY section_order;

-- Get the IDs of the parent menus we just created
-- Insert dashboard & statistics submenu items
INSERT INTO menu_items_v2 (
    parent_id, name, display_name, description, icon, color_code,
    item_type, function_name, sort_order, is_visible, is_active, keywords
)
SELECT 
    (SELECT id FROM menu_items_v2 WHERE name = 'dashboard_statistics') as parent_id,
    'system_overview',
    'System Overview',
    'System monitoring and health checks',
    '📊',
    'GREEN',
    'menu',
    'system_overview_menu',
    1,
    1,
    1,
    'system health monitoring dashboard'
FROM old_db.menu_sections WHERE name = 'system_overview'
UNION ALL
SELECT 
    (SELECT id FROM menu_items_v2 WHERE name = 'dashboard_statistics') as parent_id,
    'statistics_metrics',
    'Statistics & Metrics', 
    'Comprehensive statistics and performance metrics',
    '📈',
    'BLUE',
    'menu',
    'statistics_menu',
    2,
    1,
    1,
    'statistics metrics performance data'
FROM old_db.menu_sections WHERE name = 'statistics_submenu';

-- Insert analysis & discovery submenu
INSERT INTO menu_items_v2 (
    parent_id, name, display_name, description, icon, color_code,
    item_type, function_name, sort_order, is_visible, is_active, keywords
)
SELECT 
    (SELECT id FROM menu_items_v2 WHERE name = 'analysis_discovery') as parent_id,
    'account_analysis',
    'Account Analysis Tools',
    'Comprehensive account analysis and diagnostics',
    '🔍',
    'PURPLE',
    'menu',
    'account_analysis_menu',
    1,
    1,
    1,
    'account analysis diagnostics tools'
FROM old_db.menu_sections WHERE name = 'account_analysis_submenu';

-- Now insert all menu items as actions under their parent menus
INSERT INTO menu_items_v2 (
    parent_id, name, display_name, description, icon, color_code,
    item_type, function_name, sort_order, is_visible, is_active, keywords
)
SELECT 
    p.id as parent_id,
    'action_' || mi.id as name,  -- Ensure unique names by prefixing with action_
    mi.display_name,
    mi.description,
    mi.icon,
    ms.color_code,
    'action' as item_type,
    mi.function_name,
    mi.item_order as sort_order,
    mi.is_active as is_visible,
    mi.is_active,
    COALESCE(mi.keywords, '') as keywords
FROM old_db.menu_items mi
JOIN old_db.menu_sections ms ON mi.section_id = ms.id
JOIN menu_items_v2 p ON p.name = ms.name
ORDER BY mi.section_id, mi.item_order;

-- Migrate navigation shortcuts
INSERT INTO menu_shortcuts (
    key_char, display_name, description, icon, function_name, is_global, is_active, sort_order
)
SELECT 
    key_char,
    display_name,
    description,
    icon,
    function_name,
    is_global,
    is_active,
    nav_order as sort_order
FROM old_db.menu_navigation
WHERE is_active = 1;

-- Add standard navigation shortcuts if not present
INSERT OR IGNORE INTO menu_shortcuts (key_char, display_name, icon, function_name, is_global, sort_order) VALUES
    ('b', 'Back/Previous Menu', '⬅️', 'menu_back', 1, 1),
    ('m', 'Main Menu', '🏠', 'menu_main', 1, 2),
    ('s', 'Search', '🔍', 'menu_search', 1, 3),
    ('i', 'Index', '📋', 'menu_index', 1, 4),
    ('?', 'Help', '❓', 'menu_help', 1, 5),
    ('x', 'Exit', '❌', 'menu_exit', 1, 99);

-- Show migration summary
SELECT 'Migration Summary:' as '';
SELECT '=================' as '';
SELECT 'Total root menus: ' || COUNT(*) FROM menu_items_v2 WHERE parent_id IS NULL;
SELECT 'Total submenus: ' || COUNT(*) FROM menu_items_v2 WHERE item_type = 'menu' AND parent_id IS NOT NULL;
SELECT 'Total actions: ' || COUNT(*) FROM menu_items_v2 WHERE item_type = 'action';
SELECT 'Total shortcuts: ' || COUNT(*) FROM menu_shortcuts;

DETACH DATABASE old_db;
EOF

echo -e "${GREEN}✓ Data migration completed${NC}"

# Verify the migration
echo ""
echo -e "${YELLOW}Verifying migration...${NC}"

# Show menu tree
echo -e "${BLUE}Menu Hierarchy:${NC}"
sqlite3 "$NEW_DB" <<'EOF'
.mode column
.headers on
SELECT 
    CASE 
        WHEN depth = 0 THEN display_name 
        WHEN depth = 1 THEN '  → ' || display_name
        WHEN depth = 2 THEN '    • ' || display_name
        ELSE '      - ' || display_name
    END as "Menu Structure",
    item_type as "Type",
    CASE WHEN function_name IS NOT NULL THEN function_name ELSE '' END as "Function"
FROM v_menu_hierarchy
WHERE is_active = 1
ORDER BY 
    CASE WHEN parent_id IS NULL THEN id ELSE parent_id END,
    sort_order,
    display_name
LIMIT 30;
EOF

echo ""
echo -e "${GREEN}✅ Migration completed successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the new menu structure above"
echo "2. Test the new hierarchical menu system"
echo "3. If everything works, replace the old database:"
echo "   mv $NEW_DB $OLD_DB"
echo ""
echo -e "${BLUE}Backup location: $BACKUP_DB${NC}"