#!/bin/bash
# GWOMBAT Hierarchical Menu System
# Universal menu renderer that replaces all hardcoded menu functions

# Source required files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/database_functions.sh" 2>/dev/null

# Menu database path
MENU_DB="${MENU_DB:-$SCRIPT_DIR/../shared-config/menu.db}"

# Global variables for menu state (bash 3.2 compatible)
CURRENT_MENU_ID=""
MENU_HISTORY=""  # Space-separated list for bash 3.2 compatibility
MENU_BREADCRUMB=""

# Universal menu renderer - displays any menu by ID or name
render_menu() {
    local menu_identifier="$1"  # Can be numeric ID or text name
    local menu_id=""
    local menu_info=""
    
    # Resolve menu ID from identifier
    if [[ "$menu_identifier" =~ ^[0-9]+$ ]]; then
        menu_id="$menu_identifier"
    else
        # Look up by name
        menu_id=$(sqlite3 "$MENU_DB" "SELECT id FROM menu_items_v2 WHERE name = '$menu_identifier' AND item_type = 'menu' LIMIT 1;" 2>/dev/null)
    fi
    
    # Handle root menu (NULL parent)
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
    
    # Update current menu ID
    CURRENT_MENU_ID="$actual_id"
    
    # Clear screen and display header
    clear
    
    # Display header with color
    local header_color="${!color_code:-$BLUE}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${header_color}                         GWOMBAT - ${display_name}                              ${NC}"
    echo -e "${header_color}═══════════════════════════════════════════════════════════════════════════════${NC}"
    
    # Display breadcrumb
    display_breadcrumb
    
    # Display description if available
    if [[ -n "$description" && "$description" != "NULL" ]]; then
        echo -e "${CYAN}${description}${NC}"
    fi
    echo ""
    
    # Get and display menu items
    local items_query=""
    if [[ "$menu_id" == "NULL" ]]; then
        # Root menu - show items with NULL parent
        items_query="SELECT id, name, display_name, description, icon, item_type, function_name, sort_order 
                     FROM menu_items_v2 
                     WHERE parent_id IS NULL AND is_active = 1 AND is_visible = 1 
                     ORDER BY sort_order, display_name;"
    else
        # Submenu - show children
        items_query="SELECT id, name, display_name, description, icon, item_type, function_name, sort_order 
                     FROM menu_items_v2 
                     WHERE parent_id = $menu_id AND is_active = 1 AND is_visible = 1 
                     ORDER BY sort_order, display_name;"
    fi
    
    # Store menu items for selection
    local -a menu_items=()
    local -a menu_types=()
    local -a menu_functions=()
    local item_count=0
    local display_num=1
    
    # Display menu items
    while IFS='|' read -r item_id item_name item_display item_desc item_icon item_type item_function sort_order; do
        [[ -z "$item_id" ]] && continue
        
        # Store item info
        menu_items[$display_num]="$item_id"
        menu_types[$display_num]="$item_type"
        menu_functions[$display_num]="$item_function"
        
        # Display item
        if [[ "$item_type" == "separator" ]]; then
            echo -e "${GRAY}───────────────────────────────────────${NC}"
        else
            echo -e "${display_num}. ${item_icon} ${item_display}"
            if [[ -n "$item_desc" && "${SHOW_DESCRIPTIONS:-1}" == "1" ]]; then
                echo -e "   ${GRAY}${item_desc}${NC}"
            fi
        fi
        
        ((display_num++))
        ((item_count++))
    done < <(sqlite3 "$MENU_DB" "$items_query")
    
    # If no items, show message
    if [[ $item_count -eq 0 ]]; then
        echo -e "${YELLOW}No menu items available${NC}"
        echo ""
    fi
    
    # Display navigation options
    echo ""
    display_navigation_options "$menu_id"
    echo ""
    
    # Get user choice
    local choice=""
    read -p "Select an option: " choice
    echo ""
    
    # Handle choice
    handle_menu_choice "$choice" "${menu_items[@]}" "${menu_types[@]}" "${menu_functions[@]}"
}

