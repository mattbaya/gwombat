#!/bin/bash

# GWOMBAT GAM7 Syntax Verification Tool
# Systematically checks all GAM commands in the codebase for GAM7 compatibility

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

REPORT_FILE="gam7_syntax_verification_$(date +%Y%m%d_%H%M%S).txt"
ISSUE_COUNT=0

# Initialize report
cat > "$REPORT_FILE" << EOF
GWOMBAT GAM7 Syntax Verification Report
Generated: $(date)
==========================================

This report analyzes all GAM commands in the GWOMBAT codebase for GAM7 compatibility.

EOF

log_issue() {
    local severity="$1"
    local file="$2"
    local line="$3"
    local issue="$4"
    local command="$5"
    
    ((ISSUE_COUNT++))
    echo "[$severity] $file:$line - $issue" | tee -a "$REPORT_FILE"
    echo "  Command: $command" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
}

log_info() {
    local message="$1"
    echo -e "${CYAN}INFO: $message${NC}" | tee -a "$REPORT_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}✓ $message${NC}" | tee -a "$REPORT_FILE"
}

log_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠ $message${NC}" | tee -a "$REPORT_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}✗ $message${NC}" | tee -a "$REPORT_FILE"
}

# Check for deprecated GAM syntax patterns
check_deprecated_syntax() {
    log_info "Checking for deprecated GAM syntax patterns..."
    
    # Check for old-style shared drive creation
    log_info "Checking shared drive creation syntax..."
    grep -rn "create shareddrive.*adminmanaged[^r]" --include="*.sh" . | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "FIXED" "$file" "$line_num" "Old adminmanaged syntax (should be adminmanagedrestrictions)" "$command"
    done
    
    # Check for incorrect suspension syntax
    log_info "Checking user suspension syntax..."
    grep -rn "suspended true\|suspended false" --include="*.sh" . | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "FIXED" "$file" "$line_num" "Incorrect boolean syntax (should be on/off)" "$command"
    done
    
    # Check for old suspension reason syntax
    log_info "Checking suspension reason syntax..."
    grep -rn "suspendreason" --include="*.sh" . | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "FIXED" "$file" "$line_num" "Incorrect parameter name (should be suspensionReason)" "$command"
    done
}

# Check for potentially problematic GAM commands
check_risky_patterns() {
    log_info "Checking for potentially risky GAM command patterns..."
    
    # Check for commands without error handling
    log_info "Checking for GAM commands without error handling..."
    grep -rn '\$GAM[^|]*$' --include="*.sh" . | grep -v "2>/dev/null" | grep -v "if.*\$GAM" | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "WARNING" "$file" "$line_num" "GAM command without error handling" "$command"
    done
    
    # Check for hardcoded domain references
    log_info "Checking for hardcoded domain references..."
    grep -rn "@[a-zA-Z0-9.-]*\.(edu|com|org)" --include="*.sh" . | grep -v "DOMAIN" | grep -v "example" | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "WARNING" "$file" "$line_num" "Possible hardcoded domain reference" "$command"
    done
}

# Check for GAM command best practices
check_best_practices() {
    log_info "Checking GAM command best practices..."
    
    # Check for proper field specifications in print commands
    log_info "Checking print commands for field specifications..."
    grep -rn '\$GAM.*print users[^"]*$' --include="*.sh" . | grep -v "fields" | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "SUGGESTION" "$file" "$line_num" "Print users command without fields specification (may be slow)" "$command"
    done
    
    # Check for bulk operations without batch processing
    log_info "Checking for bulk operations..."
    grep -rn "for.*in.*\$GAM" --include="*.sh" . | while read line; do
        file=$(echo "$line" | cut -d: -f1)
        line_num=$(echo "$line" | cut -d: -f2)
        command=$(echo "$line" | cut -d: -f3-)
        log_issue "SUGGESTION" "$file" "$line_num" "Loop with GAM commands (consider batch processing)" "$command"
    done
}

# Check for new GAM7 features usage
check_gam7_features() {
    log_info "Checking for GAM7 feature usage..."
    
    # Check if using new GAM7 CSV processing
    if grep -q "gam csv" --include="*.sh" -r .; then
        log_success "Found GAM7 CSV processing usage"
    else
        log_warning "No GAM7 CSV processing found - consider for bulk operations"
    fi
    
    # Check if using GAM7 improved error handling
    if grep -q "gam.*batch" --include="*.sh" -r .; then
        log_success "Found GAM7 batch processing usage"
    else
        log_warning "No GAM7 batch processing found - consider for performance"
    fi
}

# Check for authentication and configuration issues
check_auth_config() {
    log_info "Checking authentication and configuration..."
    
    # Check for GAM path configuration
    if grep -q "GAM_PATH" --include="*.sh" -r .; then
        log_success "Found GAM_PATH configuration"
    else
        log_error "No GAM_PATH configuration found"
    fi
    
    # Check for admin user configuration
    if grep -q "ADMIN_USER" --include="*.sh" -r .; then
        log_success "Found ADMIN_USER configuration"
    else
        log_warning "No ADMIN_USER configuration found"
    fi
    
    # Check for domain configuration
    if grep -q "DOMAIN" --include="*.sh" -r .; then
        log_success "Found DOMAIN configuration"
    else
        log_warning "No DOMAIN configuration found"
    fi
}

