#!/bin/bash
# GWOMBAT Enhanced Hierarchical Menu System with Arrow Key Navigation
# Modern terminal interface with visual highlighting and keyboard navigation

# Source base hierarchical system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/hierarchical_menu_system.sh"

# Enhanced navigation state
SELECTED_ITEM=1
TOTAL_ITEMS=0
MENU_ITEMS_ARRAY=""
MENU_TYPES_ARRAY=""
MENU_FUNCTIONS_ARRAY=""

# ANSI escape codes for enhanced display
ESC=$'\033'
CURSOR_UP="${ESC}[A"
CURSOR_DOWN="${ESC}[B"
CURSOR_RIGHT="${ESC}[C"
CURSOR_LEFT="${ESC}[D"
CLEAR_LINE="${ESC}[2K"
CURSOR_HOME="${ESC}[H"
SAVE_CURSOR="${ESC}[s"
RESTORE_CURSOR="${ESC}[u"

# Colors for highlighting
HIGHLIGHT_BG='\033[44m'  # Blue background
HIGHLIGHT_FG='\033[97m'  # Bright white text
NORMAL_FG='\033[37m'     # Normal white text
DIM_FG='\033[90m'        # Dim text

# Enhanced universal menu renderer with arrow key support
render_menu_enhanced() {
    local menu_identifier="$1"
    local menu_id=""
    local menu_info=""
    
    # Reset selection state
    SELECTED_ITEM=1
    TOTAL_ITEMS=0
    
    # Resolve menu ID (same as original)
    if [[ "$menu_identifier" =~ ^[0-9]+$ ]]; then
        menu_id="$menu_identifier"
    else
        menu_id=$(sqlite3 "$MENU_DB" "SELECT id FROM menu_items_v2 WHERE name = '$menu_identifier' AND item_type = 'menu' LIMIT 1;" 2>/dev/null)
    fi
    
    if [[ -z "$menu_identifier" || "$menu_identifier" == "root" || "$menu_identifier" == "main" ]]; then
        menu_id="NULL"
    fi
    
    # Get menu info
    if [[ "$menu_id" == "NULL" ]]; then
        menu_info="root|Main Menu|GWOMBAT Main Menu|🏠|BLUE"
    else
        menu_info=$(sqlite3 "$MENU_DB" "SELECT id, display_name, description, icon, color_code FROM menu_items_v2 WHERE id = $menu_id;" 2>/dev/null)
    fi
    
    if [[ -z "$menu_info" && "$menu_id" != "NULL" ]]; then
        echo -e "${RED}Error: Menu not found (ID: $menu_identifier)${NC}"
        return 1
    fi
    
    # Parse menu info
    IFS='|' read -r actual_id display_name description icon color_code <<< "$menu_info"
    CURRENT_MENU_ID="$actual_id"
    
    # Load menu items into arrays
    load_menu_items "$menu_id"
    
    # Enter enhanced navigation mode
    enhanced_navigation_loop "$display_name" "$description" "$color_code"
}

# Load menu items into arrays for navigation
load_menu_items() {
    local menu_id="$1"
    
    # Clear arrays (bash 3.2 compatible)
    MENU_ITEMS_ARRAY=""
    MENU_TYPES_ARRAY=""
    MENU_FUNCTIONS_ARRAY=""
    TOTAL_ITEMS=0
    
    # Get menu items
    local items_query=""
    if [[ "$menu_id" == "NULL" ]]; then
        items_query="SELECT id, name, display_name, description, icon, item_type, function_name, sort_order 
                     FROM menu_items_v2 
                     WHERE parent_id IS NULL AND is_active = 1 AND is_visible = 1 
                     ORDER BY sort_order, display_name;"
    else
        items_query="SELECT id, name, display_name, description, icon, item_type, function_name, sort_order 
                     FROM menu_items_v2 
                     WHERE parent_id = $menu_id AND is_active = 1 AND is_visible = 1 
                     ORDER BY sort_order, display_name;"
    fi
    
    # Load items into space-separated strings (bash 3.2 compatible)
    local item_count=0
    while IFS='|' read -r item_id item_name item_display item_desc item_icon item_type item_function sort_order; do
        [[ -z "$item_id" ]] && continue
        
        ((item_count++))
        
        # Store in space-separated format: id:type:function:display
        MENU_ITEMS_ARRAY="$MENU_ITEMS_ARRAY $item_id:$item_type:$item_function:$item_display"
        
    done < <(sqlite3 "$MENU_DB" "$items_query")
    
    TOTAL_ITEMS=$item_count
}

