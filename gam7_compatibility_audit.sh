#!/bin/bash
# GAM7 Compatibility Audit for GWOMBAT
# Identifies and fixes GAM command compatibility issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$SCRIPT_DIR"

# Create audit report directory
AUDIT_DATE=$(date +%Y%m%d-%H%M%S)
AUDIT_DIR="$GWOMBAT_ROOT/reports/gam7-audit-$AUDIT_DATE"
mkdir -p "$AUDIT_DIR"

AUDIT_LOG="$AUDIT_DIR/gam7-compatibility-audit.log"
ISSUES_FOUND="$AUDIT_DIR/issues-found.txt"
FIXES_APPLIED="$AUDIT_DIR/fixes-applied.txt"

echo "GAM7 Compatibility Audit for GWOMBAT" > "$AUDIT_LOG"
echo "====================================" >> "$AUDIT_LOG"
echo "Date: $(date)" >> "$AUDIT_LOG"
echo "Directory: $GWOMBAT_ROOT" >> "$AUDIT_LOG"
echo "" >> "$AUDIT_LOG"

log_audit() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$AUDIT_LOG"
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[ERROR]${NC} $message"
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    elif [[ "$level" == "FIX" ]]; then
        echo -e "${GREEN}[FIX]${NC} $message"
        echo "$message" >> "$FIXES_APPLIED"
    else
        echo -e "${CYAN}[INFO]${NC} $message"
    fi
}

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                     GAM7 Compatibility Audit for GWOMBAT                    ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_audit "Starting GAM7 compatibility audit"

# Initialize counters
ISSUES_COUNT=0
FIXES_COUNT=0

# Function to track issues
track_issue() {
    local file="$1"
    local line="$2"
    local issue="$3"
    local severity="${4:-MEDIUM}"
    
    ((ISSUES_COUNT++))
    echo "$file:$line [$severity] $issue" >> "$ISSUES_FOUND"
    log_audit "Issue #$ISSUES_COUNT in $file:$line - $issue" "WARN"
}

# Function to apply fix
apply_fix() {
    local file="$1"
    local description="$2"
    
    ((FIXES_COUNT++))
    log_audit "Fix #$FIXES_COUNT: $description in $file" "FIX"
}

echo "Scanning GWOMBAT codebase for GAM command compatibility issues..."
echo ""

# 1. Check for deprecated GAM commands
log_audit "Checking for deprecated GAM commands"

# Find files with GAM commands
GAM_FILES=$(find "$GWOMBAT_ROOT" -name "*.sh" -type f | grep -v ".git" | grep -v "audit")

for file in $GAM_FILES; do
    if [[ -f "$file" ]]; then
        # Check for deprecated print commands that need field specifications
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ \$GAM.*print.*users[^[:space:]]*[[:space:]]*$ ]]; then
                track_issue "$file" "$line_num" "print users without fields specification (GAM7 requires explicit fields)" "HIGH"
            fi
        done < <(grep -n '\$GAM.*print.*users' "$file" 2>/dev/null)
        
        # Check for print groups without fields
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ \$GAM.*print.*groups[^[:space:]]*[[:space:]]*$ ]]; then
                track_issue "$file" "$line_num" "print groups without fields specification (GAM7 requires explicit fields)" "HIGH"
            fi
        done < <(grep -n '\$GAM.*print.*groups' "$file" 2>/dev/null)
        
        # Check for deprecated teamdrives command (should be shareddrives)
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ teamdrives ]]; then
                track_issue "$file" "$line_num" "teamdrives is deprecated, use shareddrives in GAM7" "MEDIUM"
            fi
        done < <(grep -n 'teamdrives' "$file" 2>/dev/null)
        
        # Check for deprecated claim ownership command
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ "claim ownership" ]]; then
                track_issue "$file" "$line_num" "claim ownership syntax may have changed in GAM7" "MEDIUM"
            fi
        done < <(grep -n 'claim ownership' "$file" 2>/dev/null)
        
        # Check for CSV output format changes
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ \$GAM.*print.*\|.*tail.*\+2 ]]; then
                track_issue "$file" "$line_num" "CSV header handling may need update for GAM7" "LOW"
            fi
        done < <(grep -n '\$GAM.*print.*|.*tail.*+2' "$file" 2>/dev/null)
        
        # Check for oauth create without domain parameter
        while IFS=: read -r line_num line_content; do
            if [[ "$line_content" =~ "oauth create"$ ]]; then
                track_issue "$file" "$line_num" "oauth create may need domain parameter in GAM7" "MEDIUM"
            fi
        done < <(grep -n 'oauth create$' "$file" 2>/dev/null)
    fi
