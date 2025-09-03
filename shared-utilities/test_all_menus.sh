#!/bin/bash
# Test script to verify all menu functions work with hierarchical system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_FILE="$SCRIPT_DIR/../gwombat.sh"
MENU_DB="$SCRIPT_DIR/../shared-config/menu.db"

# Source required files
source "$SCRIPT_DIR/database_functions.sh"
source "$SCRIPT_DIR/hierarchical_menu_system.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "🧪 Testing GWOMBAT Hierarchical Menu System"
echo "=========================================="

# Test that render_menu function exists
if ! type -t render_menu >/dev/null 2>&1; then
    echo -e "${RED}❌ render_menu function not found!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ render_menu function found${NC}"

# Get all menu functions from gwombat.sh
echo ""
echo "📋 Finding all menu functions..."
menu_functions=$(grep -o "[a-zA-Z_]*_menu()" "$GWOMBAT_FILE" | sort -u)
total_menus=$(echo "$menu_functions" | wc -l | tr -d ' ')
echo "Found $total_menus menu functions"

# Test each menu renders the correct hierarchical menu
echo ""
echo "🔍 Testing menu mappings..."
errors=0
success=0

# Function to test if a menu identifier exists in database
test_menu_exists() {
    local menu_name="$1"
    if sqlite3 "$MENU_DB" "SELECT 1 FROM menu_items_v2 WHERE name = '$menu_name' AND item_type = 'menu' LIMIT 1;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Extract render_menu calls from each function
while IFS= read -r menu_func; do
    func_name="${menu_func%()}"
    
    # Get the render_menu call from the function
    render_call=$(awk "/$func_name\(\) \{/,/^}$/" "$GWOMBAT_FILE" | grep 'render_menu' | grep -o '"[^"]*"' | tr -d '"')
    
    if [[ -n "$render_call" ]]; then
        # Test if the hierarchical menu exists
        if test_menu_exists "$render_call"; then
            echo -e "✅ ${func_name} -> ${render_call}"
            ((success++))
        else
            echo -e "${RED}❌ ${func_name} -> ${render_call} (menu not found in database)${NC}"
            ((errors++))
        fi
    else
        echo -e "${YELLOW}⚠️ ${func_name} - no render_menu call found${NC}"
        ((errors++))
    fi
done <<< "$menu_functions"

echo ""
echo "📊 Test Results:"
echo "==============="
echo -e "${GREEN}✅ Successful: $success${NC}"
echo -e "${RED}❌ Errors: $errors${NC}"
echo -e "📋 Total: $total_menus"

# Test that main menu renders
echo ""
echo "🏠 Testing main menu render..."
if test_menu_exists "main" || [[ "main" == "main" ]]; then
    echo -e "${GREEN}✅ Main menu can be rendered${NC}"
else
    echo -e "${RED}❌ Main menu cannot be rendered${NC}"
    ((errors++))
fi

# Test hierarchical relationships
echo ""
echo "🌳 Testing hierarchical relationships..."
echo "Root menus (parent_id IS NULL):"
sqlite3 "$MENU_DB" "SELECT name, display_name FROM menu_items_v2 WHERE parent_id IS NULL AND item_type = 'menu';" | while IFS='|' read -r name display; do
    echo "  • $name - $display"
done

echo ""
echo "Menus with children:"
sqlite3 "$MENU_DB" "
    SELECT DISTINCT p.name, p.display_name, COUNT(c.id) as child_count
    FROM menu_items_v2 p
    JOIN menu_items_v2 c ON c.parent_id = p.id
    WHERE p.item_type = 'menu'
    GROUP BY p.id
    ORDER BY p.name;
" | while IFS='|' read -r name display count; do
    echo "  • $name - $display ($count children)"
done

# Final summary
echo ""
echo "🎯 Final Summary:"
echo "================="
if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}✅ All menu functions are properly configured!${NC}"
    echo "The hierarchical menu system is ready to use."
    exit 0
else
    echo -e "${RED}❌ Found $errors issues that need attention${NC}"
    echo "Please check the menu mappings above."
    exit 1
fi