#!/bin/bash

# SCuBA Compliance Bridge for GWOMBAT
# Hybrid Architecture: Bash-Python Integration for SCuBA Compliance Module

# Load configuration from .env if available
if [[ -f "../.env" ]]; then
    source ../.env
fi

# Configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"
PYTHON_MODULES_PATH="./python-modules"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_DIR="$(dirname "$SCRIPT_DIR")"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Database helper function
execute_db() {
    sqlite3 "$DB_PATH" "$1" 2>/dev/null || echo ""
}

# Logging function
log_scuba() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    execute_db "
    INSERT INTO system_logs (log_level, session_id, operation, message, source_file)
    VALUES ('$level', '$SESSION_ID', 'scuba_compliance', '$message', 'scuba_compliance_bridge.sh');
    " >/dev/null 2>&1
}

# Check if Python modules are available and functional
check_python_environment() {
    echo -e "${CYAN}Checking Python environment for SCuBA compliance...${NC}"
    
    # Check if Python 3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        echo -e "${RED}✗ Python 3 not found${NC}"
        echo "Python 3 is required for SCuBA compliance features"
        return 1
    fi
    
    local python_version=$(python3 --version 2>&1)
    echo "Python version: $python_version"
    
    # Check if GWOMBAT Python modules directory exists
    if [[ ! -d "$GWOMBAT_DIR/$PYTHON_MODULES_PATH" ]]; then
        echo -e "${RED}✗ Python modules directory not found: $PYTHON_MODULES_PATH${NC}"
        return 1
    fi
    
    # Check if main SCuBA module exists
    if [[ ! -f "$GWOMBAT_DIR/$PYTHON_MODULES_PATH/scuba_compliance.py" ]]; then
        echo -e "${RED}✗ SCuBA compliance module not found${NC}"
        return 1
    fi
    
    # Test import of SCuBA module
    cd "$GWOMBAT_DIR" || return 1
    
    if python3 -c "
import sys
sys.path.insert(0, '$PYTHON_MODULES_PATH')
try:
    from scuba_compliance import ScubaCompliance
    print('✓ SCuBA compliance module imported successfully')
    exit(0)
except ImportError as e:
    print(f'✗ Import error: {e}')
    exit(1)
except Exception as e:
    print(f'✗ Module error: {e}')
    exit(1)
" 2>/dev/null; then
        echo -e "${GREEN}✓ Python environment ready for SCuBA compliance${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Python modules available but some dependencies may be missing${NC}"
        echo "Run 'pip3 install -r python-modules/requirements.txt' to install dependencies"
        return 2
    fi
}

# Install Python dependencies
install_python_dependencies() {
    echo -e "${CYAN}Installing Python dependencies for SCuBA compliance...${NC}"
    
    cd "$GWOMBAT_DIR" || return 1
    
    if [[ -f "$PYTHON_MODULES_PATH/requirements.txt" ]]; then
        echo "Installing requirements from $PYTHON_MODULES_PATH/requirements.txt"
        
        if python3 -m pip install -r "$PYTHON_MODULES_PATH/requirements.txt"; then
            echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
            log_scuba "Python dependencies installed successfully" "INFO"
            return 0
        else
            echo -e "${RED}✗ Failed to install Python dependencies${NC}"
            echo "You may need to install them manually:"
            echo "  pip3 install -r python-modules/requirements.txt"
            return 1
        fi
    else
        echo -e "${YELLOW}Requirements file not found${NC}"
        return 1
    fi
}

# Check if SCuBA compliance is enabled in configuration
is_scuba_enabled() {
    if [[ -x "$SCRIPT_DIR/config_manager.sh" ]]; then
        "$SCRIPT_DIR/config_manager.sh" get "scuba" "compliance_enabled" "false" 2>/dev/null
    else
        echo "false"
    fi
}

# Enable/disable SCuBA compliance
toggle_scuba_compliance() {
    local enable="$1" # true/false
    
    if [[ -x "$SCRIPT_DIR/config_manager.sh" ]]; then
        "$SCRIPT_DIR/config_manager.sh" set "scuba" "compliance_enabled" "$enable" "$USER" "SCuBA compliance toggled via bridge"
        
        if [[ "$enable" == "true" ]]; then
            echo -e "${GREEN}✓ SCuBA compliance enabled${NC}"
            log_scuba "SCuBA compliance enabled" "INFO"
        else
            echo -e "${YELLOW}SCuBA compliance disabled${NC}"
            log_scuba "SCuBA compliance disabled" "INFO"
        fi
    else
        echo -e "${RED}Configuration manager not available${NC}"
        return 1
    fi
}

