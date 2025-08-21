#!/bin/bash
# Test core Python modules only

echo "=== CORE PYTHON MODULE TESTING ==="

# Test compliance dashboard
echo ""
echo "Testing compliance_dashboard.py..."
if [[ -f "python-modules/compliance_dashboard.py" ]]; then
    dashboard_result=$(python3 python-modules/compliance_dashboard.py --help 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "✓ Compliance dashboard responds to --help"
        echo "  $(echo "$dashboard_result" | head -2 | tail -1)"
    else
        echo "❌ Compliance dashboard error: $(echo "$dashboard_result" | head -1)"
    fi
else
    echo "❌ compliance_dashboard.py not found"
fi

# Test SCuBA compliance module imports
echo ""
echo "Testing scuba_compliance.py imports..."
scuba_test=$(python3 -c "
import sys
sys.path.append('python-modules')
try:
    import scuba_compliance
    print('✓ SCuBA compliance module imports successfully')
    # Test if it has main functions
    if hasattr(scuba_compliance, 'main'):
        print('✓ Main function found')
    else:
        print('⚠️  No main function found')
except ImportError as e:
    print(f'❌ Import error: {e}')
except Exception as e:
    print(f'❌ Other error: {e}')
" 2>&1)
echo "$scuba_test"

# Test GWS API module
echo ""
echo "Testing gws_api.py imports..."
gws_test=$(python3 -c "
import sys
sys.path.append('python-modules')
try:
    import gws_api
    print('✓ GWS API module imports successfully')
    # Check for key functions
    if hasattr(gws_api, 'GoogleWorkspaceAPI'):
        print('✓ GoogleWorkspaceAPI class found')
    else:
        print('⚠️  GoogleWorkspaceAPI class not found')
except ImportError as e:
    print(f'❌ Import error: {e}')
except Exception as e:
    print(f'❌ Other error: {e}')
" 2>&1)
echo "$gws_test"

# Test database connectivity from Python
echo ""
echo "Testing Python database connectivity..."
db_test=$(python3 -c "
import sqlite3
import os

# Test main database
if os.path.exists('local-config/gwombat.db'):
    try:
        conn = sqlite3.connect('local-config/gwombat.db')
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM accounts')
        count = cursor.fetchone()[0]
        print(f'✓ Python can access main database: {count} accounts')
        conn.close()
    except Exception as e:
        print(f'❌ Main database error: {e}')
else:
    print('⚠️  Main database not found')

# Test menu database
if os.path.exists('shared-config/menu.db'):
    try:
        conn = sqlite3.connect('shared-config/menu.db')
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) FROM menu_items')
        count = cursor.fetchone()[0]
        print(f'✓ Python can access menu database: {count} menu items')
        conn.close()
    except Exception as e:
        print(f'❌ Menu database error: {e}')
else:
    print('⚠️  Menu database not found')
" 2>&1)
echo "$db_test"

# Test requirements satisfaction
echo ""
echo "Testing key requirements..."
key_packages=("google-api-python-client" "google-auth" "sqlite3")

for package in "${key_packages[@]}"; do
    # Special handling for sqlite3 (built-in)
    if [[ "$package" == "sqlite3" ]]; then
        test_result=$(python3 -c "import sqlite3; print('✓ sqlite3 available')" 2>&1)
    else
        test_result=$(python3 -c "import importlib; importlib.import_module('${package}'.replace('-','_')); print('✓ $package available')" 2>&1)
    fi
    
    if [[ $? -eq 0 ]]; then
        echo "  $test_result"
    else
        echo "  ❌ $package: $(echo "$test_result" | head -1)"
    fi
done

echo ""
echo "=== CORE PYTHON MODULE TESTING COMPLETED ==="