#!/bin/bash
# Test backup and recovery functionality

echo "=== BACKUP & RECOVERY TESTING ==="

# Test backup directory structure
echo ""
echo "Testing backup directory structure..."

if [[ -d "backups" ]]; then
    echo "✓ Backups directory exists"
    backup_count=$(find backups -type f -name "*.db" 2>/dev/null | wc -l)
    echo "  Database backups found: $backup_count"
    
    if [[ $backup_count -gt 0 ]]; then
        echo "✓ Backup files present"
        echo "  Latest backup: $(ls -t backups/*.db 2>/dev/null | head -1)"
    else
        echo "⚠️  No backup files found"
    fi
else
    echo "⚠️  Backups directory does not exist"
fi

# Test database backup functionality
echo ""
echo "Testing database backup creation..."

# Check if backup function exists in database_functions.sh
if grep -q "create_backup\|backup.*database" shared-utilities/database_functions.sh; then
    echo "✓ Backup functions found in database_functions.sh"
else
    echo "❌ Backup functions not found"
fi

# Test local database existence for backup
echo ""
echo "Testing local database for backup..."

if [[ -f "local-config/gwombat.db" ]]; then
    echo "✓ Main database exists"
    
    # Test database integrity
    integrity=$(sqlite3 local-config/gwombat.db "PRAGMA integrity_check;" 2>&1)
    if [[ "$integrity" == "ok" ]]; then
        echo "✓ Database integrity check passed"
    else
        echo "❌ Database integrity check failed: $integrity"
    fi
    
    # Test database size
    db_size=$(stat -f%z local-config/gwombat.db 2>/dev/null || echo "unknown")
    echo "  Database size: $db_size bytes"
    
else
    echo "❌ Main database not found"
fi

# Test menu database backup
echo ""
echo "Testing menu database for backup..."

if [[ -f "shared-config/menu.db" ]]; then
    echo "✓ Menu database exists"
    
    menu_integrity=$(sqlite3 shared-config/menu.db "PRAGMA integrity_check;" 2>&1)
    if [[ "$menu_integrity" == "ok" ]]; then
        echo "✓ Menu database integrity check passed"
    else
        echo "❌ Menu database integrity check failed: $menu_integrity"
    fi
else
    echo "❌ Menu database not found"
fi

# Test backup restoration capability
echo ""
echo "Testing backup restoration capability..."

# Look for restore functions
if grep -q "restore.*backup\|restore.*database" shared-utilities/database_functions.sh; then
    echo "✓ Restore functions found"
else
    echo "⚠️  Restore functions not clearly identified"
fi

# Test backup validation
echo ""
echo "Testing backup validation..."

# Check if there are any automated backup validation mechanisms
if grep -q "validate.*backup\|verify.*backup" shared-utilities/database_functions.sh; then
    echo "✓ Backup validation functions found"
else
    echo "⚠️  No backup validation functions found"
fi

echo ""
echo "=== BACKUP & RECOVERY TESTING COMPLETED ==="