#!/bin/bash
# Test external tools configuration

echo "=== EXTERNAL TOOLS CONFIGURATION TESTING ==="

# Load configuration
if [[ -f "local-config/.env" ]]; then
    source local-config/.env
    echo "✓ Configuration loaded"
else
    echo "❌ Configuration file not found"
    exit 1
fi

echo ""
echo "Testing configured paths..."

# Test GAM path
echo "GAM_PATH: $GAM_PATH"
if [[ -n "$GAM_PATH" ]]; then
    if [[ -f "$GAM_PATH" ]]; then
        echo "✓ GAM executable exists at $GAM_PATH"
        if [[ -x "$GAM_PATH" ]]; then
            echo "✓ GAM executable has execute permissions"
            # Test GAM version (with timeout to avoid hanging)
            gam_version=$(timeout 5s "$GAM_PATH" version 2>&1 || echo "TIMEOUT")
            if [[ "$gam_version" != "TIMEOUT" ]]; then
                echo "✓ GAM responds to version command"
                echo "  Version info: $(echo "$gam_version" | head -1)"
            else
                echo "⚠️  GAM version command timed out or failed"
            fi
        else
            echo "❌ GAM executable lacks execute permissions"
        fi
    else
        echo "❌ GAM executable not found at $GAM_PATH"
    fi
else
    echo "❌ GAM_PATH not configured"
fi

echo ""
echo "Testing Python environment..."

# Test Python path
echo "PYTHON_PATH: $PYTHON_PATH"
if [[ -n "$PYTHON_PATH" ]]; then
    if [[ -f "$PYTHON_PATH" ]]; then
        echo "✓ Python executable exists"
        python_version=$("$PYTHON_PATH" --version 2>&1)
        echo "✓ Python version: $python_version"
    else
        echo "❌ Python executable not found at $PYTHON_PATH"
    fi
else
    echo "⚠️  PYTHON_PATH not configured, testing system python"
    if command -v python3 >/dev/null 2>&1; then
        echo "✓ System python3 available"
        echo "  Version: $(python3 --version)"
    else
        echo "❌ No Python available"
    fi
fi

# Test Python virtual environment
echo ""
echo "PYTHON_VENV_PATH: $PYTHON_VENV_PATH"
if [[ -n "$PYTHON_VENV_PATH" ]]; then
    if [[ -d "$PYTHON_VENV_PATH" ]]; then
        echo "✓ Virtual environment directory exists"
        if [[ -f "$PYTHON_VENV_PATH/bin/activate" ]]; then
            echo "✓ Virtual environment properly configured"
        else
            echo "❌ Virtual environment missing activation script"
        fi
    else
        echo "❌ Virtual environment directory not found"
    fi
else
    echo "⚠️  PYTHON_VENV_PATH not configured"
fi

echo ""
echo "=== EXTERNAL TOOLS TESTING COMPLETED ==="