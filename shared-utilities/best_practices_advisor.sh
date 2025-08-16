#!/bin/bash
# GWOMBAT Best Practices Advisor
# Provides recommendations for quotas, storage, and Google Workspace optimization

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$GWOMBAT_ROOT/.env" ]]; then
    source "$GWOMBAT_ROOT/.env"
fi

# Configuration
GAM="${GAM_PATH:-gam}"
DOMAIN="${DOMAIN:-your-domain.edu}"
ADMIN_USER="${ADMIN_USER:-gwombat@$DOMAIN}"

# Create reports directory
REPORTS_DIR="$GWOMBAT_ROOT/reports/best-practices-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORTS_DIR"

log_advisor() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] ADVISOR: $message" | tee -a "$GWOMBAT_ROOT/logs/best-practices.log"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARN")  echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "RECOMMENDATION") echo -e "${CYAN}[💡 RECOMMENDATION]${NC} $message" ;;
        *) echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

# Storage quota analysis
analyze_storage_quotas() {
    log_advisor "Analyzing storage quotas and usage patterns"
    
    local storage_report="$REPORTS_DIR/storage_analysis.txt"
    
    echo "GWOMBAT Storage Quota Analysis" > "$storage_report"
    echo "==============================" >> "$storage_report"
    echo "Date: $(date)" >> "$storage_report"
    echo "Domain: $DOMAIN" >> "$storage_report"
    echo "" >> "$storage_report"
    
    # Get domain storage info
    log_advisor "Gathering domain storage information"
    
    if command -v "$GAM" >/dev/null 2>&1 && $GAM info domain >/dev/null 2>&1; then
        # Domain-level storage
        echo "Domain Storage Information:" >> "$storage_report"
        echo "=========================" >> "$storage_report"
        $GAM info domain | grep -E "(Storage|Usage|Quota)" >> "$storage_report" 2>/dev/null || echo "Domain storage info not available" >> "$storage_report"
        echo "" >> "$storage_report"
        
        # User storage analysis
        echo "User Storage Analysis:" >> "$storage_report"
        echo "=====================" >> "$storage_report"
        
        local temp_users="/tmp/gwombat_users_storage.csv"
        if $GAM print users fields primaryEmail,quotaUsed,quotaLimit > "$temp_users" 2>/dev/null; then
            # Calculate storage statistics
            local total_users=$(tail -n +2 "$temp_users" | wc -l)
            local over_quota=0
            local high_usage=0
            local low_usage=0
            
            echo "Total users analyzed: $total_users" >> "$storage_report"
            echo "" >> "$storage_report"
            
            while IFS=, read -r email quota_used quota_limit; do
                [[ "$email" == "primaryEmail" ]] && continue
                
                # Convert to numbers (handle empty values)
                quota_used=${quota_used:-0}
                quota_limit=${quota_limit:-0}
                
                if [[ "$quota_used" -gt 0 && "$quota_limit" -gt 0 ]]; then
                    local usage_percent=$((quota_used * 100 / quota_limit))
                    
                    if [[ $usage_percent -ge 95 ]]; then
                        ((over_quota++))
                    elif [[ $usage_percent -ge 80 ]]; then
                        ((high_usage++))
                    elif [[ $usage_percent -le 10 ]]; then
                        ((low_usage++))
                    fi
                fi
                
            done < "$temp_users"
            
            echo "Storage Usage Distribution:" >> "$storage_report"
            echo "Over 95% (Critical): $over_quota users" >> "$storage_report"
            echo "80-95% (High): $high_usage users" >> "$storage_report"
            echo "Under 10% (Low): $low_usage users" >> "$storage_report"
            echo "" >> "$storage_report"
            
            # Generate recommendations
            echo "STORAGE RECOMMENDATIONS:" >> "$storage_report"
            echo "======================" >> "$storage_report"
            
            if [[ $over_quota -gt 0 ]]; then
                echo "⚠️  URGENT: $over_quota users over 95% quota" >> "$storage_report"
                echo "   Action: Review and clean up files, consider quota increase" >> "$storage_report"
                log_advisor "$over_quota users are over 95% storage quota - immediate attention needed" "WARN"
            fi
            
            if [[ $high_usage -gt 0 ]]; then
                echo "⚠️  WARNING: $high_usage users at 80-95% quota" >> "$storage_report"
                echo "   Action: Proactive cleanup, monitor growth trends" >> "$storage_report"
                log_advisor "$high_usage users approaching storage limits" "RECOMMENDATION"
            fi
            
            if [[ $low_usage -gt $((total_users / 4)) ]]; then
                echo "💡 OPTIMIZATION: $low_usage users using <10% of quota" >> "$storage_report"
                echo "   Action: Consider adjusting default quota allocations" >> "$storage_report"
                log_advisor "Many users have very low storage usage - quota optimization opportunity" "RECOMMENDATION"
            fi
            
            rm -f "$temp_users"
        else
            echo "Unable to retrieve user storage data" >> "$storage_report"
            log_advisor "Could not retrieve user storage data" "WARN"
        fi
        
        # Shared drive analysis
        echo "" >> "$storage_report"
        echo "Shared Drive Storage:" >> "$storage_report"
        echo "===================" >> "$storage_report"
        
        local temp_drives="/tmp/gwombat_drives_storage.csv"
        if $GAM print shareddrives > "$temp_drives" 2>/dev/null; then
            local drive_count=$(tail -n +2 "$temp_drives" | wc -l)
            echo "Total shared drives: $drive_count" >> "$storage_report"
            
            if [[ $drive_count -gt 100 ]]; then
                echo "💡 RECOMMENDATION: Large number of shared drives detected" >> "$storage_report"
                echo "   Action: Audit for unused drives, implement lifecycle management" >> "$storage_report"
                log_advisor "Large number of shared drives - consider lifecycle management" "RECOMMENDATION"
            fi
            
            rm -f "$temp_drives"
        fi
        
    else
        echo "GAM not available - storage analysis limited" >> "$storage_report"
        log_advisor "GAM not available for storage analysis" "WARN"
    fi
    
    echo "Storage analysis saved to: $storage_report"
    return 0
}

