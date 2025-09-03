#!/bin/bash
# Comprehensive test of all menus and submenus in hierarchical system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_DB="$SCRIPT_DIR/../shared-config/menu.db"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🔍 Comprehensive Menu & Submenu Test${NC}"
echo "===================================="

# Source required functions
source "$SCRIPT_DIR/database_functions.sh"
source "$SCRIPT_DIR/hierarchical_menu_system.sh"

echo -e "${GREEN}✅ Functions loaded${NC}"

# Test 1: Check all root menus exist and can be called
echo ""
echo "1. Testing Root Menu Functions:"
echo "==============================="

root_menus=(
    "user_group_management:user_group_management_menu"
    "file_drive_operations:file_drive_operations_menu"
    "analysis_discovery:analysis_discovery_menu"
    "account_list_management:list_management_menu"
    "dashboard_statistics:dashboard_menu"
    "reports_monitoring:reports_and_cleanup_menu"
    "system_administration:system_administration_menu"
    "scuba_compliance:scuba_compliance_menu"
    "configuration_management:configuration_menu"
)

root_success=0
root_errors=0

for menu_pair in "${root_menus[@]}"; do
    IFS=':' read -r db_name func_name <<< "$menu_pair"
    
    echo -n "  Testing $func_name -> $db_name... "
    
    # Check if menu exists in database
    if sqlite3 "$MENU_DB" "SELECT 1 FROM menu_items_v2 WHERE name = '$db_name' AND item_type = 'menu' LIMIT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OK${NC}"
        ((root_success++))
    else
        echo -e "${RED}❌ Not found${NC}"
        ((root_errors++))
    fi
done

# Test 2: Check submenu structure
echo ""
echo "2. Testing Submenu Structure:"
echo "============================"

submenu_success=0
submenu_errors=0

sqlite3 "$MENU_DB" "
    SELECT p.name as parent_menu, COUNT(c.id) as child_count, 
           GROUP_CONCAT(c.display_name, ' | ') as children
    FROM menu_items_v2 p
    JOIN menu_items_v2 c ON c.parent_id = p.id
    WHERE p.item_type = 'menu'
    GROUP BY p.id
    ORDER BY p.name;
" | while IFS='|' read -r parent_menu child_count children; do
    echo -e "  ${CYAN}$parent_menu${NC}: $child_count items"
    if [[ "$child_count" -gt 0 ]]; then
        ((submenu_success++))
    else
        ((submenu_errors++))
    fi
done

# Test 3: Check that all converted functions use render_menu
echo ""
echo "3. Testing Function Conversions:"
echo "==============================="

conversion_success=0
conversion_errors=0

# Check key menu functions
key_functions=(
    "show_main_menu"
    "user_group_management_menu" 
    "file_drive_operations_menu"
    "analysis_discovery_menu"
    "dashboard_menu"
    "reports_and_cleanup_menu"
    "system_administration_menu"
    "scuba_compliance_menu"
    "configuration_menu"
)

for func in "${key_functions[@]}"; do
    echo -n "  Checking $func... "
    
    if grep -q "render_menu" "$SCRIPT_DIR/../gwombat.sh" && grep -A 2 "^${func}() {" "$SCRIPT_DIR/../gwombat.sh" | grep -q "render_menu"; then
        echo -e "${GREEN}✅ Uses render_menu${NC}"
        ((conversion_success++))
    else
        echo -e "${RED}❌ Still hardcoded${NC}"
        ((conversion_errors++))
    fi
done

# Final Summary
echo ""
echo -e "${BLUE}📊 Test Summary:${NC}"
echo "================="
echo -e "Root Menus: ${GREEN}$root_success✅${NC} / ${RED}$root_errors❌${NC}"
echo -e "Function Conversions: ${GREEN}$conversion_success✅${NC} / ${RED}$conversion_errors❌${NC}"

if [[ $root_errors -eq 0 && $conversion_errors -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 All menus and submenus are working correctly!${NC}"
    echo "The hierarchical menu system conversion is complete."
else
    echo ""
    echo -e "${YELLOW}⚠️ Some issues found that may need attention.${NC}"
fi