#!/bin/bash
# Test Python module integration

echo "=== PYTHON MODULE TESTING ==="

# Test Python modules directory
echo ""
echo "Testing Python modules directory..."

if [[ -d "python-modules" ]]; then
    echo "✓ Python modules directory exists"
    
    # List Python files
    python_files=$(find python-modules -name "*.py" -type f 2>/dev/null)
    if [[ -n "$python_files" ]]; then
        echo "✓ Python files found:"
        echo "$python_files" | while read -r file; do
            echo "  - $file"
        done
    else
        echo "❌ No Python files found"
    fi
else
    echo "❌ Python modules directory not found"
    exit 1
fi

# Test individual Python modules
echo ""
echo "Testing individual Python modules..."

# Test compliance dashboard
if [[ -f "python-modules/compliance_dashboard.py" ]]; then
    echo "  Testing compliance_dashboard.py..."
    python_output=$(python3 python-modules/compliance_dashboard.py --help 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "  ✓ Compliance dashboard responds to --help"
    else
        echo "  ❌ Compliance dashboard error: $(echo "$python_output" | head -1)"
    fi
else
    echo "  ❌ compliance_dashboard.py not found"
fi

# Test SCuBA compliance module
if [[ -f "python-modules/scuba_compliance.py" ]]; then
    echo "  Testing scuba_compliance.py..."
    python_test=$(python3 -c "import sys; sys.path.append('python-modules'); import scuba_compliance; print('✓ Module imports successfully')" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "  $python_test"
    else
        echo "  ❌ SCuBA compliance module error: $(echo "$python_test" | head -1)"
    fi
else
    echo "  ❌ scuba_compliance.py not found"
fi

# Test GWS API module
if [[ -f "python-modules/gws_api.py" ]]; then
    echo "  Testing gws_api.py..."
    api_test=$(python3 -c "import sys; sys.path.append('python-modules'); import gws_api; print('✓ GWS API module imports successfully')" 2>&1)
    if [[ $? -eq 0 ]]; then
        echo "  $api_test"
    else
        echo "  ❌ GWS API module error: $(echo "$api_test" | head -1)"
    fi
else
    echo "  ❌ gws_api.py not found"
fi

# Test virtual environment
echo ""
echo "Testing Python virtual environment..."

if [[ -d "python-modules/venv" ]]; then
    echo "✓ Virtual environment directory exists"
    
    if [[ -f "python-modules/venv/bin/activate" ]]; then
        echo "✓ Virtual environment activation script exists"
        
        # Test activating virtual environment
        echo "  Testing virtual environment activation..."
        venv_test=$(source python-modules/venv/bin/activate && python --version 2>&1)
        if [[ $? -eq 0 ]]; then
            echo "  ✓ Virtual environment activates successfully"
            echo "    Version: $venv_test"
        else
            echo "  ❌ Virtual environment activation failed: $venv_test"
        fi
    else
        echo "❌ Virtual environment activation script not found"
    fi
else
    echo "❌ Virtual environment directory not found"
fi

# Test Python requirements
echo ""
echo "Testing Python requirements..."

if [[ -f "python-modules/requirements.txt" ]]; then
    echo "✓ Requirements file exists"
    
    # Check if packages are installed
    echo "  Testing required packages..."
    while IFS= read -r requirement; do
        [[ -z "$requirement" || "$requirement" =~ ^# ]] && continue
        
        # Extract package name (before any version specifiers)
        package=$(echo "$requirement" | sed 's/[>=<].*//' | sed 's/[[:space:]].*//')
        [[ -n "$package" ]] || continue
        
        if python3 -c "import $package" 2>/dev/null; then
            echo "    ✓ $package is installed"
        else
            echo "    ❌ $package is NOT installed"
        fi
    done < python-modules/requirements.txt
else
    echo "❌ Requirements file not found"
fi

# Test Python module integration with shell scripts
echo ""
echo "Testing Python-shell integration..."

# Look for Python calls in shell scripts
python_calls=$(grep -n "python3.*python-modules\|python.*python-modules" shared-utilities/*.sh 2>/dev/null)
if [[ -n "$python_calls" ]]; then
    echo "✓ Python integration calls found in shell scripts:"
    echo "$python_calls" | head -3
else
    echo "⚠️  No Python integration calls found in shell scripts"
fi

# Test if Python modules can access GWOMBAT data
echo ""
echo "Testing Python access to GWOMBAT data..."

if [[ -f "local-config/gwombat.db" ]]; then
    # Test if Python can read the database
    db_test=$(python3 -c "
import sqlite3
try:
    conn = sqlite3.connect('local-config/gwombat.db')
    cursor = conn.cursor()
    cursor.execute('SELECT COUNT(*) FROM accounts')
    count = cursor.fetchone()[0]
    print(f'✓ Python can access database, found {count} accounts')
    conn.close()
except Exception as e:
    print(f'❌ Python database access failed: {e}')
" 2>&1)
    echo "  $db_test"
else
    echo "  ❌ Main database not available for Python testing"
fi

echo ""
echo "=== PYTHON MODULE TESTING COMPLETED ==="