# Security best practices analysis
analyze_security_practices() {
    log_advisor "Analyzing security best practices compliance"
    
    local security_report="$REPORTS_DIR/security_recommendations.txt"
    
    echo "GWOMBAT Security Best Practices Analysis" > "$security_report"
    echo "=======================================" >> "$security_report"
    echo "Date: $(date)" >> "$security_report"
    echo "" >> "$security_report"
    
    if command -v "$GAM" >/dev/null 2>&1 && $GAM info domain >/dev/null 2>&1; then
        # 2FA Analysis
        echo "Two-Factor Authentication Analysis:" >> "$security_report"
        echo "=================================" >> "$security_report"
        
        local temp_2fa="/tmp/gwombat_2fa_analysis.csv"
        if $GAM print users fields primaryEmail,isEnforcedIn2Sv,isEnrolledIn2Sv > "$temp_2fa" 2>/dev/null; then
            local total_users=$(tail -n +2 "$temp_2fa" | wc -l)
            local enforced_2fa=0
            local enrolled_2fa=0
            
            while IFS=, read -r email enforced enrolled; do
                [[ "$email" == "primaryEmail" ]] && continue
                [[ "$enforced" == "True" ]] && ((enforced_2fa++))
                [[ "$enrolled" == "True" ]] && ((enrolled_2fa++))
            done < "$temp_2fa"
            
            local enforced_percent=$((enforced_2fa * 100 / total_users))
            local enrolled_percent=$((enrolled_2fa * 100 / total_users))
            
            echo "Total users: $total_users" >> "$security_report"
            echo "2FA Enforced: $enforced_2fa ($enforced_percent%)" >> "$security_report"
            echo "2FA Enrolled: $enrolled_2fa ($enrolled_percent%)" >> "$security_report"
            echo "" >> "$security_report"
            
            # Security recommendations
            echo "SECURITY RECOMMENDATIONS:" >> "$security_report"
            echo "========================" >> "$security_report"
            
            if [[ $enforced_percent -lt 100 ]]; then
                echo "🔴 CRITICAL: 2FA not enforced for all users" >> "$security_report"
                echo "   Action: Enable 2FA enforcement domain-wide" >> "$security_report"
                echo "   Impact: Significantly improves account security" >> "$security_report"
                log_advisor "2FA not enforced for all users - critical security risk" "WARN"
            else
                echo "✅ EXCELLENT: 2FA enforced for all users" >> "$security_report"
                log_advisor "2FA properly enforced domain-wide" "SUCCESS"
            fi
            
            if [[ $enrolled_percent -lt 90 ]]; then
                echo "⚠️  WARNING: Low 2FA enrollment rate" >> "$security_report"
                echo "   Action: User education and enrollment assistance" >> "$security_report"
                log_advisor "Low 2FA enrollment rate detected" "RECOMMENDATION"
            fi
            
            rm -f "$temp_2fa"
        fi
        
        # Admin account analysis
        echo "" >> "$security_report"
        echo "Administrative Account Security:" >> "$security_report"
        echo "==============================" >> "$security_report"
        
        local temp_admins="/tmp/gwombat_admins.csv"
        if $GAM print admins > "$temp_admins" 2>/dev/null; then
            local admin_count=$(tail -n +2 "$temp_admins" | wc -l)
            echo "Total admin accounts: $admin_count" >> "$security_report"
            
            if [[ $admin_count -gt 10 ]]; then
                echo "⚠️  WARNING: High number of admin accounts" >> "$security_report"
                echo "   Action: Review admin privileges, implement least privilege" >> "$security_report"
                log_advisor "High number of admin accounts detected" "RECOMMENDATION"
            elif [[ $admin_count -lt 2 ]]; then
                echo "⚠️  WARNING: Very few admin accounts" >> "$security_report"
                echo "   Action: Ensure adequate admin coverage for availability" >> "$security_report"
                log_advisor "Very few admin accounts - availability risk" "RECOMMENDATION"
            else
                echo "✅ GOOD: Appropriate number of admin accounts" >> "$security_report"
            fi
            
            rm -f "$temp_admins"
        fi
        
        # External sharing analysis
        echo "" >> "$security_report"
        echo "External Sharing Security:" >> "$security_report"
        echo "=========================" >> "$security_report"
        
        # Note: This would require more complex analysis of sharing settings
        echo "💡 RECOMMENDATION: Regular external sharing audits" >> "$security_report"
        echo "   Action: Use GWOMBAT's sharing analysis tools monthly" >> "$security_report"
        echo "   Benefit: Prevent data leakage and maintain compliance" >> "$security_report"
        
    else
        echo "GAM not available - security analysis limited" >> "$security_report"
    fi
    
    # General security recommendations
    echo "" >> "$security_report"
    echo "GENERAL SECURITY BEST PRACTICES:" >> "$security_report"
    echo "===============================" >> "$security_report"
    echo "" >> "$security_report"
    echo "1. ACCOUNT MANAGEMENT:" >> "$security_report"
    echo "   ✓ Enable 2FA for all accounts" >> "$security_report"
    echo "   ✓ Implement strong password policies" >> "$security_report"
    echo "   ✓ Regular review of admin privileges" >> "$security_report"
    echo "   ✓ Automated offboarding processes" >> "$security_report"
    echo "" >> "$security_report"
    echo "2. DATA PROTECTION:" >> "$security_report"
    echo "   ✓ Regular external sharing audits" >> "$security_report"
    echo "   ✓ Data loss prevention (DLP) policies" >> "$security_report"
    echo "   ✓ File encryption for sensitive data" >> "$security_report"
    echo "   ✓ Backup and recovery procedures" >> "$security_report"
    echo "" >> "$security_report"
    echo "3. MONITORING & COMPLIANCE:" >> "$security_report"
    echo "   ✓ Login activity monitoring" >> "$security_report"
    echo "   ✓ Admin activity auditing" >> "$security_report"
    echo "   ✓ Device management and compliance" >> "$security_report"
    echo "   ✓ Regular security assessments" >> "$security_report"
    
    echo "Security analysis saved to: $security_report"
    return 0
}