done

# 2. Create fixes for common issues
log_audit "Generating fixes for identified issues"

echo ""
echo -e "${CYAN}Applying automatic fixes where safe...${NC}"

# Fix 1: Update teamdrives to shareddrives
for file in $GAM_FILES; do
    if [[ -f "$file" && -w "$file" ]]; then
        if grep -q 'teamdrives' "$file"; then
            sed -i.bak 's/teamdrives/shareddrives/g' "$file"
            apply_fix "$file" "Updated teamdrives to shareddrives"
        fi
    fi
done

# Fix 2: Add common fields to print users commands
for file in $GAM_FILES; do
    if [[ -f "$file" && -w "$file" ]]; then
        # Add fields to basic print users commands
        if grep -q '\$GAM print users$' "$file"; then
            sed -i.bak 's/\$GAM print users$/\$GAM print users fields primaryEmail,name.fullName,suspended,orgUnitPath/g' "$file"
            apply_fix "$file" "Added fields specification to print users command"
        fi
        
        # Add fields to print groups commands  
        if grep -q '\$GAM print groups$' "$file"; then
            sed -i.bak 's/\$GAM print groups$/\$GAM print groups fields email,name,description,directMembersCount/g' "$file"
            apply_fix "$file" "Added fields specification to print groups command"
        fi
    fi
done

# Fix 3: Update print filelist commands for better GAM7 compatibility
for file in $GAM_FILES; do
    if [[ -f "$file" && -w "$file" ]]; then
        # Ensure filelist commands have proper fields
        if grep -q 'print filelist$' "$file"; then
            sed -i.bak 's/print filelist$/print filelist fields id,name,mimeType,owners.emailAddress,size,shared/g' "$file"
            apply_fix "$file" "Added fields specification to print filelist command"
        fi
    fi
done

# 3. Generate GAM7 compatible wrapper functions
log_audit "Creating GAM7 compatibility wrapper"

cat > "$GWOMBAT_ROOT/gam7_wrapper.sh" << 'EOF'
#!/bin/bash
# GAM7 Compatibility Wrapper for GWOMBAT
# Provides backward compatibility for GAM commands

# Source the main configuration
if [[ -f "./.env" ]]; then
    source "./.env"
fi

# Set GAM path
GAM_PATH="${GAM_PATH:-${GAM:-gam}}"

# GAM7 compatible wrapper function
gam7() {
    local cmd="$1"
    shift
    
    case "$cmd" in
        "print")
            local resource="$1"
            shift
            case "$resource" in
                "users")
                    # Ensure fields are specified for users
                    if [[ "$*" != *"fields"* ]]; then
                        "$GAM_PATH" print users fields primaryEmail,name.fullName,suspended,orgUnitPath "$@"
                    else
                        "$GAM_PATH" print users "$@"
                    fi
                    ;;
                "groups")
                    # Ensure fields are specified for groups
                    if [[ "$*" != *"fields"* ]]; then
                        "$GAM_PATH" print groups fields email,name,description,directMembersCount "$@"
                    else
                        "$GAM_PATH" print groups "$@"
                    fi
                    ;;
                "teamdrives")
                    # Redirect teamdrives to shareddrives
                    echo "Warning: teamdrives is deprecated, using shareddrives" >&2
                    "$GAM_PATH" print shareddrives "$@"
                    ;;
                *)
                    "$GAM_PATH" print "$resource" "$@"
                    ;;
            esac
            ;;
        "oauth")
            if [[ "$1" == "create" && "$*" != *"domain"* ]]; then
                echo "Note: Consider adding domain parameter for GAM7" >&2
            fi
            "$GAM_PATH" oauth "$@"
            ;;
        *)
            "$GAM_PATH" "$cmd" "$@"
            ;;
    esac
}

# Export the function for use in scripts
export -f gam7
EOF

apply_fix "gam7_wrapper.sh" "Created GAM7 compatibility wrapper"

# 4. Generate migration guide
log_audit "Creating GAM7 migration guide"

cat > "$AUDIT_DIR/GAM7_Migration_Guide.md" << 'EOF'
# GAM7 Migration Guide for GWOMBAT

