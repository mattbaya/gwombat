#!/bin/bash
# Test script to check menu functionality

# Source the necessary functions
source shared-utilities/database_functions.sh

echo "Testing menu database connection..."
if [[ -f "shared-config/menu.db" ]]; then
    echo "✓ Menu database exists"
    count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items;")
    echo "✓ Menu items count: $count"
else
    echo "❌ Menu database missing"
    exit 1
fi

echo ""
echo "Testing generate_main_menu function..."
generate_main_menu
echo ""
echo "✓ Menu generation completed"