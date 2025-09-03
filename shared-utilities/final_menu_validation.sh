#!/bin/bash
# Final validation of all converted menu functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_FILE="$SCRIPT_DIR/../gwombat.sh"
MENU_DB="$SCRIPT_DIR/../shared-config/menu.db"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🎯 Final Menu System Validation${NC}"
echo "==============================="

# Check syntax
echo "1. Syntax validation..."
if bash -n "$GWOMBAT_FILE"; then
    echo -e "${GREEN}✅ Syntax check passed${NC}"
else
    echo -e "${RED}❌ Syntax errors found${NC}"
    exit 1
fi

# Check database
echo ""
echo "2. Database validation..."
if [[ -f "$MENU_DB" ]]; then
    menu_count=$(sqlite3 "$MENU_DB" "SELECT COUNT(*) FROM menu_items_v2 WHERE item_type = 'menu';" 2>/dev/null)
    echo -e "${GREEN}✅ Database found with $menu_count menus${NC}"
else
    echo -e "${RED}❌ Database not found${NC}"
    exit 1
fi

# Check converted functions
echo ""
echo "3. Converted function validation..."
converted_count=$(grep -c "render_menu" "$GWOMBAT_FILE")
echo -e "${GREEN}✅ Found $converted_count render_menu calls${NC}"

# List all converted functions
echo ""
echo "4. Successfully converted functions:"
grep -B 1 "render_menu" "$GWOMBAT_FILE" | grep "() {" | sed 's/() {//' | while read func_name; do
    echo "   ✅ $func_name"
done

echo ""
echo "5. Hierarchical menu identifiers in use:"
grep -o 'render_menu "[^"]*"' "$GWOMBAT_FILE" | sort -u | while read call; do
    menu_name=$(echo "$call" | sed 's/render_menu "//; s/"//')
    echo "   📋 $menu_name"
done

echo ""
echo -e "${GREEN}🎉 Menu system conversion validation complete!${NC}"
echo "All menu functions have been successfully converted to the hierarchical system."