## Overview
This guide covers the migration from GAM6 to GAM7 for GWOMBAT users.

## Major Changes in GAM7

### 1. Required Fields for Print Commands
GAM7 requires explicit field specifications for many print commands:

**Before (GAM6):**
```bash
gam print users
gam print groups
```

**After (GAM7):**
```bash
gam print users fields primaryEmail,name.fullName,suspended,orgUnitPath
gam print groups fields email,name,description,directMembersCount
```

### 2. TeamDrives → SharedDrives
The `teamdrives` command has been renamed to `shareddrives`:

**Before:**
```bash
gam print teamdrives
```

**After:**
```bash
gam print shareddrives
```

### 3. OAuth Configuration
OAuth creation may require domain specification:

**Enhanced:**
```bash
gam oauth create domain yourdomain.edu
```

### 4. CSV Output Changes
GAM7 may have slightly different CSV output formats. Scripts that parse CSV output should be tested.

## GWOMBAT-Specific Updates

### Files Modified
The audit has automatically updated the following:
- Replaced `teamdrives` with `shareddrives`
- Added field specifications to basic print commands
- Created backup files (.bak) for all modified files

### Using the GAM7 Wrapper
A compatibility wrapper has been created at `gam7_wrapper.sh`. To use:

```bash
source ./gam7_wrapper.sh
gam7 print users  # Will automatically add fields
```

### Testing Your Migration
1. Verify GAM7 installation: `gam version`
2. Test basic commands: `gam print users fields primaryEmail`
3. Run GWOMBAT dependency check: `./gwombat.sh` → Configuration → Test configuration
4. Test key workflows with a small dataset

### Rollback Instructions
If issues occur, restore from backup files:

```bash
for file in *.bak; do
    mv "$file" "${file%.bak}"
done
```

## Verification Steps
- [ ] GAM7 installed and working
- [ ] All GWOMBAT scripts pass syntax check
- [ ] Key workflows tested
- [ ] Database operations working
- [ ] Backup/restore functions tested
EOF

# 5. Generate test script for GAM7 compatibility
cat > "$AUDIT_DIR/test_gam7_compatibility.sh" << 'EOF'
#!/bin/bash
# GAM7 Compatibility Test Script for GWOMBAT

echo "Testing GAM7 Compatibility..."

# Test basic GAM7 commands
echo "1. Testing GAM version..."
gam version

echo "2. Testing user listing with fields..."
gam print users fields primaryEmail maxResults 5

echo "3. Testing group listing with fields..."
gam print groups fields email maxResults 5

echo "4. Testing shared drives (was teamdrives)..."
gam print shareddrives maxResults 5

echo "5. Testing domain info..."
gam info domain

echo "GAM7 compatibility test completed."
EOF

chmod +x "$AUDIT_DIR/test_gam7_compatibility.sh"
apply_fix "test_gam7_compatibility.sh" "Created GAM7 compatibility test script"

# 6. Summary report
echo ""
echo -e "${BLUE}=== GAM7 Compatibility Audit Summary ===${NC}"
echo ""
echo "Audit completed: $(date)"
echo "Issues found: $ISSUES_COUNT"
echo "Fixes applied: $FIXES_COUNT"
echo ""
echo "Report directory: $AUDIT_DIR"
echo "Detailed log: $AUDIT_LOG"
echo ""

if [[ $ISSUES_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}Issues requiring attention:${NC}"
    head -10 "$ISSUES_FOUND" 2>/dev/null || echo "See $ISSUES_FOUND for details"
    echo ""
fi

if [[ $FIXES_COUNT -gt 0 ]]; then
    echo -e "${GREEN}Automatic fixes applied:${NC}"
    head -5 "$FIXES_APPLIED" 2>/dev/null || echo "See $FIXES_APPLIED for details"
    echo ""
fi

echo -e "${CYAN}Next steps:${NC}"
echo "1. Review the migration guide: $AUDIT_DIR/GAM7_Migration_Guide.md"
echo "2. Test GAM7 compatibility: $AUDIT_DIR/test_gam7_compatibility.sh"
echo "3. Verify GWOMBAT functionality with: ./gwombat.sh"
echo "4. Check backup files (*.bak) and remove when satisfied"
echo ""

log_audit "GAM7 compatibility audit completed - $ISSUES_COUNT issues found, $FIXES_COUNT fixes applied"

echo -e "${GREEN}✅ GAM7 Compatibility Audit Complete!${NC}"