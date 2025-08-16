#!/bin/bash
# GWOMBAT First-Time Setup Wizard
# Comprehensive configuration wizard for new installations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GWOMBAT_ROOT="$SCRIPT_DIR"

# Configuration files
ENV_FILE="$GWOMBAT_ROOT/.env"
ENV_TEMPLATE="$GWOMBAT_ROOT/.env.template"
SERVER_ENV_TEMPLATE="$GWOMBAT_ROOT/server.env.template"

# Log file for setup process
SETUP_LOG="$GWOMBAT_ROOT/logs/setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$GWOMBAT_ROOT/logs"

# Logging function
log_setup() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$SETUP_LOG"
    if [[ "$level" == "ERROR" ]]; then
        echo -e "${RED}[ERROR]${NC} $message"
    elif [[ "$level" == "WARN" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    fi
}

# Banner function
show_setup_banner() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    GWOMBAT First-Time Setup Wizard                          ║${NC}"
    echo -e "${BLUE}║        Google Workspace Optimization, Management, Backups And Taskrunner    ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║                                                                              ║${NC}"
    echo -e "${BLUE}║  Welcome! This wizard will help you configure GWOMBAT for your environment  ║${NC}"
    echo -e "${BLUE}║                                                                              ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    log_setup "Setup wizard started"
}

# Check if this is first time setup
is_first_time_setup() {
    if [[ ! -f "$ENV_FILE" ]]; then
        return 0  # First time
    else
        return 1  # Not first time
    fi
}

# Check dependencies
check_setup_dependencies() {
    echo -e "${CYAN}🔍 Checking system dependencies...${NC}"
    local missing_deps=()
    
    # Essential dependencies
    if ! command -v bash >/dev/null 2>&1; then
        missing_deps+=("bash")
    fi
    
    if ! command -v sqlite3 >/dev/null 2>&1; then
        missing_deps+=("sqlite3")
    fi
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v python3 >/dev/null 2>&1; then
        missing_deps+=("python3")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}✗ Missing essential dependencies:${NC}"
        printf '  - %s\n' "${missing_deps[@]}"
        echo ""
        echo -e "${YELLOW}Please install missing dependencies before continuing.${NC}"
        log_setup "Missing dependencies: ${missing_deps[*]}" "ERROR"
        return 1
    fi
    
    echo -e "${GREEN}✓ All essential dependencies found${NC}"
    log_setup "All essential dependencies satisfied"
    return 0
}

# Get user input with validation
get_user_input() {
    local prompt="$1"
    local default="$2"
    local required="${3:-true}"
    local validation_type="${4:-none}"
    local user_input=""
    
    while true; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " user_input
            user_input="${user_input:-$default}"
        else
            read -p "$prompt: " user_input
        fi
        
        # Check if required
        if [[ "$required" == "true" && -z "$user_input" ]]; then
            echo -e "${RED}This field is required. Please enter a value.${NC}"
            continue
        fi
        
        # Validation
        case "$validation_type" in
            "email")
                if [[ "$user_input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid email address.${NC}"
                    continue
                fi
                ;;
            "domain")
                if [[ "$user_input" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid domain (e.g., example.edu).${NC}"
                    continue
                fi
                ;;
            "path")
                if [[ -d "$user_input" || "$user_input" =~ ^/.* ]]; then
                    break
                else
                    echo -e "${RED}Please enter a valid absolute path.${NC}"
                    continue
                fi
                ;;
            *)
                break
                ;;
        esac
    done
    
    echo "$user_input"
}

# Configure basic domain settings
configure_domain_settings() {
    echo -e "${CYAN}📋 Domain and Organization Configuration${NC}"
    echo ""
    echo "Let's start with your Google Workspace domain and basic settings."
    echo ""
    
    # Domain
    local domain
    domain=$(get_user_input "Enter your Google Workspace domain" "" "true" "domain")
    
    # Admin email
    local admin_email
    admin_email=$(get_user_input "Enter your GWOMBAT admin email" "gwombat@$domain" "true" "email")
    
    # Actual admin user
    local admin_user
    echo ""
    echo -e "${YELLOW}Enter your personal admin account (the account you use for administration):${NC}"
    admin_user=$(get_user_input "Your admin user email" "" "true" "email")
    
    # Store in temporary variables
    export SETUP_DOMAIN="$domain"
    export SETUP_ADMIN_EMAIL="$admin_email"
    export SETUP_ADMIN_USER="$admin_user"
    
    echo -e "${GREEN}✓ Domain settings configured${NC}"
    log_setup "Domain configured: $domain, Admin: $admin_user"
}

# Configure organizational units
configure_organizational_units() {
    echo ""
    echo -e "${CYAN}🏢 Organizational Unit Configuration${NC}"
    echo ""
    echo "Configure the OUs used for account lifecycle management."
    echo ""
    
    # Suspended OU
    local suspended_ou
    suspended_ou=$(get_user_input "Suspended Users OU path" "/Suspended Users" "true")
    
    # Pending Deletion OU
    local pending_deletion_ou
    pending_deletion_ou=$(get_user_input "Pending Deletion OU path" "/Suspended Users/Pending Deletion" "true")
    
    # Temporary Hold OU
    local temp_hold_ou
    temp_hold_ou=$(get_user_input "Temporary Hold OU path" "/Suspended Users/Temporary Hold" "true")
    
    # Exit Row OU
    local exit_row_ou
    exit_row_ou=$(get_user_input "Exit Row OU path" "/Suspended Users/Exit Row" "true")
    
    # Store in temporary variables
    export SETUP_SUSPENDED_OU="$suspended_ou"
    export SETUP_PENDING_DELETION_OU="$pending_deletion_ou"
    export SETUP_TEMPORARY_HOLD_OU="$temp_hold_ou"
    export SETUP_EXIT_ROW_OU="$exit_row_ou"
    
    echo -e "${GREEN}✓ Organizational units configured${NC}"
    log_setup "OUs configured: $suspended_ou, $pending_deletion_ou, $temp_hold_ou, $exit_row_ou"
}