# Performance optimization recommendations
analyze_performance_optimization() {
    log_advisor "Analyzing performance optimization opportunities"
    
    local perf_report="$REPORTS_DIR/performance_recommendations.txt"
    
    echo "GWOMBAT Performance Optimization Recommendations" > "$perf_report"
    echo "===============================================" >> "$perf_report"
    echo "Date: $(date)" >> "$perf_report"
    echo "" >> "$perf_report"
    
    # Group management optimization
    echo "GROUP MANAGEMENT OPTIMIZATION:" >> "$perf_report"
    echo "=============================" >> "$perf_report"
    
    if command -v "$GAM" >/dev/null 2>&1; then
        local temp_groups="/tmp/gwombat_groups_perf.csv"
        if $GAM print groups fields email,directMembersCount > "$temp_groups" 2>/dev/null; then
            local total_groups=$(tail -n +2 "$temp_groups" | wc -l)
            local large_groups=0
            local empty_groups=0
            
            while IFS=, read -r group_email member_count; do
                [[ "$group_email" == "email" ]] && continue
                member_count=${member_count:-0}
                
                if [[ $member_count -gt 1000 ]]; then
                    ((large_groups++))
                elif [[ $member_count -eq 0 ]]; then
                    ((empty_groups++))
                fi
            done < "$temp_groups"
            
            echo "Total groups: $total_groups" >> "$perf_report"
            echo "Large groups (>1000 members): $large_groups" >> "$perf_report"
            echo "Empty groups: $empty_groups" >> "$perf_report"
            echo "" >> "$perf_report"
            
            if [[ $large_groups -gt 0 ]]; then
                echo "💡 OPTIMIZATION: Large groups detected" >> "$perf_report"
                echo "   Action: Consider splitting large groups for better performance" >> "$perf_report"
                echo "   Benefit: Faster message delivery, easier management" >> "$perf_report"
                log_advisor "$large_groups large groups may impact performance" "RECOMMENDATION"
            fi
            
            if [[ $empty_groups -gt 0 ]]; then
                echo "💡 CLEANUP: $empty_groups empty groups found" >> "$perf_report"
                echo "   Action: Review and delete unused groups" >> "$perf_report"
                echo "   Benefit: Cleaner administration, reduced clutter" >> "$perf_report"
                log_advisor "$empty_groups empty groups should be cleaned up" "RECOMMENDATION"
            fi
            
            rm -f "$temp_groups"
        fi
    fi
    
    # Storage optimization
    echo "" >> "$perf_report"
    echo "STORAGE OPTIMIZATION:" >> "$perf_report"
    echo "====================" >> "$perf_report"
    echo "" >> "$perf_report"
    echo "1. REGULAR CLEANUP PROCEDURES:" >> "$perf_report"
    echo "   ✓ Monthly review of large files (>100MB)" >> "$perf_report"
    echo "   ✓ Quarterly cleanup of old/unused files" >> "$perf_report"
    echo "   ✓ Annual archive of historical data" >> "$perf_report"
    echo "" >> "$perf_report"
    echo "2. SHARING OPTIMIZATION:" >> "$perf_report"
    echo "   ✓ Use shared drives instead of individual sharing" >> "$perf_report"
    echo "   ✓ Organize files in logical folder structures" >> "$perf_report"
    echo "   ✓ Regular review of sharing permissions" >> "$perf_report"
    echo "" >> "$perf_report"
    echo "3. QUOTA MANAGEMENT:" >> "$perf_report"
    echo "   ✓ Set appropriate quotas based on user roles" >> "$perf_report"
    echo "   ✓ Monitor quota usage trends" >> "$perf_report"
    echo "   ✓ Implement alerts for high usage" >> "$perf_report"
    
    # Workflow optimization
    echo "" >> "$perf_report"
    echo "WORKFLOW OPTIMIZATION:" >> "$perf_report"
    echo "=====================" >> "$perf_report"
    echo "" >> "$perf_report"
    echo "1. AUTOMATION OPPORTUNITIES:" >> "$perf_report"
    echo "   ✓ Automated user provisioning/deprovisioning" >> "$perf_report"
    echo "   ✓ Scheduled maintenance tasks" >> "$perf_report"
    echo "   ✓ Automated reporting and monitoring" >> "$perf_report"
    echo "" >> "$perf_report"
    echo "2. GWOMBAT OPTIMIZATION:" >> "$perf_report"
    echo "   ✓ Regular database maintenance" >> "$perf_report"
    echo "   ✓ Log file rotation and cleanup" >> "$perf_report"
    echo "   ✓ Performance monitoring" >> "$perf_report"
    
    echo "Performance analysis saved to: $perf_report"
    return 0
}

