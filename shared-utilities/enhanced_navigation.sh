#!/bin/bash

# Enhanced Navigation System for GWOMBAT Terminal Interface
# Provides improved UX with visual highlighting, keyboard shortcuts, and navigation aids

# Color definitions for enhanced UX
HIGHLIGHT_BG="\033[48;5;237m"    # Dark gray background
HIGHLIGHT_FG="\033[97m"          # Bright white text
SELECTED_ARROW="\033[92m▶\033[0m" # Green arrow indicator
MENU_BORDER="\033[38;5;239m"     # Gray border
ACCENT_BLUE="\033[94m"
ACCENT_GREEN="\033[92m" 
ACCENT_YELLOW="\033[93m"
ACCENT_CYAN="\033[96m"
ACCENT_PURPLE="\033[95m"

# Enhanced menu display function with visual improvements
enhanced_menu_display() {
    local menu_title="$1"
    local -a menu_items=("${@:2}")
    
    clear
    
    # Enhanced header with borders
    echo -e "${MENU_BORDER}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${ACCENT_GREEN}                              ${menu_title}${NC}"
    echo -e "${MENU_BORDER}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Display menu items with enhanced formatting
    local item_num=1
    for item in "${menu_items[@]}"; do
        if [[ -n "$item" ]]; then
            echo -e "  ${ACCENT_CYAN}${item_num}.${NC} ${item}"
            ((item_num++))
        fi
    done
}

# Enhanced input prompt with keyboard shortcuts help
enhanced_input_prompt() {
    local max_option="$1"
    local show_help="${2:-true}"
    
    echo ""
    if [[ "$show_help" == "true" ]]; then
        echo -e "${MENU_BORDER}─────────────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "${ACCENT_YELLOW}⌨️  Navigation:${NC} ${ACCENT_CYAN}1-${max_option}${NC} Select option | ${ACCENT_CYAN}s${NC} Search | ${ACCENT_CYAN}m${NC} Main | ${ACCENT_CYAN}p${NC} Previous | ${ACCENT_CYAN}x${NC} Exit"
        if command -v fzf >/dev/null 2>&1; then
            echo -e "${ACCENT_PURPLE}🚀 Power User:${NC} ${ACCENT_CYAN}f${NC} Fuzzy search (fzf) | ${ACCENT_CYAN}?${NC} Help"
        fi
        echo -e "${MENU_BORDER}─────────────────────────────────────────────────────────────────────────────────${NC}"
    fi
    echo ""
    echo -ne "${ACCENT_GREEN}❯${NC} "
    read user_choice
    echo "$user_choice"
}

# Progress indicator for long-running operations
show_progress() {
    local message="$1"
    local duration="${2:-3}"
    
    echo -ne "${ACCENT_YELLOW}${message}${NC} "
    for ((i=0; i<duration; i++)); do
        echo -ne "${ACCENT_GREEN}▶${NC}"
        sleep 0.5
        echo -ne "${ACCENT_CYAN}▶${NC}"  
        sleep 0.5
    done
    echo ""
}

