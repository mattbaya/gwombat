#!/bin/bash
# Test file system permissions and access patterns

echo "=== FILESYSTEM & PERMISSIONS TESTING ==="

# Test critical directory permissions
echo ""
echo "Testing directory permissions..."

directories=(
    "shared-utilities"
    "local-config"
    "shared-config"
    "python-modules"
    "backups"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        perms=$(stat -f%Mp%Lp "$dir" 2>/dev/null || stat -c%a "$dir" 2>/dev/null)
        echo "  $dir: permissions $perms"
        
        # Test write access
        if [[ -w "$dir" ]]; then
            echo "    ✓ Writable"
        else
            echo "    ❌ Not writable"
        fi
        
        # Test read access
        if [[ -r "$dir" ]]; then
            echo "    ✓ Readable"
        else
            echo "    ❌ Not readable"
        fi
    else
        echo "  ❌ Directory $dir does not exist"
    fi
done

# Test critical file permissions
echo ""
echo "Testing file permissions..."

critical_files=(
    "gwombat.sh"
    "local-config/.env"
    "shared-config/menu.db"
    "local-config/gwombat.db"
    "shared-utilities/database_functions.sh"
)

for file in "${critical_files[@]}"; do
    if [[ -f "$file" ]]; then
        perms=$(stat -f%Mp%Lp "$file" 2>/dev/null || stat -c%a "$file" 2>/dev/null)
        echo "  $file: permissions $perms"
        
        # Test execute permissions for scripts
        if [[ "$file" == *.sh ]]; then
            if [[ -x "$file" ]]; then
                echo "    ✓ Executable"
            else
                echo "    ❌ Not executable"
            fi
        fi
        
        # Test read permissions
        if [[ -r "$file" ]]; then
            echo "    ✓ Readable"
        else
            echo "    ❌ Not readable"
        fi
    else
        echo "  ❌ File $file does not exist"
    fi
done

# Test disk space availability
echo ""
echo "Testing disk space..."

disk_usage=$(df -h . 2>/dev/null | tail -1)
if [[ -n "$disk_usage" ]]; then
    echo "  Disk usage: $disk_usage"
    
    # Extract available space (4th column)
    available=$(echo "$disk_usage" | awk '{print $4}')
    echo "  Available space: $available"
    
    # Check if we have at least 1GB free
    available_mb=$(echo "$available" | sed 's/[^0-9]//g')
    if [[ -n "$available_mb" && $available_mb -gt 1000 ]]; then
        echo "    ✓ Sufficient disk space"
    else
        echo "    ⚠️  Low disk space warning"
    fi
else
    echo "  ❌ Could not determine disk usage"
fi

# Test log file access
echo ""
echo "Testing log file access..."

if [[ -n "$LOG_FILE" ]]; then
    echo "  Configured log file: $LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
        if [[ -w "$LOG_FILE" ]]; then
            echo "    ✓ Log file writable"
        else
            echo "    ❌ Log file not writable"
        fi
    else
        # Test if we can create log file
        log_dir=$(dirname "$LOG_FILE")
        if [[ -w "$log_dir" ]]; then
            echo "    ✓ Can create log file in $log_dir"
        else
            echo "    ❌ Cannot create log file in $log_dir"
        fi
    fi
else
    echo "  ⚠️  LOG_FILE not configured"
fi

# Test temporary directory access
echo ""
echo "Testing temporary directory access..."

temp_dirs=("/tmp" "/var/tmp" ".")

for temp_dir in "${temp_dirs[@]}"; do
    if [[ -d "$temp_dir" && -w "$temp_dir" ]]; then
        echo "  ✓ $temp_dir is writable"
        
        # Test creating temporary file
        temp_file="$temp_dir/gwombat_test_$$"
        if echo "test" > "$temp_file" 2>/dev/null; then
            echo "    ✓ Can create temporary files"
            rm -f "$temp_file"
        else
            echo "    ❌ Cannot create temporary files"
        fi
        break
    fi
done

# Test file locking capability
echo ""
echo "Testing file locking capability..."

lock_test_file="/tmp/gwombat_lock_test_$$"
if {
    exec 200>"$lock_test_file"
    flock -n 200
} 2>/dev/null; then
    echo "  ✓ File locking supported"
    exec 200>&-
    rm -f "$lock_test_file"
else
    echo "  ❌ File locking not supported or available"
fi

# Test symlink handling
echo ""
echo "Testing symlink handling..."

symlink_test_target="/tmp/gwombat_target_$$"
symlink_test_link="/tmp/gwombat_link_$$"

echo "test" > "$symlink_test_target"
if ln -s "$symlink_test_target" "$symlink_test_link" 2>/dev/null; then
    if [[ -L "$symlink_test_link" ]]; then
        echo "  ✓ Can create and detect symlinks"
    else
        echo "  ❌ Symlink creation or detection failed"
    fi
    rm -f "$symlink_test_link"
else
    echo "  ❌ Cannot create symlinks"
fi
rm -f "$symlink_test_target"

echo ""
echo "=== FILESYSTEM & PERMISSIONS TESTING COMPLETED ==="