# Display breadcrumb navigation path
display_breadcrumb() {
    local breadcrumb=""
    
    if [[ "$CURRENT_MENU_ID" == "NULL" || -z "$CURRENT_MENU_ID" ]]; then
        breadcrumb="Main Menu"
    else
        # Get full path from database view
        breadcrumb=$(sqlite3 "$MENU_DB" "SELECT path FROM v_menu_hierarchy WHERE id = $CURRENT_MENU_ID;" 2>/dev/null)
        
        if [[ -z "$breadcrumb" ]]; then
            breadcrumb="Main Menu"
        fi
    fi
    
    MENU_BREADCRUMB="$breadcrumb"
    echo -e "${WHITE}📍 $breadcrumb${NC}"
    echo ""
}

# Display navigation options based on context
display_navigation_options() {
    local current_menu="$1"
    
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Show global shortcuts
    sqlite3 "$MENU_DB" "SELECT key_char, icon, display_name FROM menu_shortcuts WHERE is_active = 1 ORDER BY sort_order;" | while IFS='|' read -r key icon name; do
        # Skip 'back' option if at root
        if [[ "$key" == "b" && ("$current_menu" == "NULL" || -z "$current_menu") ]]; then
            continue
        fi
        echo -e "${key}. ${icon} ${name}"
    done
}

# Handle user menu choice
handle_menu_choice() {
    local choice="$1"
    shift
    local -a menu_items=("$@")
    shift $#
    local -a menu_types=("$@")
    shift $#
    local -a menu_functions=("$@")
    
    # Handle numeric choices
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local item_id="${menu_items[$choice]}"
        local item_type="${menu_types[$choice]}"
        local item_function="${menu_functions[$choice]}"
        
        if [[ -n "$item_id" ]]; then
            case "$item_type" in
                "menu")
                    # Add current menu to history (bash 3.2 compatible)
                    MENU_HISTORY="$MENU_HISTORY $CURRENT_MENU_ID"
                    # Render submenu
                    render_menu "$item_id"
                    ;;
                "action")
                    # Execute function
                    if [[ -n "$item_function" ]]; then
                        execute_menu_function "$item_function"
                    else
                        echo -e "${RED}No function defined for this action${NC}"
                        read -p "Press Enter to continue..."
                    fi
                    # Re-render current menu
                    render_menu "$CURRENT_MENU_ID"
                    ;;
            esac
        else
            echo -e "${RED}Invalid selection${NC}"
            read -p "Press Enter to continue..."
            render_menu "$CURRENT_MENU_ID"
        fi
        return
    fi
    
    # Handle navigation shortcuts
    case "${choice,,}" in
        b|back)
            # Go back to previous menu (bash 3.2 compatible)
            if [[ -n "$MENU_HISTORY" ]]; then
                # Get last item from space-separated history
                local prev_menu="${MENU_HISTORY##* }"
                # Remove last item from history
                MENU_HISTORY="${MENU_HISTORY% *}"
                render_menu "$prev_menu"
            else
                # At root, can't go back
                echo -e "${YELLOW}Already at main menu${NC}"
                read -p "Press Enter to continue..."
                render_menu "$CURRENT_MENU_ID"
            fi
            ;;
        m|main)
            # Go to main menu (bash 3.2 compatible)
            MENU_HISTORY=""
            render_menu "root"
            ;;
        s|search)
            # Search menu items
            search_hierarchical_menus
            render_menu "$CURRENT_MENU_ID"
            ;;
        i|index)
            # Show menu index
            show_hierarchical_menu_index
            render_menu "$CURRENT_MENU_ID"
            ;;
        "?"|h|help)
            # Show help
            show_menu_help
            render_menu "$CURRENT_MENU_ID"
            ;;
        x|exit|quit)
            # Exit
            echo -e "${BLUE}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option: $choice${NC}"
            read -p "Press Enter to continue..."
            render_menu "$CURRENT_MENU_ID"
            ;;
    esac
}

