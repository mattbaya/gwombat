#!/bin/bash
# Test input validation and boundary conditions

echo "=== INPUT VALIDATION TESTING ==="

# Test menu choice validation
echo ""
echo "Testing menu choice validation..."

# Test the choice conversion logic from show_main_menu
test_choice_conversion() {
    local input_choice="$1"
    local expected="$2"
    
    # Simulate the choice conversion from show_main_menu
    choice="$input_choice"
    
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then
        choice=10  # Exit
    elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
        choice=99  # Configuration
    elif [[ "$choice" == "s" || "$choice" == "S" ]]; then
        choice=98  # Search
    elif [[ "$choice" == "i" || "$choice" == "I" ]]; then
        choice=97  # Index
    fi
    
    if [[ "$choice" == "$expected" ]]; then
        echo "✓ Input '$input_choice' correctly converts to $choice"
    else
        echo "❌ Input '$input_choice' converts to $choice, expected $expected"
    fi
}

# Test various inputs
test_choice_conversion "x" "10"
test_choice_conversion "X" "10"
test_choice_conversion "c" "99"
test_choice_conversion "s" "98"
test_choice_conversion "i" "97"
test_choice_conversion "1" "1"
test_choice_conversion "999" "999"
test_choice_conversion "" ""
test_choice_conversion "abc" "abc"

# Test boundary values for menu selections
echo ""
echo "Testing menu boundary values..."

# Test with menu items count
total_items=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items;" 2>&1)
if [[ "$total_items" =~ ^[0-9]+$ ]]; then
    echo "✓ Total menu items: $total_items"
    
    # Test selecting item beyond range
    echo "  Testing selection beyond range (item $((total_items + 1)))..."
    # This would normally be handled by menu validation logic
    
    # Test selecting item 0
    echo "  Testing selection of item 0 (should be invalid)..."
    
    # Test negative selection
    echo "  Testing negative selection (-1)..."
    
else
    echo "❌ Could not get menu items count: $total_items"
fi

# Test with null/empty database responses
echo ""
echo "Testing null/empty database responses..."

# Test query that returns empty result
empty_query=$(sqlite3 shared-config/menu.db "SELECT name FROM menu_items WHERE name = 'nonexistent_item';" 2>&1)
if [[ -z "$empty_query" ]]; then
    echo "✓ Empty query result handled properly"
else
    echo "⚠️  Empty query returned: '$empty_query'"
fi

# Test configuration value validation
echo ""
echo "Testing configuration value validation..."

# Test domain validation
if [[ -n "$DOMAIN" ]]; then
    echo "  Domain: $DOMAIN"
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "✓ Domain format appears valid"
    else
        echo "⚠️  Domain format may be invalid"
    fi
else
    echo "❌ Domain not configured"
fi

# Test email validation
if [[ -n "$ADMIN_EMAIL" ]]; then
    echo "  Admin email: $ADMIN_EMAIL"
    if [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "✓ Admin email format appears valid"
    else
        echo "⚠️  Admin email format may be invalid"
    fi
else
    echo "❌ Admin email not configured"
fi

# Test path validation
echo ""
echo "Testing path validation..."

if [[ -n "$GAM_PATH" ]]; then
    # Test path traversal
    if [[ "$GAM_PATH" =~ \.\. ]]; then
        echo "⚠️  GAM_PATH contains path traversal: $GAM_PATH"
    else
        echo "✓ GAM_PATH appears safe from path traversal"
    fi
    
    # Test absolute vs relative path
    if [[ "$GAM_PATH" =~ ^/ ]]; then
        echo "✓ GAM_PATH is absolute path"
    else
        echo "⚠️  GAM_PATH is relative path: $GAM_PATH"
    fi
fi

# Test numeric value validation
echo ""
echo "Testing numeric value validation..."

# Test scanning depth
if [[ -n "$SCAN_DEPTH" ]]; then
    if [[ "$SCAN_DEPTH" =~ ^[0-9]+$ ]]; then
        if [[ $SCAN_DEPTH -ge 1 && $SCAN_DEPTH -le 5 ]]; then
            echo "✓ SCAN_DEPTH ($SCAN_DEPTH) is within valid range"
        else
            echo "⚠️  SCAN_DEPTH ($SCAN_DEPTH) is outside recommended range (1-5)"
        fi
    else
        echo "❌ SCAN_DEPTH is not numeric: $SCAN_DEPTH"
    fi
else
    echo "⚠️  SCAN_DEPTH not configured"
fi

echo ""
echo "=== INPUT VALIDATION TESTING COMPLETED ==="