# Enhanced navigation loop with arrow key support
enhanced_navigation_loop() {
    local display_name="$1"
    local description="$2" 
    local color_code="$3"
    
    # Enable raw mode for arrow key detection
    stty -echo -icanon min 1 time 0 2>/dev/null
    
    while true; do
        # Display menu
        display_enhanced_menu "$display_name" "$description" "$color_code"
        
        # Read single character
        local key=""
        read -r -n1 key 2>/dev/null
        
        # Handle escape sequences (arrow keys)
        if [[ "$key" == $'\033' ]]; then
            read -r -n2 key 2>/dev/null
            case "$key" in
                '[A') # Up arrow
                    ((SELECTED_ITEM--))
                    if [[ $SELECTED_ITEM -lt 1 ]]; then
                        SELECTED_ITEM=$TOTAL_ITEMS
                    fi
                    ;;
                '[B') # Down arrow
                    ((SELECTED_ITEM++))
                    if [[ $SELECTED_ITEM -gt $TOTAL_ITEMS ]]; then
                        SELECTED_ITEM=1
                    fi
                    ;;
                '[C') # Right arrow - Enter submenu
                    handle_enhanced_selection
                    break
                    ;;
                '[D') # Left arrow - Go back
                    handle_back_navigation
                    break
                    ;;
            esac
        else
            # Handle regular keys
            case "$key" in
                $'\n'|$'\r') # Enter key
                    handle_enhanced_selection
                    break
                    ;;
                [1-9]) # Number keys
                    if [[ $key -le $TOTAL_ITEMS ]]; then
                        SELECTED_ITEM=$key
                        handle_enhanced_selection
                        break
                    fi
                    ;;
                'b'|'B') # Back
                    handle_back_navigation
                    break
                    ;;
                'm'|'M') # Main menu
                    MENU_HISTORY=""
                    stty echo icanon 2>/dev/null
                    render_menu_enhanced "root"
                    return
                    ;;
                's'|'S') # Search
                    stty echo icanon 2>/dev/null
                    search_hierarchical_menus
                    stty -echo -icanon min 1 time 0 2>/dev/null
                    ;;
                'i'|'I') # Index
                    stty echo icanon 2>/dev/null
                    show_hierarchical_menu_index
                    stty -echo -icanon min 1 time 0 2>/dev/null
                    ;;
                '?'|'h'|'H') # Help
                    stty echo icanon 2>/dev/null
                    show_enhanced_help
                    stty -echo -icanon min 1 time 0 2>/dev/null
                    ;;
                'x'|'X'|'q'|'Q') # Exit
                    stty echo icanon 2>/dev/null
                    echo -e "\n${BLUE}Goodbye!${NC}"
                    exit 0
                    ;;
                *) # Invalid key - brief flash
                    tput flash 2>/dev/null || echo -ne "\a"
                    ;;
            esac
        fi
    done
    
    # Restore terminal
    stty echo icanon 2>/dev/null
}