# Run SCuBA compliance assessment
run_scuba_assessment() {
    local services="$1"
    local output_format="${2:-table}"
    
    echo -e "${CYAN}Running SCuBA compliance assessment...${NC}"
    
    # Check if enabled
    if [[ "$(is_scuba_enabled)" == "false" ]]; then
        echo -e "${YELLOW}SCuBA compliance is disabled${NC}"
        echo "Enable it in Configuration Management to run assessments"
        return 1
    fi
    
    # Check Python environment
    if ! check_python_environment >/dev/null 2>&1; then
        echo -e "${RED}Python environment not ready for SCuBA compliance${NC}"
        echo "Run 'setup-python' to configure the environment"
        return 1
    fi
    
    cd "$GWOMBAT_DIR" || return 1
    
    # Build command
    local cmd="python3 -m python-modules.scuba_compliance"
    cmd="$cmd --db-path '$DB_PATH'"
    
    if [[ -n "$GAM_PATH" ]]; then
        cmd="$cmd --gam-path '$GAM_PATH'"
    fi
    
    if [[ -n "$services" ]]; then
        cmd="$cmd --services $services"
    fi
    
    cmd="$cmd --output $output_format"
    
    echo "Executing: $cmd"
    log_scuba "Starting SCuBA assessment: $cmd" "INFO"
    
    # Execute assessment
    if eval "$cmd"; then
        echo -e "${GREEN}✓ SCuBA assessment completed successfully${NC}"
        log_scuba "SCuBA assessment completed successfully" "INFO"
        return 0
    else
        echo -e "${RED}✗ SCuBA assessment failed${NC}"
        log_scuba "SCuBA assessment failed" "ERROR"
        return 1
    fi
}

# Show SCuBA compliance dashboard
show_scuba_dashboard() {
    echo -e "${CYAN}Loading SCuBA compliance dashboard...${NC}"
    
    # Check if enabled
    if [[ "$(is_scuba_enabled)" == "false" ]]; then
        echo -e "${YELLOW}SCuBA compliance is disabled${NC}"
        echo "Enable it in Configuration Management to view dashboard"
        return 1
    fi
    
    cd "$GWOMBAT_DIR" || return 1
    
    # Run dashboard
    if python3 -m python-modules.compliance_dashboard --db-path "$DB_PATH" --action dashboard; then
        log_scuba "SCuBA dashboard displayed" "INFO"
        return 0
    else
        echo -e "${RED}✗ Failed to display SCuBA dashboard${NC}"
        echo "This may indicate missing Python dependencies or database issues"
        return 1
    fi
}

# Export SCuBA compliance report
export_scuba_report() {
    local output_path="$1"
    local format="${2:-json}"
    
    echo -e "${CYAN}Exporting SCuBA compliance report...${NC}"
    
    if [[ -z "$output_path" ]]; then
        output_path="./reports/scuba_compliance_$(date +%Y%m%d_%H%M%S).json"
    fi
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$output_path")"
    
    cd "$GWOMBAT_DIR" || return 1
    
    if python3 -m python-modules.compliance_dashboard --db-path "$DB_PATH" --action export --output "$output_path" --format "$format"; then
        echo -e "${GREEN}✓ SCuBA compliance report exported to: $output_path${NC}"
        log_scuba "SCuBA report exported to $output_path" "INFO"
        return 0
    else
        echo -e "${RED}✗ Failed to export SCuBA compliance report${NC}"
        return 1
    fi
}