# Compliance and governance recommendations
analyze_compliance_governance() {
    log_advisor "Analyzing compliance and governance requirements"
    
    local compliance_report="$REPORTS_DIR/compliance_recommendations.txt"
    
    echo "GWOMBAT Compliance & Governance Recommendations" > "$compliance_report"
    echo "=============================================" >> "$compliance_report"
    echo "Date: $(date)" >> "$compliance_report"
    echo "" >> "$compliance_report"
    
    # Data governance
    echo "DATA GOVERNANCE FRAMEWORK:" >> "$compliance_report"
    echo "=========================" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "1. DATA CLASSIFICATION:" >> "$compliance_report"
    echo "   ✓ Implement data classification scheme (Public, Internal, Confidential)" >> "$compliance_report"
    echo "   ✓ Use labels and metadata for automatic classification" >> "$compliance_report"
    echo "   ✓ Train users on proper data handling" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "2. ACCESS CONTROLS:" >> "$compliance_report"
    echo "   ✓ Principle of least privilege" >> "$compliance_report"
    echo "   ✓ Regular access reviews (quarterly)" >> "$compliance_report"
    echo "   ✓ Segregation of duties for sensitive operations" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "3. RETENTION POLICIES:" >> "$compliance_report"
    echo "   ✓ Define retention schedules by data type" >> "$compliance_report"
    echo "   ✓ Automated deletion of expired data" >> "$compliance_report"
    echo "   ✓ Legal hold procedures for litigation" >> "$compliance_report"
    
    # Audit and monitoring
    echo "" >> "$compliance_report"
    echo "AUDIT & MONITORING:" >> "$compliance_report"
    echo "==================" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "1. LOGGING REQUIREMENTS:" >> "$compliance_report"
    echo "   ✓ Admin activity logging (enabled by default)" >> "$compliance_report"
    echo "   ✓ User access logging" >> "$compliance_report"
    echo "   ✓ Data access and modification logs" >> "$compliance_report"
    echo "   ✓ Log retention for 7+ years (compliance requirement)" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "2. REGULAR AUDITS:" >> "$compliance_report"
    echo "   ✓ Monthly security posture reviews" >> "$compliance_report"
    echo "   ✓ Quarterly access certification" >> "$compliance_report"
    echo "   ✓ Annual comprehensive compliance assessment" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "3. INCIDENT RESPONSE:" >> "$compliance_report"
    echo "   ✓ Defined incident response procedures" >> "$compliance_report"
    echo "   ✓ Breach notification processes" >> "$compliance_report"
    echo "   ✓ Forensic data collection capabilities" >> "$compliance_report"
    
    # Specific compliance frameworks
    echo "" >> "$compliance_report"
    echo "COMPLIANCE FRAMEWORKS:" >> "$compliance_report"
    echo "=====================" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "1. FERPA (Educational Records):" >> "$compliance_report"
    echo "   ✓ Restrict access to educational records" >> "$compliance_report"
    echo "   ✓ Audit trails for record access" >> "$compliance_report"
    echo "   ✓ Student consent management" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "2. HIPAA (Healthcare Data):" >> "$compliance_report"
    echo "   ✓ Encryption of PHI data at rest and in transit" >> "$compliance_report"
    echo "   ✓ Access controls and audit logs" >> "$compliance_report"
    echo "   ✓ Business associate agreements" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "3. GDPR (EU Data Protection):" >> "$compliance_report"
    echo "   ✓ Lawful basis for data processing" >> "$compliance_report"
    echo "   ✓ Data subject rights (access, deletion, portability)" >> "$compliance_report"
    echo "   ✓ Privacy impact assessments" >> "$compliance_report"
    echo "" >> "$compliance_report"
    echo "4. SOX (Financial Controls):" >> "$compliance_report"
    echo "   ✓ Segregation of duties in financial systems" >> "$compliance_report"
    echo "   ✓ Change management controls" >> "$compliance_report"
    echo "   ✓ Regular control testing" >> "$compliance_report"
    
    echo "Compliance analysis saved to: $compliance_report"
    return 0
}

