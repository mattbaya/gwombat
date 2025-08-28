#!/bin/bash

# Enhanced Main Menu Demo for GWOMBAT
# Demonstrates improved terminal UX and navigation features

# Source the enhanced navigation utilities
source "$(dirname "${BASH_SOURCE[0]}")/shared-utilities/enhanced_navigation.sh"

# Source existing configuration
if [[ -f "local-config/.env" ]]; then
    source "local-config/.env"
fi

# Initialize colors (from existing gwombat.sh)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m' 
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;37m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' GRAY='' BOLD='' NC=''
fi

enhanced_main_menu_demo() {
    while true; do
        # Enhanced header display
        enhanced_menu_display "GWOMBAT - Enhanced Terminal Interface Demo" \
            "👥 User & Group Management" \
            "💾 File & Drive Operations" \
            "🔍 Analysis & Discovery" \
            "📋 Account List Management" \
            "🎯 Dashboard & Statistics" \
            "📈 Reports & Monitoring" \
            "⚙️  System Administration" \
            "🔐 SCuBA Compliance Management" \
            "⚙️  Configuration Management"
        
        echo ""
        show_system_status
        echo ""
        
        # Enhanced input with help
        choice=$(enhanced_input_prompt 9)
        
        case $choice in
            1)
                show_progress "Loading User & Group Management" 2
                show_enhanced_success "User & Group Management loaded successfully!"
                echo "This would normally load the User & Group Management menu..."
                read -p "Press Enter to continue..."
                ;;
            2)
                show_progress "Initializing File & Drive Operations" 3
                show_enhanced_success "File & Drive Operations ready!"
                read -p "Press Enter to continue..."
                ;;
            3)
                show_enhanced_success "Analysis & Discovery tools activated!"
                read -p "Press Enter to continue..."
                ;;
            4|5|6|7|8)
                show_progress "Loading menu section" 2
                show_enhanced_success "Menu section $choice loaded!"
                read -p "Press Enter to continue..."
                ;;
            9|c)
                show_enhanced_success "Configuration Management loaded!"
                read -p "Press Enter to continue..."
                ;;
            s)
                echo ""
                echo -e "${ACCENT_CYAN}🔍 Enhanced Search Features:${NC}"
                echo "1. Database search (current functionality)"
                echo "2. Fuzzy search with fzf (if available)" 
                echo ""
                read -p "Select search type (1-2): " search_type
                case $search_type in
                    1)
                        echo "Loading database search..."
                        show_progress "Searching menu database" 2
                        ;;
                    2)
                        fuzzy_search_menu
                        ;;
                esac
                ;;
            f)
                if command -v fzf >/dev/null 2>&1; then
                    fuzzy_search_menu
                else
                    show_enhanced_error "fzf not available" "Install with: brew install fzf"
                    read -p "Press Enter to continue..."
                fi
                ;;
            i)
                show_progress "Building alphabetical index" 2
                show_enhanced_success "Index ready - this would show the menu index"
                read -p "Press Enter to continue..."
                ;;
            "?"|help)
                show_context_help "main"
                ;;
            test)
                echo ""
                echo -e "${ACCENT_PURPLE}🧪 Testing Enhanced Features:${NC}"
                echo ""
                
                # Test confirmation dialog
                if enhanced_confirmation "Test the enhanced confirmation dialog?"; then
                    show_enhanced_success "Confirmation dialog works!"
                else
                    show_enhanced_error "Confirmation declined" "You chose not to proceed"
                fi
                
                # Test progress indicators
                echo ""
                echo "Testing progress indicators..."
                show_progress "Processing test data" 3
                show_enhanced_success "Progress indicators working!"
                
                # Test spinner (simulate background task)
                echo ""
                echo "Testing spinner..."
                (sleep 3) &
                show_spinner $! "Running background process"
                show_enhanced_success "Spinner test complete!"
                
                read -p "Press Enter to continue..."
                ;;
            x|exit|quit)
                if enhanced_confirmation "Exit GWOMBAT Enhanced Demo?"; then
                    echo ""
                    show_enhanced_success "Thank you for trying the enhanced interface!"
                    echo ""
                    exit 0
                fi
                ;;
            "")
                # Handle empty input gracefully
                ;;
            *)
                show_enhanced_error "Invalid option: '$choice'" "Use numbers 1-9, or letters s, i, f, ?, x"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Show demo information
show_demo_info() {
    clear
    echo -e "${ACCENT_GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${ACCENT_GREEN}                     GWOMBAT Enhanced Terminal Interface Demo                   ${NC}"
    echo -e "${ACCENT_GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${ACCENT_CYAN}✨ New Features Demonstrated:${NC}"
    echo ""
    echo -e "🎨 ${ACCENT_YELLOW}Visual Enhancements:${NC}"
    echo "   • Enhanced menu borders and colors"
    echo "   • Improved status indicators (✅/❌)"
    echo "   • Progress bars and spinners"
    echo "   • Better error and success messages"
    echo ""
    echo -e "⌨️  ${ACCENT_YELLOW}Enhanced Navigation:${NC}"
    echo "   • Contextual help with '?' command"
    echo "   • Enhanced search options ('s' and 'f')"
    echo "   • System status display"
    echo "   • Better confirmation dialogs"
    echo ""
    echo -e "🚀 ${ACCENT_YELLOW}Power User Features:${NC}"
    echo "   • Fuzzy search with fzf (if installed: brew install fzf)"
    echo "   • Hidden 'test' command to demo features"
    echo "   • Enhanced keyboard shortcuts"
    echo ""
    echo -e "${ACCENT_PURPLE}💡 Try these commands:${NC}"
    echo "   • Normal numbers 1-9 for menu sections"
    echo "   • 's' for search, 'f' for fuzzy search"
    echo "   • '?' for help, 'test' for feature demo"
    echo "   • 'x' to exit with confirmation"
    echo ""
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "${ACCENT_YELLOW}📦 Optional Enhancement:${NC}"
        echo "   Install fzf for fuzzy search: ${ACCENT_CYAN}brew install fzf${NC}"
        echo ""
    fi
    
    read -p "Press Enter to start the enhanced demo..."
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_demo_info
    enhanced_main_menu_demo
fi