# Show SCuBA compliance status summary
show_scuba_status() {
    echo -e "${CYAN}📊 SCuBA Compliance Status${NC}"
    echo ""
    
    # Check if enabled
    local enabled=$(is_scuba_enabled)
    echo -e "SCuBA Compliance: $([ "$enabled" == "true" ] && echo "${GREEN}ENABLED${NC}" || echo "${RED}DISABLED${NC}")"
    
    # Check Python environment
    if check_python_environment >/dev/null 2>&1; then
        echo -e "Python Environment: ${GREEN}READY${NC}"
    else
        echo -e "Python Environment: ${RED}NOT READY${NC}"
        echo "  Run 'setup-python' to configure"
    fi
    
    # Check database
    if [[ -f "$DB_PATH" ]]; then
        local baseline_count=$(execute_db "SELECT COUNT(*) FROM scuba_baselines WHERE is_enabled = 1;" 2>/dev/null || echo "0")
        echo "Enabled Baselines: $baseline_count"
        
        local last_assessment=$(execute_db "SELECT MAX(assessment_start) FROM scuba_assessment_history;" 2>/dev/null || echo "")
        if [[ -n "$last_assessment" && "$last_assessment" != "" ]]; then
            echo "Last Assessment: $last_assessment"
        else
            echo "Last Assessment: Never"
        fi
    else
        echo -e "Database: ${RED}NOT FOUND${NC}"
    fi
    
    echo ""
    
    # Show recent assessment summary if available
    if [[ "$enabled" == "true" ]] && [[ -f "$DB_PATH" ]]; then
        echo -e "${CYAN}Recent Assessment Summary:${NC}"
        
        local summary=$(execute_db "
        SELECT 
            overall_compliance_percentage,
            critical_findings,
            baselines_assessed,
            assessment_start
        FROM scuba_assessment_history 
        ORDER BY assessment_start DESC 
        LIMIT 1;" 2>/dev/null)
        
        if [[ -n "$summary" && "$summary" != "" ]]; then
            echo "$summary" | while IFS='|' read -r compliance critical baselines date; do
                echo "  Compliance: ${compliance}%"
                echo "  Critical Findings: $critical"
                echo "  Baselines Assessed: $baselines"
                echo "  Date: $date"
            done
        else
            echo "  No assessment data available"
        fi
    fi
}

# SCuBA compliance management menu
show_scuba_menu() {
    while true; do
        clear
        echo -e "${BLUE}=== 🔐 SCuBA Compliance Management ===${NC}"
        echo ""
        
        # Show current status
        local enabled=$(is_scuba_enabled)
        local status_color="$RED"
        local status_text="DISABLED"
        if [[ "$enabled" == "true" ]]; then
            status_color="$GREEN"
            status_text="ENABLED"
        fi
        echo -e "${CYAN}Current Status:${NC} ${status_color}$status_text${NC}"
        echo ""
        
        echo -e "${GREEN}=== COMPLIANCE OPERATIONS ===${NC}"
        echo "1. 📊 View Compliance Dashboard"
        echo "2. 🔍 Run Full Compliance Assessment"
        echo "3. 📋 Run Service-Specific Assessment"
        echo "4. 📄 Export Compliance Report"
        echo "5. 📈 View Assessment History"
        echo ""
        echo -e "${YELLOW}=== CONFIGURATION ===${NC}"
        echo "6. ⚙️  Enable/Disable SCuBA Compliance"
        echo "7. 🐍 Setup Python Environment"
        echo "8. 🔧 Check System Status"
        echo "9. 📚 View Baseline Management"
        echo ""
        echo -e "${PURPLE}=== INFORMATION ===${NC}"
        echo "10. ℹ️  About SCuBA Compliance"
        echo "11. 📖 View Documentation"
        echo ""
        echo "12. ↩️  Return to main menu"
        echo "m. Main menu"
        echo "x. Exit"
        echo ""
        read -p "Select an option (1-12, m, x): " scuba_choice
        echo ""
        
        case $scuba_choice in
            1) show_scuba_dashboard; read -p "Press Enter to continue..." ;;
            2) run_scuba_assessment ""; read -p "Press Enter to continue..." ;;
            3) 
                echo "Available services: gmail, calendar, drive, meet, chat, groups, classroom, sites, common_controls"
                read -p "Enter services to assess (space-separated): " services
                run_scuba_assessment "$services"
                read -p "Press Enter to continue..."
                ;;
            4) 
                read -p "Enter output path (or press Enter for default): " output_path
                export_scuba_report "$output_path"
                read -p "Press Enter to continue..."
                ;;
            5) show_assessment_history; read -p "Press Enter to continue..." ;;
            6) toggle_scuba_settings_menu ;;
            7) 
                install_python_dependencies
                read -p "Press Enter to continue..."
                ;;
            8) show_scuba_status; read -p "Press Enter to continue..." ;;
            9) show_baseline_management_menu ;;
            10) show_scuba_about; read -p "Press Enter to continue..." ;;
            11) show_scuba_documentation; read -p "Press Enter to continue..." ;;
            12|m|M) return ;;
            x|X) echo -e "${BLUE}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Please select 1-12, m, or x.${NC}"; read -p "Press Enter to continue..." ;;
        esac
    done
}