# Spinner for operations with unknown duration
show_spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    echo -ne "${ACCENT_YELLOW}${message}${NC} "
    
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 $((${#spin} - 1))); do
            echo -ne "${ACCENT_CYAN}${spin:$i:1}${NC}"
            sleep 0.1
            echo -ne "\b"
        done
    done
    echo -e "${ACCENT_GREEN}✓${NC}"
}

# Enhanced error display
show_enhanced_error() {
    local error_msg="$1"
    local suggestion="${2:-}"
    
    echo ""
    echo -e "${RED}❌ ${error_msg}${NC}"
    if [[ -n "$suggestion" ]]; then
        echo -e "${ACCENT_YELLOW}💡 Suggestion: ${suggestion}${NC}"
    fi
    echo ""
}

# Enhanced success display
show_enhanced_success() {
    local success_msg="$1"
    
    echo ""
    echo -e "${ACCENT_GREEN}✅ ${success_msg}${NC}"
    echo ""
}

# Fuzzy search integration (if fzf is available)
fuzzy_search_menu() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  fzf not installed. Install with: brew install fzf${NC}"
        return 1
    fi
    
    # Get all menu options from database
    local search_results
    search_results=$(sqlite3 shared-config/menu.db "
        SELECT DISTINCT 
            ms.display_name || ' → ' || mi.display_name || ' (' || mi.description || ')'
        FROM menu_items mi 
        JOIN menu_sections ms ON mi.section_id = ms.id 
        WHERE mi.is_active = 1 AND ms.is_active = 1
        ORDER BY ms.section_order, mi.item_order;
    " 2>/dev/null | fzf --prompt="🔍 GWOMBAT Menu Search ❯ " \
        --header="Use ↑↓ arrows, type to search, Enter to select" \
        --border=rounded \
        --height=40% \
        --preview-window=hidden \
        --color="fg:#ffffff,bg:#1e1e1e,hl:#00ff87,fg+:#ffffff,bg+:#444444,hl+:#00ff87" \
        --info=inline)
    
    if [[ -n "$search_results" ]]; then
        echo "Selected: $search_results"
        echo "Feature integration with menu system coming soon..."
        read -p "Press Enter to continue..."
    fi
}

# Context-sensitive help system
show_context_help() {
    local context="$1"
    
    case "$context" in
        "main")
            echo -e "${ACCENT_CYAN}📖 GWOMBAT Main Menu Help${NC}"
            echo ""
            echo "Navigation Options:"
            echo "• Numbers 1-9: Select menu sections"
            echo "• 's': Search all menu options"
            echo "• 'i': Show alphabetical index"
            echo "• 'c': Configuration management"
            echo "• 'x': Exit application"
            ;;
        "submenu")
            echo -e "${ACCENT_CYAN}📖 Submenu Navigation Help${NC}"
            echo ""
            echo "Navigation Options:"
            echo "• Numbers: Select specific operations"
            echo "• 'p': Previous menu (back)"
            echo "• 'm': Return to main menu"
            echo "• 's': Search all options"
            echo "• 'x': Exit application"
            ;;
        "search")
            echo -e "${ACCENT_CYAN}📖 Search System Help${NC}"
            echo ""
            echo "Search Features:"
            echo "• Enter keywords to find matching options"
            echo "• Search across all menu items and descriptions"
            echo "• Leave empty to see all options"
            echo "• Type 'exit' to return to previous menu"
            ;;
        *)
            echo -e "${ACCENT_CYAN}📖 GWOMBAT Help System${NC}"
            echo ""
            echo "Available commands in most menus:"
            echo "• 's': Search functionality"
            echo "• 'm': Main menu"
            echo "• 'p': Previous menu"
            echo "• 'x': Exit"
            echo "• '?': Context help"
            ;;
    esac
    echo ""
    read -p "Press Enter to continue..."
}

# Enhanced confirmation dialog
enhanced_confirmation() {
    local message="$1"
    local default="${2:-n}"
    
    echo ""
    echo -e "${ACCENT_YELLOW}🔔 ${message}${NC}"
    
    if [[ "$default" == "y" ]]; then
        echo -ne "${ACCENT_GREEN}Continue? [Y/n]:${NC} "
    else
        echo -ne "${ACCENT_GREEN}Continue? [y/N]:${NC} "
    fi
    
    read -r response
    case "$response" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        [Nn]|[Nn][Oo]) return 1 ;;
        "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
        *) return 1 ;;
    esac
}

# Status indicator for system health
show_system_status() {
    local gam_status="❌"
    local db_status="❌" 
    local config_status="❌"
    
    # Quick health checks
    if command -v gam >/dev/null 2>&1 && gam version >/dev/null 2>&1; then
        gam_status="✅"
    fi
    
    if [[ -f "shared-config/menu.db" ]] && sqlite3 shared-config/menu.db "SELECT 1;" >/dev/null 2>&1; then
        db_status="✅"
    fi
    
    if [[ -f "local-config/.env" ]] && [[ -n "$DOMAIN" ]]; then
        config_status="✅"
    fi
    
    echo -e "${MENU_BORDER}─ System Status: ${NC}GAM:${gam_status} Database:${db_status} Config:${config_status} ${MENU_BORDER}─${NC}"
}

# Export functions for use in main script
export -f enhanced_menu_display
export -f enhanced_input_prompt
export -f show_progress
export -f show_spinner
export -f show_enhanced_error
export -f show_enhanced_success
export -f fuzzy_search_menu
export -f show_context_help
export -f enhanced_confirmation
export -f show_system_status