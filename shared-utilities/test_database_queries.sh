#!/bin/bash
# Test database queries for various menu sections

echo "=== DATABASE QUERY TESTING ==="

# Test menu database structure
echo ""
echo "Testing menu database structure..."
if [[ -f "shared-config/menu.db" ]]; then
    echo "✓ Menu database exists"
    
    # Test table existence
    tables=$(sqlite3 shared-config/menu.db ".tables" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "✓ Database accessible"
        echo "Tables: $tables"
    else
        echo "❌ Database access error: $tables"
    fi
else
    echo "❌ Menu database missing"
    exit 1
fi

# Test menu sections
echo ""
echo "Testing menu sections..."
sections=$(sqlite3 shared-config/menu.db "SELECT name, display_name FROM menu_sections ORDER BY section_order;" 2>&1)
if [[ $? -eq 0 ]]; then
    echo "✓ Menu sections query successful"
    echo "$sections" | while IFS='|' read -r name display_name; do
        [[ -n "$name" ]] && echo "  - $name: $display_name"
    done
else
    echo "❌ Menu sections query failed: $sections"
fi

# Test menu items for each section
echo ""
echo "Testing menu items per section..."
while IFS='|' read -r section_name; do
    [[ -n "$section_name" ]] || continue
    count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items WHERE section_id = (SELECT id FROM menu_sections WHERE name = '$section_name');" 2>&1)
    if [[ "$count" =~ ^[0-9]+$ ]]; then
        if [[ $count -gt 0 ]]; then
            echo "✓ Section $section_name: $count items"
        else
            echo "⚠️  Section $section_name: 0 items (empty section)"
        fi
    else
        echo "❌ Section $section_name query error: $count"
    fi
done < <(sqlite3 shared-config/menu.db "SELECT name FROM menu_sections;")

echo ""
echo "=== DATABASE TESTING COMPLETED ==="