# Display enhanced menu with highlighting
display_enhanced_menu() {
    local display_name="$1"
    local description="$2"
    local color_code="$3"
    
    # Clear screen and position cursor
    clear
    
    # Header with color
    local header_color="${!color_code:-$BLUE}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${header_color}                         GWOMBAT - ${display_name}                              ${NC}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    # Breadcrumb
    echo -e "${WHITE}📍 ${MENU_BREADCRUMB:-Main Menu}${NC}"
    echo ""
    
    # Description
    if [[ -n "$description" && "$description" != "NULL" ]]; then
        echo -e "${CYAN}${description}${NC}"
        echo ""
    fi
    
    # Display menu items with highlighting
    local item_num=1
    for item_data in $MENU_ITEMS_ARRAY; do
        [[ -z "$item_data" ]] && continue
        
        IFS=':' read -r item_id item_type item_function item_display <<< "$item_data"
        
        # Highlight selected item
        if [[ $item_num -eq $SELECTED_ITEM ]]; then
            echo -e "${HIGHLIGHT_BG}${HIGHLIGHT_FG} ▶ ${item_num}. ${item_display} ${NC}"
        else
            echo -e "${NORMAL_FG}   ${item_num}. ${item_display}${NC}"
        fi
        
        ((item_num++))
    done
    
    # Show if no items
    if [[ $TOTAL_ITEMS -eq 0 ]]; then
        echo -e "${YELLOW}No menu items available${NC}"
    fi
    
    echo ""
    
    # Navigation help
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${DIM_FG}Navigation: ↑↓ move • Enter/→ select • ← back • s search • m main • x exit${NC}"
    echo -e "${DIM_FG}Selected: ${SELECTED_ITEM}/${TOTAL_ITEMS}${NC}"
    echo ""
}

# Handle selection in enhanced mode
handle_enhanced_selection() {
    if [[ $SELECTED_ITEM -le $TOTAL_ITEMS && $SELECTED_ITEM -ge 1 ]]; then
        # Get selected item info
        local item_data=$(echo $MENU_ITEMS_ARRAY | cut -d' ' -f$SELECTED_ITEM)
        IFS=':' read -r item_id item_type item_function item_display <<< "$item_data"
        
        # Restore terminal before executing
        stty echo icanon 2>/dev/null
        
        case "$item_type" in
            "menu")
                # Add current menu to history
                MENU_HISTORY="$MENU_HISTORY $CURRENT_MENU_ID"
                # Update breadcrumb
                if [[ -z "$MENU_BREADCRUMB" || "$MENU_BREADCRUMB" == "Main Menu" ]]; then
                    MENU_BREADCRUMB="$item_display"
                else
                    MENU_BREADCRUMB="$MENU_BREADCRUMB > $item_display"
                fi
                render_menu_enhanced "$item_id"
                ;;
            "action")
                # Execute function
                clear
                echo -e "${CYAN}Executing: $item_display${NC}"
                echo ""
                
                if [[ -n "$item_function" ]]; then
                    execute_menu_function "$item_function"
                else
                    echo -e "${RED}No function defined for this action${NC}"
                    read -p "Press Enter to continue..."
                fi
                
                # Return to current menu
                render_menu_enhanced "$CURRENT_MENU_ID"
                ;;
        esac
    fi
}

# Handle back navigation in enhanced mode
handle_back_navigation() {
    stty echo icanon 2>/dev/null
    
    if [[ -n "$MENU_HISTORY" ]]; then
        # Get last item from history
        local prev_menu="${MENU_HISTORY##* }"
        MENU_HISTORY="${MENU_HISTORY% *}"
        
        # Update breadcrumb
        if [[ "$prev_menu" == "NULL" || -z "$prev_menu" ]]; then
            MENU_BREADCRUMB="Main Menu"
        else
            # Rebuild breadcrumb from database
            MENU_BREADCRUMB=$(sqlite3 "$MENU_DB" "SELECT path FROM v_menu_hierarchy WHERE id = $prev_menu;" 2>/dev/null)
            if [[ -z "$MENU_BREADCRUMB" ]]; then
                MENU_BREADCRUMB="Main Menu"
            fi
        fi
        
        render_menu_enhanced "$prev_menu"
    else
        # Already at root
        echo -e "\n${YELLOW}Already at main menu${NC}"
        sleep 1
        render_menu_enhanced "$CURRENT_MENU_ID"
    fi
}

