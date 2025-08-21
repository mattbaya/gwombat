#!/bin/bash
# Test individual functions from gwombat.sh

echo "Testing function definitions..."

# Try to source gwombat.sh to get function definitions
if timeout 5s bash -c 'source gwombat.sh 2>/dev/null' 2>/dev/null; then
    echo "✓ gwombat.sh sourced successfully"
else
    echo "❌ Could not source gwombat.sh (may hang or have errors)"
fi

# Test specific function existence by parsing the file
echo ""
echo "Testing function definitions in gwombat.sh..."

functions_to_test=(
    "dashboard_menu"
    "statistics_menu"
    "user_group_management_menu"
    "file_drive_operations_menu"
    "generate_daily_report"
)

for func in "${functions_to_test[@]}"; do
    if grep -q "^${func}()" gwombat.sh; then
        echo "✓ Function $func defined"
    else
        echo "❌ Function $func not found"
    fi
done