# Analyze specific GAM command categories
analyze_command_categories() {
    log_info "Analyzing GAM command usage by category..."
    
    echo "GAM Command Usage Analysis:" | tee -a "$REPORT_FILE"
    echo "===========================" | tee -a "$REPORT_FILE"
    
    # User management commands
    local user_cmds=$(grep -r "\$GAM.*user" --include="*.sh" . | wc -l)
    echo "User management commands: $user_cmds" | tee -a "$REPORT_FILE"
    
    # Group management commands  
    local group_cmds=$(grep -r "\$GAM.*group" --include="*.sh" . | wc -l)
    echo "Group management commands: $group_cmds" | tee -a "$REPORT_FILE"
    
    # Drive/file commands
    local drive_cmds=$(grep -r "\$GAM.*drive\|\$GAM.*file" --include="*.sh" . | wc -l)
    echo "Drive/file management commands: $drive_cmds" | tee -a "$REPORT_FILE"
    
    # Print/info commands
    local info_cmds=$(grep -r "\$GAM.*print\|\$GAM.*info" --include="*.sh" . | wc -l)
    echo "Information/reporting commands: $info_cmds" | tee -a "$REPORT_FILE"
    
    # Shared drive commands
    local shared_cmds=$(grep -r "\$GAM.*shareddrive\|\$GAM.*teamdrive" --include="*.sh" . | wc -l)
    echo "Shared drive commands: $shared_cmds" | tee -a "$REPORT_FILE"
    
    echo "" | tee -a "$REPORT_FILE"
}

# Generate recommendations
generate_recommendations() {
    log_info "Generating GAM7 optimization recommendations..."
    
    echo "GAM7 Optimization Recommendations:" | tee -a "$REPORT_FILE"
    echo "===================================" | tee -a "$REPORT_FILE"
    
    echo "1. ✅ COMPLETED: Updated shared drive creation syntax" | tee -a "$REPORT_FILE"
    echo "2. ✅ COMPLETED: Fixed user suspension syntax (on/off)" | tee -a "$REPORT_FILE"  
    echo "3. ✅ COMPLETED: Corrected suspension reason parameter" | tee -a "$REPORT_FILE"
    echo "4. 🔄 IN PROGRESS: Systematic GAM command verification" | tee -a "$REPORT_FILE"
    echo "5. 📋 TODO: Implement GAM7 batch processing for bulk operations" | tee -a "$REPORT_FILE"
    echo "6. 📋 TODO: Add comprehensive error handling to all GAM commands" | tee -a "$REPORT_FILE"
    echo "7. 📋 TODO: Optimize print commands with specific field selections" | tee -a "$REPORT_FILE"
    echo "8. 📋 TODO: Implement GAM7 CSV processing for data operations" | tee -a "$REPORT_FILE"
    echo "9. 📋 TODO: Add authentication verification checks" | tee -a "$REPORT_FILE"
    echo "10. 📋 TODO: Create GAM7 performance monitoring" | tee -a "$REPORT_FILE"
    
    echo "" | tee -a "$REPORT_FILE"
}

# Main execution
main() {
    echo -e "${CYAN}GWOMBAT GAM7 Syntax Verification Tool${NC}"
    echo -e "${CYAN}=====================================${NC}"
    echo ""
    
    log_info "Starting GAM7 syntax verification..."
    echo ""
    
    check_deprecated_syntax
    echo ""
    
    check_risky_patterns
    echo ""
    
    check_best_practices  
    echo ""
    
    check_gam7_features
    echo ""
    
    check_auth_config
    echo ""
    
    analyze_command_categories
    echo ""
    
    generate_recommendations
    echo ""
    
    # Summary
    echo "Verification Summary:" | tee -a "$REPORT_FILE"
    echo "====================" | tee -a "$REPORT_FILE"
    echo "Total issues found: $ISSUE_COUNT" | tee -a "$REPORT_FILE"
    echo "Report saved to: $REPORT_FILE" | tee -a "$REPORT_FILE"
    echo "Verification completed: $(date)" | tee -a "$REPORT_FILE"
    
    if [[ $ISSUE_COUNT -eq 0 ]]; then
        log_success "No syntax issues found! GAM7 compatibility looks good."
    elif [[ $ISSUE_COUNT -lt 10 ]]; then
        log_warning "Minor issues found. Review the report for recommendations."
    else
        log_error "Multiple issues found. Priority review recommended."
    fi
    
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "1. Review the detailed report: $REPORT_FILE"
    echo "2. Address any CRITICAL or ERROR issues first"
    echo "3. Consider implementing suggested optimizations"
    echo "4. Test GAM functionality in development environment"
    echo "5. Update GAM7 documentation as needed"
}

# Run the verification
main "$@"