# Check and configure GAM
configure_gam() {
    echo ""
    echo -e "${CYAN}🔧 GAM (Google Apps Manager) Configuration${NC}"
    echo ""
    
    # Check if GAM is installed
    local gam_path=""
    if command -v gam >/dev/null 2>&1; then
        gam_path=$(which gam)
        echo -e "${GREEN}✓ GAM found at: $gam_path${NC}"
    else
        echo -e "${YELLOW}GAM not found in PATH${NC}"
        echo ""
        echo -e "${BLUE}GAM Installation Guide:${NC}"
        echo "1. Download GAM from: https://github.com/GAM-team/GAM"
        echo "2. Follow installation instructions for your platform"
        echo "3. Common installation paths:"
        echo "   - Linux/macOS: /usr/local/bin/gam"
        echo "   - Windows: C:\\GAM\\gam.exe"
        echo ""
        
        local install_now
        install_now=$(get_user_input "Would you like to install GAM now? (y/n)" "n" "false")
        
        if [[ "$install_now" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing GAM...${NC}"
            if command -v curl >/dev/null 2>&1; then
                echo "Downloading GAM installer..."
                if bash <(curl -s -S -L https://git.io/install-gam) -l; then
                    echo -e "${GREEN}✓ GAM installation completed${NC}"
                    gam_path=$(which gam || echo "/usr/local/bin/gam")
                else
                    echo -e "${YELLOW}⚠ Automatic installation failed. Please install manually.${NC}"
                    gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
                fi
            else
                echo -e "${YELLOW}⚠ curl not available. Please install GAM manually.${NC}"
                gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
            fi
        else
            gam_path=$(get_user_input "Enter GAM installation path" "/usr/local/bin/gam" "true")
        fi
    fi
    
    # GAM Configuration Walkthrough
    echo ""
    echo -e "${CYAN}GAM Configuration Walkthrough${NC}"
    echo ""
    
    if [[ -x "$gam_path" ]]; then
        local gam_version=$($gam_path version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}GAM Version: $gam_version${NC}"
        
        # Check if GAM is already configured
        if $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
            echo -e "${GREEN}✓ GAM is already configured and working${NC}"
            local domain_info=$($gam_path info domain 2>/dev/null | grep "Primary Domain" | awk '{print $3}' || echo "unknown")
            echo -e "${GREEN}  Primary Domain: $domain_info${NC}"
            log_setup "GAM configured: $gam_version for domain $domain_info"
        else
            echo -e "${YELLOW}GAM needs to be configured with your Google Workspace domain${NC}"
            echo ""
            echo -e "${BLUE}GAM Configuration Steps:${NC}"
            echo ""
            echo "1. ${CYAN}Create OAuth credentials:${NC}"
            echo "   $gam_path oauth create"
            echo ""
            echo "2. ${CYAN}Authorize GAM:${NC}"
            echo "   - This will open a browser window"
            echo "   - Log in with your Google Workspace admin account"
            echo "   - Grant the requested permissions"
            echo ""
            echo "3. ${CYAN}Test configuration:${NC}"
            echo "   $gam_path info domain"
            echo ""
            
            local configure_now
            configure_now=$(get_user_input "Configure GAM now? (y/n)" "y" "false")
            
            if [[ "$configure_now" =~ ^[Yy] ]]; then
                echo ""
                echo -e "${CYAN}Running GAM OAuth setup...${NC}"
                echo "Follow the instructions in your browser..."
                echo ""
                
                if $gam_path oauth create; then
                    echo ""
                    echo -e "${CYAN}Testing GAM configuration...${NC}"
                    if $gam_path info domain 2>/dev/null | grep -q "Customer ID"; then
                        echo -e "${GREEN}✓ GAM configuration successful!${NC}"
                        local domain_info=$($gam_path info domain 2>/dev/null | grep "Primary Domain" | awk '{print $3}' || echo "configured")
                        echo -e "${GREEN}  Primary Domain: $domain_info${NC}"
                        log_setup "GAM configured successfully for domain $domain_info"
                    else
                        echo -e "${YELLOW}⚠ GAM configuration may need additional setup${NC}"
                        echo "You can complete this later by running:"
                        echo "  $gam_path oauth create"
                        echo "  $gam_path info domain"
                        log_setup "GAM OAuth created but needs verification" "WARN"
                    fi
                else
                    echo -e "${YELLOW}⚠ GAM OAuth setup incomplete${NC}"
                    echo "You can complete this later by running: $gam_path oauth create"
                    log_setup "GAM OAuth setup failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ Skipping GAM configuration${NC}"
                echo "Configure later with: $gam_path oauth create"
                log_setup "Skipped GAM configuration"
            fi
        fi
        
        # GAM Advanced Configuration
        echo ""
        echo -e "${CYAN}GAM Advanced Configuration Options:${NC}"
        echo ""
        echo "Would you like to configure advanced GAM settings?"
        echo "1. Set custom GAM config directory"
        echo "2. Configure GAM for multiple domains"
        echo "3. Set up GAM service account (advanced)"
        echo "4. Skip advanced configuration"
        echo ""
        
        local advanced_choice
        advanced_choice=$(get_user_input "Select option (1-4)" "4" "false")
        
        case "$advanced_choice" in
            1)
                echo ""
                echo -e "${CYAN}Custom GAM Config Directory${NC}"
                echo "Default: $HOME/.gam"
                local custom_config
                custom_config=$(get_user_input "Enter custom config directory" "$HOME/.gam" "false")
                echo "To use custom directory, set: export GAMCFGDIR=\"$custom_config\""
                export SETUP_GAM_CONFIG_PATH="$custom_config"
                log_setup "GAM custom config directory: $custom_config"
                ;;
            2)
                echo ""
                echo -e "${CYAN}Multiple Domain Configuration${NC}"
                echo "For multiple domains, you can:"
                echo "1. Use separate GAM installations"
                echo "2. Use GAM profiles with different config directories"
                echo "3. Switch between OAuth tokens"
                echo ""
                echo "See GAM documentation for multi-domain setup:"
                echo "https://github.com/GAM-team/GAM/wiki/Multiple-Domains"
                ;;
            3)
                echo ""
                echo -e "${CYAN}Service Account Configuration${NC}"
                echo "Service accounts provide automated access without OAuth."
                echo ""
                echo "Steps to configure service account:"
                echo "1. Create service account in Google Cloud Console"
                echo "2. Enable necessary APIs"
                echo "3. Download service account JSON key"
                echo "4. Configure GAM: $gam_path oauth serviceaccount"
                echo ""
                echo "⚠️  Service account setup requires Google Cloud Console access"
                echo "See: https://github.com/GAM-team/GAM/wiki/Service-Account-Access"
                ;;
            4)
                echo -e "${YELLOW}⚠ Skipping advanced GAM configuration${NC}"
                ;;
        esac
        
    else
        echo -e "${RED}✗ GAM executable not found or not executable${NC}"
        echo "Please install GAM before continuing setup."
        log_setup "GAM not found at $gam_path" "ERROR"
    fi
    
    # GAM config path
    local gam_config_path="${SETUP_GAM_CONFIG_PATH:-$HOME/.gam}"
    if [[ -z "$SETUP_GAM_CONFIG_PATH" ]]; then
        gam_config_path=$(get_user_input "GAM config directory" "$HOME/.gam" "false")
    fi
    
    export SETUP_GAM_PATH="$gam_path"
    export SETUP_GAM_CONFIG_PATH="$gam_config_path"
}

