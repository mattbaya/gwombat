#!/bin/bash
# Test dashboard functionality

# Load required functions
source shared-utilities/database_functions.sh
source local-config/.env 2>/dev/null || echo "Warning: No .env file"

echo "Testing dashboard menu function..."

# Test if dashboard_menu function exists
if declare -f dashboard_menu >/dev/null 2>&1; then
    echo "✓ dashboard_menu function exists"
else
    echo "❌ dashboard_menu function not found"
    exit 1
fi

# Test database connectivity for dashboard
echo "Testing dashboard database connectivity..."
if [[ -f "shared-config/menu.db" ]]; then
    count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'dashboard_menu');" 2>&1)
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "✓ Dashboard menu items found: $count"
    else
        echo "❌ Database error: $count"
    fi
else
    echo "❌ Menu database not found"
fi

echo "✓ Dashboard testing completed"