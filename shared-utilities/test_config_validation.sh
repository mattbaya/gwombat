#!/bin/bash
# Test configuration validation specifically

echo "=== CONFIGURATION VALIDATION TESTING ==="

# Load configuration
if [[ -f "local-config/.env" ]]; then
    source local-config/.env
    echo "✓ Configuration file loaded"
else
    echo "❌ Configuration file not found"
    exit 1
fi

# Test domain validation
echo ""
echo "Testing domain validation..."
echo "  Domain: $DOMAIN"
if [[ -n "$DOMAIN" ]]; then
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "✓ Domain format appears valid"
    else
        echo "⚠️  Domain format may be invalid"
    fi
    
    # Test domain vs admin email mismatch (found in earlier testing)
    if [[ -n "$ADMIN_EMAIL" ]]; then
        admin_domain="${ADMIN_EMAIL#*@}"
        echo "  Admin email domain: $admin_domain"
        if [[ "$DOMAIN" != "$admin_domain" ]]; then
            echo "❌ DOMAIN MISMATCH: Config domain ($DOMAIN) ≠ Admin email domain ($admin_domain)"
        else
            echo "✓ Domain and admin email domain match"
        fi
    fi
else
    echo "❌ Domain not configured"
fi

# Test admin email validation
echo ""
echo "Testing admin email validation..."
echo "  Admin email: $ADMIN_EMAIL"
if [[ -n "$ADMIN_EMAIL" ]]; then
    if [[ "$ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "✓ Admin email format appears valid"
    else
        echo "❌ Admin email format invalid"
    fi
else
    echo "❌ Admin email not configured"
fi

# Test duplicate configuration values
echo ""
echo "Testing for duplicate configuration values..."
if [[ "$ADMIN_EMAIL" == "$ADMIN_USER" ]]; then
    echo "✓ ADMIN_EMAIL and ADMIN_USER are consistent"
else
    echo "⚠️  ADMIN_EMAIL ($ADMIN_EMAIL) differs from ADMIN_USER ($ADMIN_USER)"
fi

# Test path configurations
echo ""
echo "Testing path configurations..."

paths_to_test=(
    "GAM_PATH:$GAM_PATH"
    "PYTHON_PATH:$PYTHON_PATH"
    "PYTHON_VENV_PATH:$PYTHON_VENV_PATH"
    "SSH_KEY_PATH:$SSH_KEY_PATH"
)

for path_config in "${paths_to_test[@]}"; do
    IFS=':' read -r name path <<< "$path_config"
    echo "  Testing $name: $path"
    
    if [[ -n "$path" ]]; then
        if [[ "$path" =~ \.\. ]]; then
            echo "    ❌ Contains path traversal"
        elif [[ "$path" =~ ^/ ]]; then
            echo "    ✓ Absolute path"
            if [[ -e "$path" ]]; then
                echo "    ✓ Path exists"
            else
                echo "    ⚠️  Path does not exist"
            fi
        else
            echo "    ⚠️  Relative path"
        fi
    else
        echo "    ⚠️  Not configured"
    fi
done

# Test organizational unit paths
echo ""
echo "Testing organizational unit paths..."

ou_paths=(
    "SUSPENDED_OU:$SUSPENDED_OU"
    "PENDING_DELETION_OU:$PENDING_DELETION_OU"
    "TEMPORARY_HOLD_OU:$TEMPORARY_HOLD_OU"
    "EXIT_ROW_OU:$EXIT_ROW_OU"
)

for ou_config in "${ou_paths[@]}"; do
    IFS=':' read -r name ou_path <<< "$ou_config"
    echo "  Testing $name: $ou_path"
    
    if [[ -n "$ou_path" ]]; then
        if [[ "$ou_path" =~ ^/ ]]; then
            echo "    ✓ Proper OU path format"
        else
            echo "    ❌ Invalid OU path format (should start with /)"
        fi
    else
        echo "    ❌ OU path not configured"
    fi
done

# Test boolean configuration values
echo ""
echo "Testing boolean configuration values..."

boolean_configs=(
    "SETUP_COMPLETED:$SETUP_COMPLETED"
    "PYTHON_USE_VENV:$PYTHON_USE_VENV"
    "PYTHON_PACKAGES_INSTALLED:$PYTHON_PACKAGES_INSTALLED"
)

for bool_config in "${boolean_configs[@]}"; do
    IFS=':' read -r name value <<< "$bool_config"
    echo "  Testing $name: $value"
    
    if [[ "$value" == "true" || "$value" == "false" ]]; then
        echo "    ✓ Valid boolean value"
    elif [[ -z "$value" ]]; then
        echo "    ⚠️  Not configured"
    else
        echo "    ❌ Invalid boolean value (should be 'true' or 'false')"
    fi
done

echo ""
echo "=== CONFIGURATION VALIDATION TESTING COMPLETED ==="