# Generate comprehensive recommendations summary
generate_summary_report() {
    log_advisor "Generating comprehensive best practices summary"
    
    local summary_report="$REPORTS_DIR/BEST_PRACTICES_SUMMARY.md"
    
    cat > "$summary_report" << EOF
# GWOMBAT Best Practices Summary Report

**Generated:** $(date)  
**Domain:** $DOMAIN  
**Report Directory:** $REPORTS_DIR

## Executive Summary

This report provides comprehensive best practices recommendations for Google Workspace management using GWOMBAT. The recommendations are categorized by priority and impact to help organizations optimize their deployment.

## Quick Action Items

### 🔴 Critical Priority
- [ ] Enable 2FA enforcement domain-wide
- [ ] Review users over 95% storage quota
- [ ] Audit admin account privileges
- [ ] Implement data classification scheme

### 🟡 High Priority  
- [ ] Set up automated external sharing audits
- [ ] Configure storage quota alerts
- [ ] Implement regular access reviews
- [ ] Establish incident response procedures

### 🟢 Medium Priority
- [ ] Optimize large group management
- [ ] Clean up empty/unused groups
- [ ] Implement automated cleanup procedures
- [ ] Enhance monitoring and reporting

## Detailed Analysis Reports

1. **Storage Analysis:** \`storage_analysis.txt\`
   - Quota usage patterns
   - Storage optimization opportunities
   - Capacity planning recommendations

2. **Security Analysis:** \`security_recommendations.txt\`
   - 2FA compliance status
   - Admin account security
   - External sharing risks

3. **Performance Analysis:** \`performance_recommendations.txt\`
   - Group management optimization
   - Workflow automation opportunities
   - System performance tuning

4. **Compliance Analysis:** \`compliance_recommendations.txt\`
   - Governance framework
   - Regulatory compliance (FERPA, HIPAA, GDPR, SOX)
   - Audit and monitoring requirements

## Implementation Timeline

### Month 1: Security Fundamentals
- Enable 2FA enforcement
- Audit admin accounts
- Implement basic monitoring

### Month 2: Storage Optimization
- Configure quota management
- Implement cleanup procedures
- Set up automated alerts

### Month 3: Governance & Compliance
- Establish data classification
- Implement access review processes
- Document policies and procedures

### Ongoing: Monitoring & Maintenance
- Monthly security reviews
- Quarterly access certifications
- Annual compliance assessments

## GWOMBAT Integration

These recommendations integrate with GWOMBAT's existing capabilities:

- **Database Tracking:** Use GWOMBAT's SQLite database for audit trails
- **Automated Workflows:** Leverage GWOMBAT's batch processing for cleanup
- **Reporting:** Utilize GWOMBAT's reporting tools for ongoing monitoring
- **Backup Integration:** Implement recommendations using GWOMBAT's backup tools

## Next Steps

1. Review detailed analysis reports
2. Prioritize recommendations based on organizational needs
3. Develop implementation timeline
4. Assign responsibilities to appropriate teams
5. Set up regular review processes

## Support Resources

- GWOMBAT Documentation: \`GWOMBAT_ROOT/CLAUDE.md\`
- Setup Wizard: \`./setup_wizard.sh\`
- Configuration: \`./gwombat.sh → Configuration\`
- Forms Integration: \`./shared-utilities/google_forms_integration.sh\`

For questions or assistance, refer to the GWOMBAT parking lot for future enhancements: \`parkinglot.md\`
EOF

    log_advisor "Summary report generated: $summary_report" "SUCCESS"
    return 0
}

# Main dashboard
show_best_practices_dashboard() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    GWOMBAT Best Practices Advisor                            ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Generate recommendations for optimal Google Workspace management"
    echo ""
    echo "Analysis Options:"
    echo "1. 💾 Storage & Quota Analysis"
    echo "2. 🔐 Security Best Practices Review"
    echo "3. ⚡ Performance Optimization"
    echo "4. 📋 Compliance & Governance"
    echo "5. 📊 Comprehensive Analysis (All)"
    echo "6. 📈 View Previous Reports"
    echo "7. 🏠 Return to Main Menu"
    echo ""
    
    read -p "Select analysis type (1-7): " choice
    echo ""
    
    case $choice in
        1)
            analyze_storage_quotas
            ;;
        2)
            analyze_security_practices
            ;;
        3)
            analyze_performance_optimization
            ;;
        4)
            analyze_compliance_governance
            ;;
        5)
            log_advisor "Running comprehensive best practices analysis"
            analyze_storage_quotas
            analyze_security_practices
            analyze_performance_optimization
            analyze_compliance_governance
            generate_summary_report
            echo ""
            echo -e "${GREEN}✅ Comprehensive analysis complete!${NC}"
            echo "Reports available in: $REPORTS_DIR"
            ;;
        6)
            echo -e "${CYAN}Previous Reports:${NC}"
            ls -la "$GWOMBAT_ROOT/reports/" | grep "best-practices" | tail -10
            ;;
        7)
            return 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            sleep 2
            show_best_practices_dashboard
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    show_best_practices_dashboard
}

# Script execution
case "${1:-}" in
    "dashboard"|"")
        show_best_practices_dashboard
        ;;
    "storage")
        analyze_storage_quotas
        ;;
    "security")
        analyze_security_practices
        ;;
    "performance")
        analyze_performance_optimization
        ;;
    "compliance")
        analyze_compliance_governance
        ;;
    "full"|"comprehensive")
        analyze_storage_quotas
        analyze_security_practices
        analyze_performance_optimization
        analyze_compliance_governance
        generate_summary_report
        echo -e "${GREEN}✅ Comprehensive analysis complete!${NC}"
        echo "Reports available in: $REPORTS_DIR"
        ;;
    *)
        echo "GWOMBAT Best Practices Advisor"
        echo "Usage: $0 [dashboard|storage|security|performance|compliance|full]"
        echo ""
        echo "Commands:"
        echo "  dashboard     - Interactive dashboard (default)"
        echo "  storage       - Storage and quota analysis"
        echo "  security      - Security best practices review"
        echo "  performance   - Performance optimization analysis"
        echo "  compliance    - Compliance and governance review"
        echo "  full          - Comprehensive analysis (all categories)"
        echo ""
        exit 1
        ;;
esac