# Display enhanced menu with highlighting
display_enhanced_menu() {
    local display_name="$1"
    local description="$2"
    local color_code="$3"
    
    # Clear screen
    clear
    
    # Header
    local header_color="${!color_code:-$BLUE}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${header_color}                         GWOMBAT - ${display_name}                              ${NC}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    # Breadcrumb
    echo -e "${WHITE}📍 ${MENU_BREADCRUMB:-Main Menu}${NC}"
    echo ""
    
    # Description
    if [[ -n "$description" && "$description" != "NULL" ]]; then
        echo -e "${CYAN}${description}${NC}"
        echo ""
    fi
    
    # Display menu items with highlighting
    local item_num=1
    for item_data in $MENU_ITEMS_ARRAY; do
        [[ -z "$item_data" ]] && continue
        
        IFS=':' read -r item_id item_type item_function item_display <<< "$item_data"
        
        # Highlight selected item
        if [[ $item_num -eq $SELECTED_ITEM ]]; then
            echo -e "${HIGHLIGHT_BG}${HIGHLIGHT_FG} ▶ ${item_num}. ${item_display} ${NC}"
        else
            echo -e "${NORMAL_FG}   ${item_num}. ${item_display}${NC}"
        fi
        
        ((item_num++))
    done
    
    # Show if no items
    if [[ $TOTAL_ITEMS -eq 0 ]]; then
        echo -e "${YELLOW}No menu items available${NC}"
    fi
    
    echo ""
    
    # Navigation help
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${DIM_FG}↑↓ move • Enter/→ select • ← back • s search • m main • x exit • ? help${NC}"
    echo -e "${DIM_FG}Selection: ${SELECTED_ITEM}/${TOTAL_ITEMS}${NC}"
}

# Enhanced help with arrow key information
show_enhanced_help() {
    clear
    echo -e "${BLUE}=== GWOMBAT Enhanced Navigation Help ===${NC}"
    echo ""
    echo -e "${CYAN}Arrow Key Navigation:${NC}"
    echo "• ↑ ↓ - Move selection up/down"
    echo "• → Enter - Select highlighted item"
    echo "• ← - Go back to previous menu"
    echo ""
    echo -e "${CYAN}Keyboard Shortcuts:${NC}"
    echo "• 1-9 - Direct selection by number"
    echo "• b - Back to previous menu"
    echo "• m - Return to main menu"
    echo "• s - Search all menus"
    echo "• i - Show menu index"
    echo "• ? or h - Show this help"
    echo "• x or q - Exit GWOMBAT"
    echo ""
    echo -e "${CYAN}Visual Cues:${NC}"
    echo "• Blue highlighted line shows current selection"
    echo "• Breadcrumb shows your current location"
    echo "• Status bar shows current position (X/Y)"
    echo ""
    echo -e "${CYAN}Tips:${NC}"
    echo "• Use arrow keys for smooth navigation"
    echo "• Number keys work for quick access"
    echo "• All existing shortcuts still work"
    echo ""
    read -p "Press Enter to continue..."
}

# Initialize enhanced menu system
init_enhanced_hierarchical_menu() {
    # Reset state
    CURRENT_MENU_ID=""
    MENU_HISTORY=""
    MENU_BREADCRUMB="Main Menu"
    SELECTED_ITEM=1
    
    # Check terminal capabilities
    if [[ ! -t 0 ]]; then
        echo -e "${YELLOW}Non-interactive mode detected. Using standard menu system.${NC}"
        init_hierarchical_menu
        return
    fi
    
    # Check if terminal supports enhanced features
    if ! command -v stty >/dev/null 2>&1; then
        echo -e "${YELLOW}Enhanced navigation not available. Using standard menu system.${NC}"
        init_hierarchical_menu
        return
    fi
    
    echo -e "${GREEN}🚀 Enhanced Navigation Enabled${NC}"
    echo -e "${GRAY}Use arrow keys to navigate, Enter to select${NC}"
    echo ""
    sleep 1
    
    # Start at root menu with enhanced navigation
    render_menu_enhanced "root"
}

# Override the original render_menu to use enhanced version
render_menu() {
    render_menu_enhanced "$@"
}

# Override the original init function
init_hierarchical_menu() {
    init_enhanced_hierarchical_menu
}

# Export enhanced functions
export -f render_menu_enhanced
export -f init_enhanced_hierarchical_menu
export -f enhanced_navigation_loop