# Execute a menu function
execute_menu_function() {
    local function_name="$1"
    
    # Check if function exists
    if type -t "$function_name" >/dev/null 2>&1; then
        # Function exists, call it
        "$function_name"
    else
        # Try common function patterns
        case "$function_name" in
            *_menu)
                # Legacy menu function - try to render as hierarchical
                local menu_name="${function_name%_menu}"
                if sqlite3 "$MENU_DB" "SELECT 1 FROM menu_items_v2 WHERE name = '$menu_name' AND item_type = 'menu';" >/dev/null 2>&1; then
                    MENU_HISTORY+=("$CURRENT_MENU_ID")
                    render_menu "$menu_name"
                else
                    echo -e "${YELLOW}Function not implemented yet: $function_name${NC}"
                    echo "This feature is coming soon!"
                    read -p "Press Enter to continue..."
                fi
                ;;
            *)
                # Generic not implemented message
                echo -e "${YELLOW}Function not implemented yet: $function_name${NC}"
                echo "This feature is coming soon!"
                read -p "Press Enter to continue..."
                ;;
        esac
    fi
}

# Search hierarchical menus
search_hierarchical_menus() {
    echo -e "${BLUE}=== Menu Search ===${NC}"
    echo ""
    read -p "Enter search term: " search_term
    
    if [[ -z "$search_term" ]]; then
        return
    fi
    
    echo ""
    echo -e "${CYAN}Search results for: '$search_term'${NC}"
    echo ""
    
    # Search in menu items
    sqlite3 "$MENU_DB" <<EOF | while IFS='|' read -r id path display_name item_type icon description; do
.mode list
.separator |
SELECT 
    id,
    path,
    display_name,
    item_type,
    icon,
    description
FROM v_menu_hierarchy
WHERE is_active = 1 AND is_visible = 1
AND (
    display_name LIKE '%$search_term%' 
    OR description LIKE '%$search_term%'
    OR keywords LIKE '%$search_term%'
)
ORDER BY depth, sort_order
LIMIT 20;
EOF
        if [[ "$item_type" == "menu" ]]; then
            echo -e "${GREEN}📁 $display_name${NC}"
        else
            echo -e "${CYAN}▶️ $display_name${NC}"
        fi
        echo -e "   ${GRAY}Path: $path${NC}"
        if [[ -n "$description" ]]; then
            echo -e "   ${GRAY}$description${NC}"
        fi
        echo ""
    done
    
    echo ""
    read -p "Press Enter to continue..."
}

# Show hierarchical menu index
show_hierarchical_menu_index() {
    echo -e "${BLUE}=== Menu Index ===${NC}"
    echo ""
    
    # Show menu tree
    sqlite3 "$MENU_DB" <<'EOF'
.mode column
.headers off
SELECT 
    CASE 
        WHEN depth = 0 THEN icon || ' ' || display_name 
        WHEN depth = 1 THEN '  └─ ' || icon || ' ' || display_name
        WHEN depth = 2 THEN '    └─ ' || icon || ' ' || display_name
        ELSE '      └─ ' || icon || ' ' || display_name
    END as structure,
    CASE 
        WHEN item_type = 'menu' THEN '📁'
        WHEN item_type = 'action' THEN '▶️'
        ELSE ''
    END as type
FROM v_menu_hierarchy
WHERE is_active = 1 AND is_visible = 1
ORDER BY 
    CASE WHEN parent_id IS NULL THEN id*1000 ELSE parent_id*1000 + sort_order END;
EOF
    
    echo ""
    read -p "Press Enter to continue..."
}

# Show menu help
show_menu_help() {
    echo -e "${BLUE}=== GWOMBAT Menu Help ===${NC}"
    echo ""
    echo -e "${CYAN}Navigation:${NC}"
    echo "• Use numbers to select menu items"
    echo "• b - Go back to previous menu"
    echo "• m - Return to main menu"
    echo "• s - Search all menus"
    echo "• i - Show menu index"
    echo "• ? - Show this help"
    echo "• x - Exit GWOMBAT"
    echo ""
    echo -e "${CYAN}Tips:${NC}"
    echo "• Search finds items by name, description, or keywords"
    echo "• The breadcrumb shows your current location"
    echo "• Menus are organized hierarchically"
    echo ""
    read -p "Press Enter to continue..."
}

# Initialize menu system and render main menu
init_hierarchical_menu() {
    # Reset state (bash 3.2 compatible)
    CURRENT_MENU_ID=""
    MENU_HISTORY=""
    MENU_BREADCRUMB="Main Menu"
    
    # Start at root menu
    render_menu "root"
}

# Export functions for use in main script
export -f render_menu
export -f init_hierarchical_menu
export -f execute_menu_function