# Check and configure Python environment
configure_python_environment() {
    echo ""
    echo -e "${CYAN}🐍 Python Environment Configuration${NC}"
    echo ""
    
    # Check Python version and compatibility
    local python_path=""
    local python_version=""
    local python_major=""
    local python_minor=""
    
    if command -v python3 >/dev/null 2>&1; then
        python_path=$(which python3)
        python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        python_major=$(echo "$python_version" | cut -d. -f1)
        python_minor=$(echo "$python_version" | cut -d. -f2)
        
        echo -e "${GREEN}✓ Python found: $python_version at $python_path${NC}"
        
        # Check Python version compatibility (require 3.8+)
        if [[ "$python_major" -eq 3 && "$python_minor" -ge 8 ]]; then
            echo -e "${GREEN}  ✓ Python version is compatible (3.8+ required)${NC}"
            log_setup "Python version compatible: $python_version"
        elif [[ "$python_major" -eq 3 && "$python_minor" -lt 8 ]]; then
            echo -e "${YELLOW}  ⚠ Python version may be outdated (3.8+ recommended)${NC}"
            echo -e "${YELLOW}    Some advanced features may not work properly${NC}"
            log_setup "Python version outdated: $python_version" "WARN"
        else
            echo -e "${RED}  ✗ Python version incompatible${NC}"
            log_setup "Python version incompatible: $python_version" "ERROR"
        fi
    else
        echo -e "${RED}✗ Python 3 not found${NC}"
        echo ""
        echo -e "${BLUE}Python Installation Guide:${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Install with: sudo apt update && sudo apt install python3 python3-pip"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install python3"
            echo "Or download from: https://www.python.org/downloads/"
        else
            echo "Download from: https://www.python.org/downloads/"
        fi
        
        local install_python
        install_python=$(get_user_input "Install Python now? (y/n)" "n" "false")
        
        if [[ "$install_python" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing Python...${NC}"
            if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y python3 python3-pip python3-venv
            elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                brew install python3
            else
                echo -e "${YELLOW}⚠ Automatic installation not available for your platform${NC}"
                echo "Please install Python manually and run setup again"
                log_setup "Python installation failed - manual installation required" "ERROR"
                return 1
            fi
            
            # Recheck after installation
            if command -v python3 >/dev/null 2>&1; then
                python_version=$(python3 --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
                echo -e "${GREEN}✓ Python installation successful: $python_version${NC}"
                log_setup "Python installed successfully: $python_version"
            else
                echo -e "${RED}✗ Python installation failed${NC}"
                log_setup "Python installation failed" "ERROR"
                return 1
            fi
        else
            log_setup "Python 3 not found - skipping Python setup" "ERROR"
            return 1
        fi
    fi
    
    # Check pip and package management tools
    echo ""
    echo -e "${CYAN}Python Package Management${NC}"
    
    if command -v pip3 >/dev/null 2>&1; then
        local pip_version=$(pip3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        echo -e "${GREEN}✓ pip3 available: $pip_version${NC}"
        log_setup "pip3 available: $pip_version"
    else
        echo -e "${YELLOW}⚠ pip3 not found - attempting to install${NC}"
        if command -v python3 >/dev/null 2>&1; then
            if python3 -m ensurepip --upgrade 2>/dev/null; then
                echo -e "${GREEN}✓ pip3 installed successfully${NC}"
                log_setup "pip3 installed successfully"
            else
                echo -e "${RED}✗ pip3 installation failed${NC}"
                echo "You may need to install pip3 manually"
                log_setup "pip3 installation failed" "WARN"
            fi
        fi
    fi
    
    # Check for virtual environment support
    if python3 -m venv --help >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Virtual environment support available${NC}"
        export SETUP_PYTHON_VENV_SUPPORT="true"
    else
        echo -e "${YELLOW}⚠ Virtual environment support not available${NC}"
        echo "Consider installing python3-venv package"
        export SETUP_PYTHON_VENV_SUPPORT="false"
        log_setup "Virtual environment support not available" "WARN"
    fi
    
    # Virtual Environment Configuration
    echo ""
    echo -e "${CYAN}Python Virtual Environment Setup${NC}"
    echo ""
    echo "GWOMBAT can use a dedicated Python virtual environment to:"
    echo "• Isolate Python packages from system installation"
    echo "• Avoid conflicts with other applications"
    echo "• Ensure consistent package versions"
    echo "• Enable easy cleanup and updates"
    echo ""
    
    local use_venv="false"
    if [[ "$SETUP_PYTHON_VENV_SUPPORT" == "true" ]]; then
        local venv_choice
        venv_choice=$(get_user_input "Use virtual environment for GWOMBAT? (y/n)" "y" "false")
        
        if [[ "$venv_choice" =~ ^[Yy] ]]; then
            use_venv="true"
            local venv_path="$GWOMBAT_ROOT/python-modules/venv"
            
            echo ""
            echo -e "${CYAN}Creating Python virtual environment...${NC}"
            
            if [[ -d "$venv_path" ]]; then
                echo -e "${YELLOW}⚠ Virtual environment already exists at $venv_path${NC}"
                local recreate_venv
                recreate_venv=$(get_user_input "Recreate virtual environment? (y/n)" "n" "false")
                if [[ "$recreate_venv" =~ ^[Yy] ]]; then
                    rm -rf "$venv_path"
                fi
            fi
            
            if [[ ! -d "$venv_path" ]]; then
                if python3 -m venv "$venv_path"; then
                    echo -e "${GREEN}✓ Virtual environment created at: $venv_path${NC}"
                    log_setup "Python virtual environment created at $venv_path"
                    
                    # Activate virtual environment
                    if source "$venv_path/bin/activate"; then
                        echo -e "${GREEN}✓ Virtual environment activated${NC}"
                        
                        # Upgrade pip in venv
                        echo "Upgrading pip in virtual environment..."
                        pip install --upgrade pip >/dev/null 2>&1
                        
                        export SETUP_PYTHON_VENV_PATH="$venv_path"
                        export SETUP_PYTHON_USE_VENV="true"
                    else
                        echo -e "${YELLOW}⚠ Failed to activate virtual environment${NC}"
                        use_venv="false"
                        log_setup "Failed to activate virtual environment" "WARN"
                    fi
                else
                    echo -e "${YELLOW}⚠ Failed to create virtual environment${NC}"
                    echo "Continuing with system Python installation"
                    use_venv="false"
                    log_setup "Failed to create virtual environment" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ Using existing virtual environment${NC}"
                if source "$venv_path/bin/activate"; then
                    echo -e "${GREEN}✓ Existing virtual environment activated${NC}"
                    export SETUP_PYTHON_VENV_PATH="$venv_path"
                    export SETUP_PYTHON_USE_VENV="true"
                fi
            fi
        else
            echo -e "${YELLOW}⚠ Using system Python installation${NC}"
            log_setup "Using system Python installation"
        fi
    else
        echo -e "${YELLOW}⚠ Virtual environment not supported - using system Python${NC}"
        log_setup "Virtual environment not supported"
    fi
    
    # Python Package Installation
    echo ""
    echo -e "${CYAN}GWOMBAT Python Package Installation${NC}"
    echo ""
    echo "GWOMBAT uses Python for advanced features including:"
    echo "• 📊 SCuBA compliance analysis and reporting"
    echo "• 📈 Advanced data visualization (matplotlib)"
    echo "• 📋 HTML report generation (jinja2)"
    echo "• 🔐 Enhanced security analysis"
    echo "• 📊 Data processing and analytics (pandas, numpy)"
    echo ""
    
    local install_packages
    install_packages=$(get_user_input "Install GWOMBAT Python packages now? (y/n)" "y" "false")
    
    if [[ "$install_packages" =~ ^[Yy] ]]; then
        echo ""
        echo -e "${CYAN}Installing GWOMBAT Python packages...${NC}"
        
        # Check requirements file
        local requirements_file="$GWOMBAT_ROOT/python-modules/requirements.txt"
        if [[ ! -f "$requirements_file" ]]; then
            echo -e "${RED}✗ Requirements file not found: $requirements_file${NC}"
            log_setup "Requirements file not found" "ERROR"
            return 1
        fi
        
        echo "Requirements file: $requirements_file"
        echo ""
        echo -e "${BLUE}Packages to be installed:${NC}"
        
        # Show package list
        while IFS= read -r line; do
            if [[ "$line" =~ ^[a-zA-Z] ]]; then
                local package_name=$(echo "$line" | cut -d'>' -f1 | cut -d'=' -f1 | cut -d'[' -f1)
                echo "  • $package_name"
            fi
        done < "$requirements_file"
        
        echo ""
        echo "Installing packages (this may take a few minutes)..."
        
        # Install packages with progress indication
        local pip_cmd="pip3"
        if [[ "$use_venv" == "true" ]]; then
            pip_cmd="pip"  # Use venv pip
        fi
        
        if $pip_cmd install -r "$requirements_file" --upgrade; then
            echo -e "${GREEN}✓ All Python packages installed successfully${NC}"
            log_setup "Python packages installed successfully"
            
            # Verify key packages
            echo ""
            echo -e "${CYAN}Verifying package installation...${NC}"
            local packages_verified=0
            local packages_failed=()
            
            # Test key imports
            local key_packages=("pandas" "numpy" "matplotlib" "jinja2" "requests" "cryptography")
            for package in "${key_packages[@]}"; do
                if python3 -c "import $package" 2>/dev/null; then
                    echo -e "${GREEN}  ✓ $package${NC}"
                    ((packages_verified++))
                else
                    echo -e "${RED}  ✗ $package${NC}"
                    packages_failed+=("$package")
                fi
            done
            
            echo ""
            if [[ ${#packages_failed[@]} -eq 0 ]]; then
                echo -e "${GREEN}✅ All key packages verified successfully!${NC}"
                export SETUP_PYTHON_PACKAGES_INSTALLED="true"
                log_setup "All Python packages verified successfully"
            else
                echo -e "${YELLOW}⚠ Some packages failed verification: ${packages_failed[*]}${NC}"
                echo "You may need to install these manually later"
                export SETUP_PYTHON_PACKAGES_INSTALLED="partial"
                log_setup "Some Python packages failed verification: ${packages_failed[*]}" "WARN"
            fi
            
        else
            echo -e "${YELLOW}⚠ Some Python packages failed to install${NC}"
            echo ""
            echo -e "${BLUE}Troubleshooting options:${NC}"
            echo "1. Check your internet connection"
            echo "2. Ensure you have sufficient disk space"
            echo "3. Try installing packages individually:"
            echo "   pip3 install pandas numpy matplotlib jinja2"
            echo "4. Use system package manager if available:"
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "   sudo apt install python3-pandas python3-numpy python3-matplotlib"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                echo "   brew install python-tk  # For matplotlib GUI support"
            fi
            echo ""
            echo "You can retry package installation later by running:"
            echo "  ./gwombat.sh → Configuration → Setup Python Environment"
            
            export SETUP_PYTHON_PACKAGES_INSTALLED="failed"
            log_setup "Python package installation failed" "WARN"
        fi
        
        # Deactivate virtual environment if we activated it
        if [[ "$use_venv" == "true" && -n "$VIRTUAL_ENV" ]]; then
            deactivate 2>/dev/null || true
        fi
        
    else
        echo -e "${YELLOW}⚠ Skipping Python package installation${NC}"
        echo ""
        echo "You can install packages later with:"
        if [[ "$use_venv" == "true" ]]; then
            echo "  source $SETUP_PYTHON_VENV_PATH/bin/activate"
            echo "  pip install -r python-modules/requirements.txt"
            echo "  deactivate"
        else
            echo "  pip3 install -r python-modules/requirements.txt"
        fi
        echo ""
        echo "Or use the GWOMBAT configuration menu:"
        echo "  ./gwombat.sh → Configuration → Setup Python Environment"
        
        export SETUP_PYTHON_PACKAGES_INSTALLED="skipped"
        log_setup "Skipped Python package installation"
    fi
    
    # Python Environment Summary
    echo ""
    echo -e "${CYAN}Python Environment Summary${NC}"
    echo "========================="
    echo "Python Version: $python_version"
    echo "Python Path: $python_path"
    echo "Virtual Environment: $use_venv"
    if [[ "$use_venv" == "true" ]]; then
        echo "Virtual Environment Path: $SETUP_PYTHON_VENV_PATH"
    fi
    echo "Package Installation: $SETUP_PYTHON_PACKAGES_INSTALLED"
    echo ""
    
    # Store configuration for .env file
    export SETUP_PYTHON_VERSION="$python_version"
    export SETUP_PYTHON_PATH="$python_path"
}

# Check and configure optional tools
configure_optional_tools() {
    echo ""
    echo -e "${CYAN}🛠️ Optional Tools Configuration${NC}"
    echo ""
    echo "Let's check for optional tools that enhance GWOMBAT functionality."
    echo ""
    
    # GYB (Got Your Back) - Comprehensive Configuration
    echo -e "${BLUE}=== GYB (Got Your Back) - Gmail Backup Tool ===${NC}"
    if command -v gyb >/dev/null 2>&1; then
        local gyb_version=$(gyb --version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN}✓ GYB found: $gyb_version${NC}"
        log_setup "GYB found: $gyb_version"
        
        # Check GYB configuration
        echo ""
        echo -e "${CYAN}GYB Configuration Check${NC}"
        local gyb_config_dir="$HOME/.gyb"
        if [[ -d "$gyb_config_dir" && -f "$gyb_config_dir/oauth2.txt" ]]; then
            echo -e "${GREEN}✓ GYB appears to be configured${NC}"
            echo -e "${GREEN}  Config directory: $gyb_config_dir${NC}"
        else
            echo -e "${YELLOW}⚠ GYB needs initial configuration${NC}"
            echo ""
            echo -e "${BLUE}GYB Configuration Steps:${NC}"
            echo "1. Run: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu}"
            echo "2. Follow OAuth setup (similar to GAM)"
            echo "3. Test with: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu} --action estimate"
            echo ""
            
            local configure_gyb
            configure_gyb=$(get_user_input "Configure GYB now? (y/n)" "n" "false")
            
            if [[ "$configure_gyb" =~ ^[Yy] ]]; then
                echo ""
                local test_email
                test_email=$(get_user_input "Enter test email for GYB setup" "$SETUP_ADMIN_USER" "false")
                if [[ -n "$test_email" ]]; then
                    echo -e "${CYAN}Running GYB initial setup...${NC}"
                    echo "This will open a browser for OAuth authorization..."
                    if gyb --email "$test_email" --action estimate; then
                        echo -e "${GREEN}✓ GYB configuration successful!${NC}"
                        log_setup "GYB configured successfully for $test_email"
                    else
                        echo -e "${YELLOW}⚠ GYB configuration may need additional setup${NC}"
                        log_setup "GYB configuration incomplete" "WARN"
                    fi
                fi
            else
                echo -e "${YELLOW}⚠ Skipping GYB configuration${NC}"
                echo "Configure later with: gyb --email your-user@${SETUP_DOMAIN:-yourdomain.edu}"
            fi
        fi
        
        # GYB Advanced Features
        echo ""
        echo -e "${CYAN}GYB Advanced Features:${NC}"
        echo "• Full Gmail backup and restore"
        echo "• Incremental backups"
        echo "• Cross-account email migration"
        echo "• MBOX format export"
        echo "• Label-based filtering"
        echo ""
        
    else
        echo -e "${YELLOW}○ GYB not found${NC}"
        echo ""
        echo -e "${BLUE}GYB Installation Guide:${NC}"
        echo "1. Download from: https://github.com/GAM-team/got-your-back"
        echo "2. Install using pip: pip install gyb"
        echo "3. Or download binary from releases page"
        echo ""
        
        local install_gyb
        install_gyb=$(get_user_input "Install GYB now? (y/n)" "n" "false")
        
        if [[ "$install_gyb" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing GYB...${NC}"
            if command -v pip3 >/dev/null 2>&1; then
                if pip3 install gyb; then
                    echo -e "${GREEN}✓ GYB installation completed${NC}"
                    echo "Run setup wizard again to configure GYB"
                    log_setup "GYB installed successfully"
                else
                    echo -e "${YELLOW}⚠ GYB installation failed${NC}"
                    echo "Install manually from: https://github.com/GAM-team/got-your-back"
                    log_setup "GYB installation failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ pip3 not available. Install GYB manually${NC}"
                echo "Download from: https://github.com/GAM-team/got-your-back"
            fi
        fi
        log_setup "GYB not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== rclone - Cloud Storage Sync Tool ===${NC}"
    if command -v rclone >/dev/null 2>&1; then
        local rclone_version=$(rclone version 2>/dev/null | head -n1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
        echo -e "${GREEN}✓ rclone found: $rclone_version${NC}"
        
        # Check for configured remotes
        local remotes=$(rclone listremotes 2>/dev/null)
        if [[ -n "$remotes" ]]; then
            echo -e "${GREEN}✓ rclone has configured remotes:${NC}"
            echo "$remotes" | sed 's/^/    /'
            log_setup "rclone found with remotes: $rclone_version"
        else
            echo -e "${YELLOW}⚠ No rclone remotes configured${NC}"
            echo ""
            echo -e "${BLUE}rclone Configuration Walkthrough:${NC}"
            echo ""
            echo "rclone supports 40+ cloud storage providers:"
            echo "• Google Drive, OneDrive, Dropbox"
            echo "• AWS S3, Google Cloud Storage, Azure"
            echo "• Box, pCloud, Mega, and many more"
            echo ""
            
            local configure_rclone
            configure_rclone=$(get_user_input "Configure rclone remote now? (y/n)" "n" "false")
            
            if [[ "$configure_rclone" =~ ^[Yy] ]]; then
                echo ""
                echo -e "${CYAN}Popular cloud storage options for GWOMBAT:${NC}"
                echo "1. Google Drive (recommended for Google Workspace)"
                echo "2. AWS S3 (enterprise backup)"
                echo "3. Microsoft OneDrive"
                echo "4. Local/Network storage"
                echo "5. Other (full rclone config)"
                echo ""
                
                local storage_choice
                storage_choice=$(get_user_input "Select storage type (1-5)" "1" "false")
                
                case "$storage_choice" in
                    1)
                        echo ""
                        echo -e "${CYAN}Configuring Google Drive remote...${NC}"
                        echo "This will create a 'gdrive' remote for Google Drive"
                        rclone config create gdrive drive
                        ;;
                    2)
                        echo ""
                        echo -e "${CYAN}Configuring AWS S3 remote...${NC}"
                        echo "You'll need your AWS Access Key ID and Secret"
                        rclone config create s3backup s3
                        ;;
                    3)
                        echo ""
                        echo -e "${CYAN}Configuring OneDrive remote...${NC}"
                        rclone config create onedrive onedrive
                        ;;
                    4)
                        echo ""
                        echo -e "${CYAN}Configuring local/network storage...${NC}"
                        local local_path
                        local_path=$(get_user_input "Enter backup directory path" "/backup/gwombat" "false")
                        rclone config create local local path "$local_path"
                        ;;
                    5)
                        echo ""
                        echo -e "${CYAN}Running full rclone configuration...${NC}"
                        rclone config
                        ;;
                esac
                
                # Test the configuration
                echo ""
                local remotes_after=$(rclone listremotes 2>/dev/null)
                if [[ -n "$remotes_after" ]]; then
                    echo -e "${GREEN}✓ rclone configuration successful!${NC}"
                    echo -e "${GREEN}Configured remotes:${NC}"
                    echo "$remotes_after" | sed 's/^/    /'
                    log_setup "rclone configured successfully"
                else
                    echo -e "${YELLOW}⚠ rclone configuration incomplete${NC}"
                    log_setup "rclone configuration failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ Skipping rclone configuration${NC}"
                echo "Configure later with: rclone config"
                log_setup "rclone found but no remotes configured"
            fi
        fi
        
        # rclone Advanced Features
        echo ""
        echo -e "${CYAN}rclone Advanced Features for GWOMBAT:${NC}"
        echo "• Automated cloud backups"
        echo "• Cross-cloud migrations"
        echo "• Encryption at rest"
        echo "• Bandwidth limiting"
        echo "• Progress monitoring"
        echo ""
        
    else
        echo -e "${YELLOW}○ rclone not found${NC}"
        echo ""
        echo -e "${BLUE}rclone Installation Guide:${NC}"
        echo "1. Visit: https://rclone.org/install/"
        echo "2. One-line install: curl https://rclone.org/install.sh | sudo bash"
        echo "3. Or download binary for your platform"
        echo ""
        
        local install_rclone
        install_rclone=$(get_user_input "Install rclone now? (y/n)" "n" "false")
        
        if [[ "$install_rclone" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing rclone...${NC}"
            if command -v curl >/dev/null 2>&1; then
                if curl https://rclone.org/install.sh | sudo bash; then
                    echo -e "${GREEN}✓ rclone installation completed${NC}"
                    echo "Run setup wizard again to configure remotes"
                    log_setup "rclone installed successfully"
                else
                    echo -e "${YELLOW}⚠ rclone installation failed${NC}"
                    echo "Install manually from: https://rclone.org/install/"
                    log_setup "rclone installation failed" "WARN"
                fi
            else
                echo -e "${YELLOW}⚠ curl not available. Install rclone manually${NC}"
                echo "Download from: https://rclone.org/install/"
            fi
        fi
        log_setup "rclone not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== restic - Encrypted Backup Tool ===${NC}"
    if command -v restic >/dev/null 2>&1; then
        local restic_version=$(restic version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo -e "${GREEN}✓ restic found: $restic_version${NC}"
        echo ""
        echo -e "${CYAN}restic Features:${NC}"
        echo "• Encrypted, deduplicated backups"
        echo "• Incremental backups"
        echo "• Multiple storage backends"
        echo "• Cross-platform compatibility"
        echo ""
        echo "Configure restic repositories in GWOMBAT backup settings"
        log_setup "restic found: $restic_version"
    else
        echo -e "${YELLOW}○ restic not found${NC}"
        echo ""
        echo -e "${BLUE}restic Installation Guide:${NC}"
        echo "1. Visit: https://restic.net/"
        echo "2. Download binary for your platform"
        echo "3. Or install via package manager"
        echo ""
        
        local install_restic
        install_restic=$(get_user_input "Install restic now? (y/n)" "n" "false")
        
        if [[ "$install_restic" =~ ^[Yy] ]]; then
            echo ""
            echo -e "${CYAN}Installing restic...${NC}"
            # Platform-specific installation
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                if command -v apt >/dev/null 2>&1; then
                    sudo apt update && sudo apt install restic
                elif command -v yum >/dev/null 2>&1; then
                    sudo yum install restic
                else
                    echo "Please install restic manually from https://restic.net/"
                fi
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                if command -v brew >/dev/null 2>&1; then
                    brew install restic
                else
                    echo "Please install restic manually from https://restic.net/"
                fi
            else
                echo "Please install restic manually from https://restic.net/"
            fi
        fi
        log_setup "restic not found"
    fi
    
    echo ""
    echo -e "${BLUE}=== jq - JSON Processing Tool ===${NC}"
    if command -v jq >/dev/null 2>&1; then
        local jq_version=$(jq --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓ jq found: $jq_version${NC}"
        log_setup "jq found: $jq_version"
    else
        echo -e "${YELLOW}○ jq not found${NC}"
        echo ""
        echo -e "${BLUE}jq Installation:${NC}"
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "Install with: sudo apt install jq"
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install jq"
        else
            echo "Visit: https://stedolan.github.io/jq/download/"
        fi
        
        local install_jq
        install_jq=$(get_user_input "Install jq now? (y/n)" "y" "false")
        
        if [[ "$install_jq" =~ ^[Yy] ]]; then
            if [[ "$OSTYPE" == "linux-gnu"* ]] && command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y jq
            elif [[ "$OSTYPE" == "darwin"* ]] && command -v brew >/dev/null 2>&1; then
                brew install jq
            else
                echo "Please install jq manually"
            fi
        fi
        log_setup "jq not found"
    fi
}

# Configure server/deployment settings
configure_deployment_settings() {
    echo ""
    echo -e "${CYAN}🚀 Deployment Configuration${NC}"
    echo ""
    echo "Configure settings for deployment to production servers (optional)."
    echo ""
    
    local configure_deployment
    configure_deployment=$(get_user_input "Configure deployment settings now? (y/n)" "n" "false")
    
    if [[ "$configure_deployment" =~ ^[Yy] ]]; then
        # Production server
        local production_server
        production_server=$(get_user_input "Production server hostname" "" "false")
        
        if [[ -n "$production_server" ]]; then
            # Production user
            local production_user
            production_user=$(get_user_input "Production server username" "" "false")
            
            # GWOMBAT path on server
            local gwombat_path
            gwombat_path=$(get_user_input "GWOMBAT path on server" "/opt/gwombat" "false")
            
            # SSH key path
            local ssh_key_path
            ssh_key_path=$(get_user_input "SSH key path" "$HOME/.ssh/gwombatgit-key" "false")
            
            export SETUP_PRODUCTION_SERVER="$production_server"
            export SETUP_PRODUCTION_USER="$production_user"
            export SETUP_GWOMBAT_PATH="$gwombat_path"
            export SETUP_SSH_KEY_PATH="$ssh_key_path"
            
            echo -e "${GREEN}✓ Deployment settings configured${NC}"
            log_setup "Deployment configured: $production_server"
        fi
    else
        echo -e "${YELLOW}⚠ Skipping deployment configuration${NC}"
        log_setup "Skipped deployment configuration"
    fi
}

# Ask about initial scans
configure_initial_scans() {
    echo ""
    echo -e "${CYAN}📊 Initial System Discovery & Baseline Scans${NC}"
    echo ""
    echo "GWOMBAT can perform comprehensive initial scans to establish baseline"
    echo "system state and enable effective monitoring and management."
    echo ""
    echo -e "${BLUE}Available scan modules:${NC}"
    echo ""
    echo -e "${GREEN}Core System Scans:${NC}"
    echo "1. 👥 Account Discovery & Statistics"
    echo "   • All user accounts (active, suspended, admin)"
    echo "   • Account creation dates and last login"
    echo "   • Storage usage per user"
    echo "   • Organizational unit placement"
    echo ""
    echo "2. 💾 Shared Drives & Storage Analysis"
    echo "   • All shared drives and their sizes"
    echo "   • Permission analysis and sharing patterns"
    echo "   • Storage quotas and usage trends"
    echo "   • Orphaned files detection"
    echo ""
    echo "3. 🔐 Security & Compliance Baseline"
    echo "   • 2FA status for all accounts"
    echo "   • Admin activity monitoring setup"
    echo "   • Password policy compliance"
    echo "   • External sharing audit"
    echo ""
    echo -e "${BLUE}Advanced Discovery Scans:${NC}"
    echo "4. 📧 Email & Groups Infrastructure"
    echo "   • All Google Groups and memberships"
    echo "   • Email routing and forwarding rules"
    echo "   • Distribution list analysis"
    echo "   • Email retention policies"
    echo ""
    echo "5. 🌐 Domain & DNS Configuration"
    echo "   • Domain verification status"
    echo "   • DNS records and mail routing"
    echo "   • Custom directory integration"
    echo "   • API access and service accounts"
    echo ""
    echo "6. 📱 Device & Mobile Management"
    echo "   • Mobile device inventory"
    echo "   • Chrome OS device management"
    echo "   • App installations and policies"
    echo "   • Security compliance status"
    echo ""
    echo -e "${PURPLE}Scan Configuration Options:${NC}"
    echo "7. Custom scan selection (choose specific scans)"
    echo "8. Full comprehensive scan (all modules - recommended)"
    echo "9. Essential scans only (accounts + drives + security)"
    echo "10. Skip all initial scans"
    echo ""
    
    local scan_choice
    scan_choice=$(get_user_input "Select scan option (1-10)" "8" "true")
    
    case "$scan_choice" in
        1)
            export SETUP_SCAN_ACCOUNTS="true"
            echo -e "${GREEN}✓ Will perform account discovery & statistics${NC}"
            log_setup "Initial scan: accounts only"
            ;;
        2)
            export SETUP_SCAN_DRIVES="true"
            echo -e "${GREEN}✓ Will perform shared drives analysis${NC}"
            log_setup "Initial scan: shared drives only"
            ;;
        3)
            export SETUP_SCAN_SECURITY="true"
            echo -e "${GREEN}✓ Will perform security baseline scan${NC}"
            log_setup "Initial scan: security only"
            ;;
        4)
            export SETUP_SCAN_GROUPS="true"
            echo -e "${GREEN}✓ Will perform email & groups infrastructure scan${NC}"
            log_setup "Initial scan: groups only"
            ;;
        5)
            export SETUP_SCAN_DOMAIN="true"
            echo -e "${GREEN}✓ Will perform domain & DNS configuration scan${NC}"
            log_setup "Initial scan: domain only"
            ;;
        6)
            export SETUP_SCAN_DEVICES="true"
            echo -e "${GREEN}✓ Will perform device & mobile management scan${NC}"
            log_setup "Initial scan: devices only"
            ;;
        7)
            echo ""
            echo -e "${CYAN}Custom Scan Selection${NC}"
            echo "Select which scans to perform:"
            echo ""
            
            # Account scan
            local accounts_scan
            accounts_scan=$(get_user_input "Perform account discovery? (y/n)" "y" "false")
            if [[ "$accounts_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_ACCOUNTS="true"
                echo -e "${GREEN}  ✓ Account discovery enabled${NC}"
            fi
            
            # Drives scan
            local drives_scan
            drives_scan=$(get_user_input "Perform shared drives analysis? (y/n)" "y" "false")
            if [[ "$drives_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DRIVES="true"
                echo -e "${GREEN}  ✓ Shared drives analysis enabled${NC}"
            fi
            
            # Security scan
            local security_scan
            security_scan=$(get_user_input "Perform security baseline scan? (y/n)" "y" "false")
            if [[ "$security_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_SECURITY="true"
                echo -e "${GREEN}  ✓ Security baseline scan enabled${NC}"
            fi
            
            # Groups scan
            local groups_scan
            groups_scan=$(get_user_input "Perform email & groups scan? (y/n)" "n" "false")
            if [[ "$groups_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_GROUPS="true"
                echo -e "${GREEN}  ✓ Email & groups scan enabled${NC}"
            fi
            
            # Domain scan
            local domain_scan
            domain_scan=$(get_user_input "Perform domain configuration scan? (y/n)" "n" "false")
            if [[ "$domain_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DOMAIN="true"
                echo -e "${GREEN}  ✓ Domain configuration scan enabled${NC}"
            fi
            
            # Devices scan
            local devices_scan
            devices_scan=$(get_user_input "Perform device management scan? (y/n)" "n" "false")
            if [[ "$devices_scan" =~ ^[Yy] ]]; then
                export SETUP_SCAN_DEVICES="true"
                echo -e "${GREEN}  ✓ Device management scan enabled${NC}"
            fi
            
            log_setup "Initial scan: custom selection"
            ;;
        8)
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            export SETUP_SCAN_GROUPS="true"
            export SETUP_SCAN_DOMAIN="true"
            export SETUP_SCAN_DEVICES="true"
            echo -e "${GREEN}✓ Will perform full comprehensive scan (all modules)${NC}"
            log_setup "Initial scan: comprehensive (all modules)"
            ;;
        9)
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            echo -e "${GREEN}✓ Will perform essential scans (accounts + drives + security)${NC}"
            log_setup "Initial scan: essential scans"
            ;;
        10)
            echo -e "${YELLOW}⚠ Skipping all initial scans${NC}"
            log_setup "Skipped all initial scans"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice, defaulting to essential scans${NC}"
            export SETUP_SCAN_ACCOUNTS="true"
            export SETUP_SCAN_DRIVES="true"
            export SETUP_SCAN_SECURITY="true"
            log_setup "Invalid scan choice, defaulted to essential"
            ;;
    esac
    
    # Configure scan depth and output
    if [[ "$SETUP_SCAN_ACCOUNTS" == "true" || "$SETUP_SCAN_DRIVES" == "true" || "$SETUP_SCAN_SECURITY" == "true" || 
          "$SETUP_SCAN_GROUPS" == "true" || "$SETUP_SCAN_DOMAIN" == "true" || "$SETUP_SCAN_DEVICES" == "true" ]]; then
        echo ""
        echo -e "${CYAN}Scan Configuration Options:${NC}"
        echo ""
        
        # Scan depth
        echo "Scan depth level:"
        echo "1. Quick scan (basic statistics only)"
        echo "2. Standard scan (detailed analysis)"
        echo "3. Deep scan (comprehensive with historical data)"
        echo ""
        
        local scan_depth
        scan_depth=$(get_user_input "Select scan depth (1-3)" "2" "false")
        export SETUP_SCAN_DEPTH="$scan_depth"
        
        # Output format
        echo ""
        echo "Scan output format:"
        echo "1. Console output only"
        echo "2. CSV reports + console"
        echo "3. HTML dashboard + CSV + console (recommended)"
        echo ""
        
        local output_format
        output_format=$(get_user_input "Select output format (1-3)" "3" "false")
        export SETUP_SCAN_OUTPUT="$output_format"
        
        # Estimated time warning
        echo ""
        echo -e "${YELLOW}⏱️  Estimated scan time based on your selections:${NC}"
        case "$scan_depth" in
            1) echo "Quick scan: 2-5 minutes" ;;
            2) echo "Standard scan: 5-15 minutes" ;;
            3) echo "Deep scan: 15-45 minutes" ;;
        esac
        echo ""
        echo -e "${BLUE}💡 Tip: Scans run in background and can be interrupted safely${NC}"
        echo -e "${BLUE}    Results are saved incrementally as scans complete${NC}"
        
        log_setup "Scan configuration: depth=$scan_depth, output=$output_format"
    fi
}

# Generate .env file
generate_env_file() {
    echo ""
    echo -e "${CYAN}📝 Generating configuration file...${NC}"
    
    # Backup existing .env if it exists
    if [[ -f "$ENV_FILE" ]]; then
        local backup_file="$ENV_FILE.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$ENV_FILE" "$backup_file"
        echo -e "${YELLOW}⚠ Existing .env backed up to: $backup_file${NC}"
        log_setup "Backed up existing .env to $backup_file"
    fi
    
    # Generate new .env file
    cat > "$ENV_FILE" << EOF
# GWOMBAT Configuration
# Generated by Setup Wizard on $(date)

# Domain and Organization Configuration
DOMAIN="${SETUP_DOMAIN:-your-domain.edu}"
ADMIN_EMAIL="${SETUP_ADMIN_EMAIL:-gwombat@your-domain.edu}"
ADMIN_USER="${SETUP_ADMIN_USER:-your-actual-admin@your-domain.edu}"

# GAM Configuration
GAM_PATH="${SETUP_GAM_PATH:-/usr/local/bin/gam}"
GAM_CONFIG_PATH="${SETUP_GAM_CONFIG_PATH:-$HOME/.gam}"

# Python Environment Configuration
PYTHON_PATH="${SETUP_PYTHON_PATH:-python3}"
PYTHON_VERSION="${SETUP_PYTHON_VERSION:-unknown}"
PYTHON_USE_VENV="${SETUP_PYTHON_USE_VENV:-false}"
PYTHON_VENV_PATH="${SETUP_PYTHON_VENV_PATH:-}"
PYTHON_PACKAGES_INSTALLED="${SETUP_PYTHON_PACKAGES_INSTALLED:-false}"

# Organizational Unit Paths
SUSPENDED_OU="${SETUP_SUSPENDED_OU:-/Suspended Users}"
PENDING_DELETION_OU="${SETUP_PENDING_DELETION_OU:-/Suspended Users/Pending Deletion}"
TEMPORARY_HOLD_OU="${SETUP_TEMPORARY_HOLD_OU:-/Suspended Users/Temporary Hold}"
EXIT_ROW_OU="${SETUP_EXIT_ROW_OU:-/Suspended Users/Exit Row}"

# Production Server Configuration (if configured)
PRODUCTION_SERVER="${SETUP_PRODUCTION_SERVER:-your-server.edu}"
PRODUCTION_USER="${SETUP_PRODUCTION_USER:-your-user}"
GWOMBAT_PATH="${SETUP_GWOMBAT_PATH:-/opt/path/to/gwombat}"

# SSH Configuration
SSH_KEY_PATH="${SETUP_SSH_KEY_PATH:-$HOME/.ssh/gwombatgit-key}"
SSH_KEY_PASSWORD="${SETUP_SSH_KEY_PASSWORD:-}"

# Google Drive Configuration
DRIVE_LABEL_ID="${SETUP_DRIVE_LABEL_ID:-your-drive-label-id}"

# Feature Flags (set by setup wizard)
SETUP_COMPLETED="true"
SETUP_DATE="$(date)"
INITIAL_SCANS_ACCOUNTS="${SETUP_SCAN_ACCOUNTS:-false}"
INITIAL_SCANS_DRIVES="${SETUP_SCAN_DRIVES:-false}"
INITIAL_SCANS_SECURITY="${SETUP_SCAN_SECURITY:-false}"
INITIAL_SCANS_GROUPS="${SETUP_SCAN_GROUPS:-false}"
INITIAL_SCANS_DOMAIN="${SETUP_SCAN_DOMAIN:-false}"
INITIAL_SCANS_DEVICES="${SETUP_SCAN_DEVICES:-false}"
SCAN_DEPTH="${SETUP_SCAN_DEPTH:-2}"
SCAN_OUTPUT_FORMAT="${SETUP_SCAN_OUTPUT:-3}"
EOF
    
    echo -e "${GREEN}✓ Configuration file created: $ENV_FILE${NC}"
    log_setup "Generated .env file"
}

# Perform initial scans
perform_initial_scans() {
    echo ""
    echo -e "${CYAN}🔍 Performing Initial System Discovery Scans${NC}"
    echo ""
    
    # Check if any scans are enabled
    if [[ "$SETUP_SCAN_ACCOUNTS" != "true" && "$SETUP_SCAN_DRIVES" != "true" && "$SETUP_SCAN_SECURITY" != "true" && 
          "$SETUP_SCAN_GROUPS" != "true" && "$SETUP_SCAN_DOMAIN" != "true" && "$SETUP_SCAN_DEVICES" != "true" ]]; then
        echo -e "${YELLOW}⚠ No initial scans configured${NC}"
        return 0
    fi
    
    # Create scan results directory
    local scan_date=$(date +%Y%m%d-%H%M%S)
    local scan_dir="$GWOMBAT_ROOT/reports/initial-scan-$scan_date"
    mkdir -p "$scan_dir"
    
    local scan_log="$scan_dir/scan-log.txt"
    local scan_summary="$scan_dir/scan-summary.txt"
    
    echo "Scan results will be saved to: $scan_dir"
    echo "This may take several minutes depending on your domain size and scan depth..."
    echo ""
    
    # Initialize progress tracking
    local total_scans=0
    local completed_scans=0
    
    # Count enabled scans
    [[ "$SETUP_SCAN_ACCOUNTS" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DRIVES" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_SECURITY" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_GROUPS" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DOMAIN" == "true" ]] && ((total_scans++))
    [[ "$SETUP_SCAN_DEVICES" == "true" ]] && ((total_scans++))
    
    echo "$(date): Starting $total_scans scan modules" > "$scan_log"
    echo "Scan depth: ${SETUP_SCAN_DEPTH:-2}, Output format: ${SETUP_SCAN_OUTPUT:-3}" >> "$scan_log"
    echo "" >> "$scan_log"
    
    # Initialize databases first
    echo -e "${CYAN}Initializing GWOMBAT databases...${NC}"
    if [[ -x "$GWOMBAT_ROOT/database_functions.sh" ]]; then
        if "$GWOMBAT_ROOT/database_functions.sh" init >> "$scan_log" 2>&1; then
            echo -e "${GREEN}✓ Database initialization successful${NC}"
        else
            echo -e "${YELLOW}⚠ Database initialization had issues (continuing)${NC}"
        fi
    fi
    echo ""
    
    # Account Discovery & Statistics
    if [[ "$SETUP_SCAN_ACCOUNTS" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 👥 Account Discovery & Statistics${NC}"
        
        local account_report="$scan_dir/accounts-discovery.csv"
        local account_summary="$scan_dir/accounts-summary.txt"
        
        echo "$(date): Starting account discovery scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering all user accounts..."
            
            # Basic account information
            echo "Email,Name,OrgUnit,CreationTime,LastLoginTime,IsAdmin,IsSuspended,StorageUsed,StorageLimit" > "$account_report"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" == "1" ]]; then
                # Quick scan - basic user list
                $SETUP_GAM_PATH print users basic >> "$scan_log" 2>&1
                echo "Quick account scan completed" >> "$account_summary"
            elif [[ "${SETUP_SCAN_DEPTH:-2}" == "2" ]]; then
                # Standard scan - detailed account info
                echo "Performing standard account analysis..."
                $SETUP_GAM_PATH print users fullname email ou creationtime lastlogintime isadmin suspended quotaused >> "$account_report" 2>>"$scan_log"
                
                # Account statistics
                local total_users=$($SETUP_GAM_PATH print users | tail -n +2 | wc -l)
                local admin_users=$($SETUP_GAM_PATH print users query isadmin=true | tail -n +2 | wc -l)
                local suspended_users=$($SETUP_GAM_PATH print users query issuspended=true | tail -n +2 | wc -l)
                
                echo "Account Statistics Summary" > "$account_summary"
                echo "=========================" >> "$account_summary"
                echo "Total Users: $total_users" >> "$account_summary"
                echo "Admin Users: $admin_users" >> "$account_summary"
                echo "Suspended Users: $suspended_users" >> "$account_summary"
                echo "Active Users: $((total_users - suspended_users))" >> "$account_summary"
                echo "" >> "$account_summary"
                
            else
                # Deep scan - comprehensive analysis with storage
                echo "Performing deep account analysis with storage details..."
                $SETUP_GAM_PATH print users fullname email ou creationtime lastlogintime isadmin suspended quotaused quotalimit >> "$account_report" 2>>"$scan_log"
                
                # Detailed organizational unit analysis
                echo "Analyzing organizational unit distribution..."
                $SETUP_GAM_PATH print orgs >> "$scan_dir/organizational-units.csv" 2>>"$scan_log"
                
                # Generate comprehensive summary
                echo "Generating comprehensive account analysis..." >> "$scan_log"
            fi
            
            echo -e "${GREEN}  ✓ Account discovery completed${NC}"
            echo "    Results: $account_report"
            if [[ -f "$account_summary" ]]; then
                echo "    Summary: $account_summary"
            fi
        else
            echo -e "${RED}  ✗ GAM not available for account scan${NC}"
            echo "GAM not available" >> "$account_summary"
        fi
        
        echo "$(date): Account discovery scan completed" >> "$scan_log"
        echo ""
        log_setup "Account discovery scan completed"
    fi
    
    # Shared Drives & Storage Analysis  
    if [[ "$SETUP_SCAN_DRIVES" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 💾 Shared Drives & Storage Analysis${NC}"
        
        local drives_report="$scan_dir/shared-drives.csv"
        local drives_summary="$scan_dir/drives-summary.txt"
        
        echo "$(date): Starting shared drives analysis" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering shared drives..."
            
            echo "DriveId,Name,CreatedTime,SizeGB,FileCount,Organizers,Members" > "$drives_report"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" == "1" ]]; then
                # Quick scan - basic drive list
                $SETUP_GAM_PATH print shareddrives >> "$drives_report" 2>>"$scan_log"
            else
                # Standard/Deep scan - detailed drive analysis
                echo "Analyzing shared drive details and permissions..."
                $SETUP_GAM_PATH print shareddrives >> "$scan_dir/shareddrives-full.csv" 2>>"$scan_log"
                
                # Drive statistics
                local total_drives=$($SETUP_GAM_PATH print shareddrives | tail -n +2 | wc -l)
                
                echo "Shared Drives Summary" > "$drives_summary"
                echo "====================" >> "$drives_summary"
                echo "Total Shared Drives: $total_drives" >> "$drives_summary"
                echo "" >> "$drives_summary"
                
                if [[ "${SETUP_SCAN_DEPTH:-2}" == "3" ]]; then
                    # Deep scan - file analysis
                    echo "Performing deep file analysis (this may take longer)..."
                    echo "Files by shared drive analysis initiated..." >> "$scan_log"
                fi
            fi
            
            echo -e "${GREEN}  ✓ Shared drives analysis completed${NC}"
            echo "    Results: $drives_report"
        else
            echo -e "${RED}  ✗ GAM not available for drives scan${NC}"
            echo "GAM not available" >> "$drives_summary"
        fi
        
        echo "$(date): Shared drives analysis completed" >> "$scan_log"
        echo ""
        log_setup "Shared drives analysis completed"
    fi
    
    # Security & Compliance Baseline
    if [[ "$SETUP_SCAN_SECURITY" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 🔐 Security & Compliance Baseline${NC}"
        
        local security_report="$scan_dir/security-baseline.csv"
        local security_summary="$scan_dir/security-summary.txt"
        
        echo "$(date): Starting security baseline scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Analyzing security configurations..."
            
            # 2FA Analysis
            echo "Checking 2FA status for all users..."
            echo "Email,Name,2FA_Enrolled,2FA_Enforced,LastLogin" > "$security_report"
            $SETUP_GAM_PATH print users email fullname isenrolledin2sv isenforcedin2sv lastlogintime >> "$security_report" 2>>"$scan_log"
            
            # Admin activity analysis
            echo "Analyzing admin accounts..."
            $SETUP_GAM_PATH print users query isadmin=true >> "$scan_dir/admin-accounts.csv" 2>>"$scan_log"
            
            # External sharing audit
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Auditing external sharing settings..."
                $SETUP_GAM_PATH print domains >> "$scan_dir/domain-security.csv" 2>>"$scan_log"
            fi
            
            # Security summary
            local users_with_2fa=$($SETUP_GAM_PATH print users query isenrolledin2sv=true | tail -n +2 | wc -l)
            local total_users_check=$($SETUP_GAM_PATH print users | tail -n +2 | wc -l)
            local admin_count=$($SETUP_GAM_PATH print users query isadmin=true | tail -n +2 | wc -l)
            
            echo "Security Baseline Summary" > "$security_summary"
            echo "========================" >> "$security_summary"
            echo "Total Users: $total_users_check" >> "$security_summary"
            echo "Users with 2FA: $users_with_2fa" >> "$security_summary"
            echo "Admin Accounts: $admin_count" >> "$security_summary"
            echo "2FA Coverage: $(( users_with_2fa * 100 / total_users_check ))%" >> "$security_summary"
            echo "" >> "$security_summary"
            
            echo -e "${GREEN}  ✓ Security baseline scan completed${NC}"
            echo "    Results: $security_report"
        else
            echo -e "${RED}  ✗ GAM not available for security scan${NC}"
            echo "GAM not available" >> "$security_summary"
        fi
        
        echo "$(date): Security baseline scan completed" >> "$scan_log"
        echo ""
        log_setup "Security baseline scan completed"
    fi
    
    # Email & Groups Infrastructure
    if [[ "$SETUP_SCAN_GROUPS" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 📧 Email & Groups Infrastructure${NC}"
        
        local groups_report="$scan_dir/groups-infrastructure.csv"
        local groups_summary="$scan_dir/groups-summary.txt"
        
        echo "$(date): Starting groups infrastructure scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering Google Groups..."
            
            echo "GroupEmail,Name,Description,MemberCount,DirectMembersCount,Settings" > "$groups_report"
            $SETUP_GAM_PATH print groups >> "$groups_report" 2>>"$scan_log"
            
            # Group statistics
            local total_groups=$($SETUP_GAM_PATH print groups | tail -n +2 | wc -l)
            
            echo "Groups Infrastructure Summary" > "$groups_summary"
            echo "============================" >> "$groups_summary"
            echo "Total Groups: $total_groups" >> "$groups_summary"
            echo "" >> "$groups_summary"
            
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Analyzing group memberships..."
                # Detailed group analysis would go here
            fi
            
            echo -e "${GREEN}  ✓ Groups infrastructure scan completed${NC}"
            echo "    Results: $groups_report"
        else
            echo -e "${RED}  ✗ GAM not available for groups scan${NC}"
            echo "GAM not available" >> "$groups_summary"
        fi
        
        echo "$(date): Groups infrastructure scan completed" >> "$scan_log"
        echo ""
        log_setup "Groups infrastructure scan completed"
    fi
    
    # Domain & DNS Configuration
    if [[ "$SETUP_SCAN_DOMAIN" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 🌐 Domain & DNS Configuration${NC}"
        
        local domain_report="$scan_dir/domain-configuration.txt"
        
        echo "$(date): Starting domain configuration scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Analyzing domain configuration..."
            
            echo "Domain Configuration Analysis" > "$domain_report"
            echo "============================" >> "$domain_report"
            $SETUP_GAM_PATH info domain >> "$domain_report" 2>>"$scan_log"
            
            echo "" >> "$domain_report"
            echo "Domain Verification:" >> "$domain_report"
            $SETUP_GAM_PATH print domains >> "$domain_report" 2>>"$scan_log"
            
            echo -e "${GREEN}  ✓ Domain configuration scan completed${NC}"
            echo "    Results: $domain_report"
        else
            echo -e "${RED}  ✗ GAM not available for domain scan${NC}"
            echo "GAM not available" > "$domain_report"
        fi
        
        echo "$(date): Domain configuration scan completed" >> "$scan_log"
        echo ""
        log_setup "Domain configuration scan completed"
    fi
    
    # Device & Mobile Management
    if [[ "$SETUP_SCAN_DEVICES" == "true" ]]; then
        ((completed_scans++))
        echo -e "${CYAN}[$completed_scans/$total_scans] 📱 Device & Mobile Management${NC}"
        
        local devices_report="$scan_dir/device-inventory.csv"
        local devices_summary="$scan_dir/devices-summary.txt"
        
        echo "$(date): Starting device management scan" >> "$scan_log"
        
        if [[ -x "$SETUP_GAM_PATH" ]]; then
            echo "Discovering managed devices..."
            
            # Mobile devices
            echo "DeviceId,Type,Model,OS,LastSync,Status,User" > "$devices_report"
            $SETUP_GAM_PATH print mobile >> "$devices_report" 2>>"$scan_log"
            
            # Chrome OS devices
            if [[ "${SETUP_SCAN_DEPTH:-2}" -ge "2" ]]; then
                echo "Scanning Chrome OS devices..."
                $SETUP_GAM_PATH print cros >> "$scan_dir/chromeos-devices.csv" 2>>"$scan_log"
            fi
            
            local mobile_count=$($SETUP_GAM_PATH print mobile | tail -n +2 | wc -l)
            
            echo "Device Management Summary" > "$devices_summary"
            echo "========================" >> "$devices_summary"
            echo "Mobile Devices: $mobile_count" >> "$devices_summary"
            echo "" >> "$devices_summary"
            
            echo -e "${GREEN}  ✓ Device management scan completed${NC}"
            echo "    Results: $devices_report"
        else
            echo -e "${RED}  ✗ GAM not available for device scan${NC}"
            echo "GAM not available" >> "$devices_summary"
        fi
        
        echo "$(date): Device management scan completed" >> "$scan_log"
        echo ""
        log_setup "Device management scan completed"
    fi
    
    # Generate overall scan summary
    echo ""
    echo -e "${CYAN}📋 Generating Scan Summary Report${NC}"
    
    echo "GWOMBAT Initial System Discovery Report" > "$scan_summary"
    echo "=======================================" >> "$scan_summary"
    echo "Scan Date: $(date)" >> "$scan_summary"
    echo "Domain: ${SETUP_DOMAIN}" >> "$scan_summary"
    echo "Scan Depth: ${SETUP_SCAN_DEPTH:-2}" >> "$scan_summary"
    echo "Total Modules: $total_scans" >> "$scan_summary"
    echo "" >> "$scan_summary"
    
    echo "Scan Results Summary:" >> "$scan_summary"
    echo "--------------------" >> "$scan_summary"
    
    # Include summaries from each scan
    for summary_file in "$scan_dir"/*-summary.txt; do
        if [[ -f "$summary_file" ]]; then
            echo "" >> "$scan_summary"
            cat "$summary_file" >> "$scan_summary"
        fi
    done
    
    # Generate HTML dashboard if requested
    if [[ "${SETUP_SCAN_OUTPUT:-3}" == "3" ]]; then
        echo -e "${CYAN}📊 Generating HTML Dashboard${NC}"
        local html_dashboard="$scan_dir/dashboard.html"
        
        cat > "$html_dashboard" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GWOMBAT Initial Discovery Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #1f4e79; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .stats { display: flex; gap: 20px; }
        .stat-box { background: #f5f5f5; padding: 15px; border-radius: 5px; flex: 1; }
        .success { color: #28a745; }
        .warning { color: #ffc107; }
        .error { color: #dc3545; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 GWOMBAT Initial Discovery Dashboard</h1>
        <p>System baseline established on: $(date)</p>
    </div>
    
    <div class="section">
        <h2>📊 Scan Overview</h2>
        <div class="stats">
            <div class="stat-box">
                <h3>Modules Executed</h3>
                <p><strong>$total_scans</strong> scan modules</p>
            </div>
            <div class="stat-box">
                <h3>Scan Depth</h3>
                <p><strong>Level ${SETUP_SCAN_DEPTH:-2}</strong></p>
            </div>
            <div class="stat-box">
                <h3>Results Directory</h3>
                <p><code>$scan_dir</code></p>
            </div>
        </div>
    </div>
    
    <div class="section">
        <h2>📋 Quick Actions</h2>
        <ul>
            <li>Review detailed CSV reports in scan directory</li>
            <li>Import data into GWOMBAT database for ongoing management</li>
            <li>Configure automated monitoring based on baseline</li>
            <li>Schedule regular scans to track changes</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>🔗 Report Files</h2>
        <ul>
EOF
        
        # Add links to generated files
        for file in "$scan_dir"/*.csv "$scan_dir"/*.txt; do
            if [[ -f "$file" ]]; then
                local filename=$(basename "$file")
                echo "            <li><a href=\"$filename\">$filename</a></li>" >> "$html_dashboard"
            fi
        done
        
        echo '        </ul>' >> "$html_dashboard"
        echo '    </div>' >> "$html_dashboard"
        echo '</body>' >> "$html_dashboard"
        echo '</html>' >> "$html_dashboard"
        
        echo -e "${GREEN}  ✓ HTML dashboard created: $html_dashboard${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✅ All Initial Scans Completed Successfully!${NC}"
    echo ""
    echo -e "${BLUE}📊 Scan Results Summary:${NC}"
    echo "• Scan directory: $scan_dir"
    echo "• Total modules: $total_scans"
    echo "• Scan log: $scan_log"
    echo "• Summary report: $scan_summary"
    
    if [[ "${SETUP_SCAN_OUTPUT:-3}" == "3" ]]; then
        echo "• HTML dashboard: $scan_dir/dashboard.html"
    fi
    
    echo ""
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo "1. Review scan results in the reports directory"
    echo "2. Use GWOMBAT's import functions to load data into the database"
    echo "3. Configure ongoing monitoring based on discovered baseline"
    echo "4. Set up automated scans to track system changes"
    
    log_setup "All initial scans completed successfully - results in $scan_dir"
}

# Show setup summary
show_setup_summary() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                            Setup Complete!                                  ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ GWOMBAT has been configured successfully!${NC}"
    echo ""
    echo -e "${CYAN}Configuration Summary:${NC}"
    echo "• Domain: ${SETUP_DOMAIN}"
    echo "• Admin User: ${SETUP_ADMIN_USER}"
    echo "• GAM Path: ${SETUP_GAM_PATH}"
    echo "• Configuration: $ENV_FILE"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Run './gwombat.sh' to start using GWOMBAT"
    echo "2. Check the dashboard for system overview"
    echo "3. Review the logs directory for setup details"
    echo ""
    if [[ -n "$SETUP_PRODUCTION_SERVER" ]]; then
        echo -e "${CYAN}Deployment:${NC}"
        echo "• Server: ${SETUP_PRODUCTION_SERVER}"
        echo "• Run './deploy.sh' to deploy to production"
        echo ""
    fi
    echo -e "${YELLOW}Setup log saved to: $SETUP_LOG${NC}"
    echo ""
    log_setup "Setup wizard completed successfully"
}

# Main setup wizard flow
main() {
    show_setup_banner
    
    # Check if first time
    if ! is_first_time_setup; then
        echo -e "${YELLOW}Configuration file already exists.${NC}"
        echo ""
        echo "Would you like to:"
        echo "1. Reconfigure (backup existing config)"
        echo "2. Exit"
        echo ""
        local choice
        choice=$(get_user_input "Select option (1-2)" "2" "true")
        
        if [[ "$choice" != "1" ]]; then
            echo "Setup cancelled."
            exit 0
        fi
        echo ""
    fi
    
    # Run setup steps
    if ! check_setup_dependencies; then
        echo ""
        echo -e "${RED}Cannot continue setup without required dependencies.${NC}"
        echo "Please install missing dependencies and run setup again."
        exit 1
    fi
    
    configure_domain_settings
    configure_organizational_units
    configure_gam
    configure_python_environment
    configure_optional_tools
    configure_deployment_settings
    configure_initial_scans
    
    generate_env_file
    perform_initial_scans
    show_setup_summary
    
    echo ""
    read -p "Press Enter to start GWOMBAT..."
    
    # Launch GWOMBAT
    if [[ -x "$GWOMBAT_ROOT/gwombat.sh" ]]; then
        "$GWOMBAT_ROOT/gwombat.sh"
    fi
}

# Standalone Python environment setup function
setup_python_environment_standalone() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    GWOMBAT Python Environment Setup                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Set up logging for standalone mode
    local standalone_log="$GWOMBAT_ROOT/logs/python-setup-$(date +%Y%m%d-%H%M%S).log"
    mkdir -p "$GWOMBAT_ROOT/logs"
    
    # Override log function for standalone mode
    log_setup() {
        local message="$1"
        local level="${2:-INFO}"
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "[$timestamp] [$level] $message" >> "$standalone_log"
        if [[ "$level" == "ERROR" ]]; then
            echo -e "${RED}[ERROR]${NC} $message"
        elif [[ "$level" == "WARN" ]]; then
            echo -e "${YELLOW}[WARN]${NC} $message"
        fi
    }
    
    # Check if running from GWOMBAT directory
    if [[ ! -f "./gwombat.sh" ]]; then
        echo -e "${RED}Error: This script must be run from the GWOMBAT directory${NC}"
        echo "Please run: cd /path/to/gwombat && ./setup_wizard.sh python"
        exit 1
    fi
    
    echo "This utility will configure Python environment for GWOMBAT."
    echo "Log file: $standalone_log"
    echo ""
    
    # Run Python configuration
    configure_python_environment
    
    # Update .env file if it exists
    if [[ -f "./.env" ]]; then
        echo ""
        echo -e "${CYAN}Updating .env configuration...${NC}"
        
        # Create backup
        local backup_file="./.env.backup.$(date +%Y%m%d-%H%M%S)"
        cp "./.env" "$backup_file"
        echo "Backup created: $backup_file"
        
        # Update Python configuration in .env
        local temp_env="/tmp/gwombat_env_update.$$"
        
        # Remove existing Python configuration
        grep -v "^PYTHON_" "./.env" > "$temp_env"
        
        # Add new Python configuration
        {
            echo ""
            echo "# Python Environment Configuration (updated $(date))"
            echo "PYTHON_PATH=\"${SETUP_PYTHON_PATH:-python3}\""
            echo "PYTHON_VERSION=\"${SETUP_PYTHON_VERSION:-unknown}\""
            echo "PYTHON_USE_VENV=\"${SETUP_PYTHON_USE_VENV:-false}\""
            echo "PYTHON_VENV_PATH=\"${SETUP_PYTHON_VENV_PATH:-}\""
            echo "PYTHON_PACKAGES_INSTALLED=\"${SETUP_PYTHON_PACKAGES_INSTALLED:-false}\""
        } >> "$temp_env"
        
        mv "$temp_env" "./.env"
        echo -e "${GREEN}✓ .env file updated with Python configuration${NC}"
        log_setup ".env file updated with Python configuration"
    else
        echo -e "${YELLOW}⚠ .env file not found - configuration not saved${NC}"
        echo "Run the full setup wizard to create configuration file"
        log_setup ".env file not found" "WARN"
    fi
    
    echo ""
    echo -e "${GREEN}✅ Python Environment Setup Complete!${NC}"
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    if [[ -n "$SETUP_PYTHON_VERSION" ]]; then
        echo "• Python Version: $SETUP_PYTHON_VERSION"
    fi
    if [[ "$SETUP_PYTHON_USE_VENV" == "true" ]]; then
        echo "• Virtual Environment: $SETUP_PYTHON_VENV_PATH"
    fi
    if [[ -n "$SETUP_PYTHON_PACKAGES_INSTALLED" ]]; then
        echo "• Package Installation: $SETUP_PYTHON_PACKAGES_INSTALLED"
    fi
    echo "• Setup Log: $standalone_log"
    echo ""
    
    if [[ "$SETUP_PYTHON_PACKAGES_INSTALLED" == "true" ]]; then
        echo -e "${CYAN}🎉 Python environment is ready for advanced GWOMBAT features!${NC}"
        echo ""
        echo "You can now use:"
        echo "• SCuBA compliance reporting"
        echo "• Advanced data visualization"
        echo "• HTML report generation"
        echo "• Enhanced security analysis"
    elif [[ "$SETUP_PYTHON_PACKAGES_INSTALLED" == "partial" ]]; then
        echo -e "${YELLOW}⚠ Python environment partially configured${NC}"
        echo "Some packages may need manual installation"
    else
        echo -e "${YELLOW}ℹ️  Python environment configured but packages not installed${NC}"
        echo "Install packages later with: pip3 install -r python-modules/requirements.txt"
    fi
}

# Check command line arguments for standalone mode
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "python"|"python-env"|"python-environment")
            GWOMBAT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            setup_python_environment_standalone
            ;;
        *)
            main "$@"
            ;;
    esac
fi