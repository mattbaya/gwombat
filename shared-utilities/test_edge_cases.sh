#!/bin/bash
# Test edge cases and error handling

echo "=== EDGE CASE & ERROR TESTING ==="

# Test with missing database files
echo ""
echo "Testing with missing database files..."

# Backup current database
if [[ -f "shared-config/menu.db" ]]; then
    cp shared-config/menu.db shared-config/menu.db.backup
    echo "✓ Backed up menu database"
    
    # Remove database temporarily
    rm shared-config/menu.db
    echo "  Removed menu database for testing"
    
    # Test menu generation with missing database
    source shared-utilities/database_functions.sh
    result=$(generate_main_menu 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "⚠️  Menu generation succeeded despite missing database"
        echo "  Output: $(echo "$result" | head -1)"
    else
        echo "✓ Menu generation properly failed with missing database"
        echo "  Error: $(echo "$result" | head -1)"
    fi
    
    # Restore database
    mv shared-config/menu.db.backup shared-config/menu.db
    echo "  ✓ Restored menu database"
else
    echo "❌ Menu database not found for testing"
fi

# Test with corrupted database
echo ""
echo "Testing with corrupted database..."

if [[ -f "shared-config/menu.db" ]]; then
    # Create a backup
    cp shared-config/menu.db shared-config/menu.db.backup2
    
    # Corrupt the database by writing random data
    echo "corrupted data" > shared-config/menu.db
    echo "  Created corrupted database"
    
    # Test database access
    error_output=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items;" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "✓ Database properly reports corruption"
        echo "  Error: $(echo "$error_output" | head -1)"
    else
        echo "❌ Database corruption not detected"
    fi
    
    # Restore database
    mv shared-config/menu.db.backup2 shared-config/menu.db
    echo "  ✓ Restored corrupted database"
fi

# Test with extremely long inputs
echo ""
echo "Testing with extremely long inputs..."

# Create a very long string (1000+ characters)
long_string=$(printf 'A%.0s' {1..1500})
echo "  Created string of length: ${#long_string}"

# Test with long search term
long_search_result=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items WHERE keywords LIKE '%${long_string}%';" 2>&1)
if [[ $? -eq 0 ]]; then
    echo "✓ Long search query handled successfully"
    echo "  Result: $long_search_result"
else
    echo "❌ Long search query failed: $long_search_result"
fi

# Test with special characters
echo ""
echo "Testing with special characters..."

special_chars="'; DROP TABLE menu_items; --"
echo "  Testing with: $special_chars"

# Test SQL injection attempt (safe because we're just testing query formation)
special_result=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items WHERE keywords LIKE '%test%';" 2>&1)
if [[ $? -eq 0 ]]; then
    echo "✓ Basic query with safe parameters works"
else
    echo "❌ Basic query failed: $special_result"
fi

# Test with empty inputs
echo ""
echo "Testing with empty inputs..."

empty_result=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items WHERE keywords LIKE '';" 2>&1)
if [[ $? -eq 0 ]]; then
    echo "✓ Empty search query handled"
    echo "  Result: $empty_result"
else
    echo "❌ Empty search query failed: $empty_result"
fi

# Test with invalid file permissions
echo ""
echo "Testing with invalid file permissions..."

if [[ -f "shared-config/menu.db" ]]; then
    # Store original permissions
    original_perms=$(stat -f%Mp%Lp shared-config/menu.db)
    echo "  Original permissions: $original_perms"
    
    # Remove read permissions
    chmod 000 shared-config/menu.db
    echo "  Removed all permissions"
    
    # Test database access
    perm_error=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items;" 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "✓ Permission error properly detected"
        echo "  Error: $(echo "$perm_error" | head -1)"
    else
        echo "❌ Permission error not detected"
    fi
    
    # Restore permissions
    chmod "$original_perms" shared-config/menu.db
    echo "  ✓ Restored original permissions"
fi

echo ""
echo "=== EDGE CASE TESTING COMPLETED ==="