# Toggle SCuBA settings submenu
toggle_scuba_settings_menu() {
    echo -e "${CYAN}⚙️ SCuBA Compliance Settings${NC}"
    echo ""
    
    local enabled=$(is_scuba_enabled)
    echo "Current Status: $([ "$enabled" == "true" ] && echo "${GREEN}ENABLED${NC}" || echo "${RED}DISABLED${NC}")"
    echo ""
    echo "1. Enable SCuBA compliance"
    echo "2. Disable SCuBA compliance"
    echo "3. Return to SCuBA menu"
    echo ""
    read -p "Select option (1-3): " choice
    
    case $choice in
        1) toggle_scuba_compliance "true" ;;
        2) toggle_scuba_compliance "false" ;;
        3) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
}

# Show assessment history
show_assessment_history() {
    echo -e "${CYAN}📈 SCuBA Assessment History${NC}"
    echo ""
    
    local history=$(execute_db "
    SELECT 
        assessment_start,
        assessment_type,
        overall_compliance_percentage,
        baselines_assessed,
        critical_findings
    FROM scuba_assessment_history 
    ORDER BY assessment_start DESC 
    LIMIT 10;
    ")
    
    if [[ -n "$history" && "$history" != "" ]]; then
        printf "%-19s %-10s %-11s %-10s %-8s\n" "Date" "Type" "Compliance%" "Baselines" "Critical"
        echo "---------------------------------------------------------------"
        echo "$history" | while IFS='|' read -r date type compliance baselines critical; do
            printf "%-19s %-10s %-11s %-10s %-8s\n" "$date" "$type" "${compliance}%" "$baselines" "$critical"
        done
    else
        echo "No assessment history available"
    fi
}

# Show information about SCuBA
show_scuba_about() {
    echo -e "${CYAN}ℹ️ About SCuBA Compliance${NC}"
    echo ""
    echo "CISA Secure Cloud Business Applications (SCuBA) Security Baselines"
    echo "=================================================================="
    echo ""
    echo "SCuBA provides security baseline guidance for Google Workspace"
    echo "environments, developed by the Cybersecurity and Infrastructure"
    echo "Security Agency (CISA)."
    echo ""
    echo "GWOMBAT's SCuBA compliance module implements automated checking"
    echo "of these security baselines across 9 Google Workspace services:"
    echo ""
    echo "• Gmail - Email security settings and policies"
    echo "• Calendar - Calendar sharing and access controls"
    echo "• Drive & Docs - File sharing and collaboration settings"
    echo "• Google Meet - Meeting security and recording controls"
    echo "• Google Chat - Chat and messaging security"
    echo "• Groups for Business - Group membership and access"
    echo "• Google Classroom - Educational environment security"
    echo "• Google Sites - Website publishing controls"
    echo "• Common Controls - Cross-service security settings"
    echo ""
    echo "Features:"
    echo "• Automated compliance checking via GAM and Google APIs"
    echo "• Gap analysis and remediation tracking"
    echo "• Executive reporting and compliance dashboards"
    echo "• Configurable baseline enablement"
    echo "• Integration with GWOMBAT's scheduling system"
}

# Placeholder for additional functions
show_baseline_management_menu() {
    echo -e "${YELLOW}Baseline management interface - implementation pending${NC}"
}

show_scuba_documentation() {
    echo -e "${YELLOW}SCuBA documentation viewer - implementation pending${NC}"
}

# Command line interface
case "${1:-menu}" in
    "menu")
        show_scuba_menu
        ;;
    "status")
        show_scuba_status
        ;;
    "check-python")
        check_python_environment
        ;;
    "setup-python")
        install_python_dependencies
        ;;
    "enable")
        toggle_scuba_compliance "true"
        ;;
    "disable")
        toggle_scuba_compliance "false"
        ;;
    "assess")
        run_scuba_assessment "$2" "$3"
        ;;
    "dashboard")
        show_scuba_dashboard
        ;;
    "export")
        export_scuba_report "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {menu|status|check-python|setup-python|enable|disable|assess|dashboard|export}"
        echo ""
        echo "Commands:"
        echo "  menu         - Show SCuBA compliance management menu"
        echo "  status       - Show current SCuBA compliance status"
        echo "  check-python - Check Python environment readiness"
        echo "  setup-python - Install Python dependencies"
        echo "  enable       - Enable SCuBA compliance"
        echo "  disable      - Disable SCuBA compliance"
        echo "  assess       - Run compliance assessment"
        echo "  dashboard    - Show compliance dashboard"
        echo "  export       - Export compliance report"
        exit 1
        ;;
esac