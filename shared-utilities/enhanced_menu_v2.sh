#!/bin/bash

# GWOMBAT Enhanced Menu V2 - With Visual Enhancements
# Integrates Phase 2 visual elements for professional appearance
# Part of Terminal UX & Navigation Improvements - Phase 2 (Issue #8)

# Source required modules
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/terminal_control.sh"
source "$SCRIPT_DIR/key_input.sh"
source "$SCRIPT_DIR/visual_elements.sh"

# Enhanced SQLite menu renderer with visual elements
render_sqlite_menu_enhanced() {
    local menu_title="$1"
    local menu_description="$2"
    local menu_category="$3"
    local current_selection="$4"
    local section_name="$5"
    
    # Clear and setup
    clear_screen
    
    # Draw enhanced header
    draw_enhanced_header "$menu_title" "$menu_description" "$menu_category"
    printf "\n"
    
    # Check if we're in compact mode
    if [[ "${COMPACT_MODE:-}" == "true" ]]; then
        # Compact display for small terminals
        render_compact_menu "$@"
        return
    fi
    
    # Load menu items from database
    if [[ -f "shared-config/menu.db" ]]; then
        # Arrays for menu data
        local menu_items=()
        local function_names=()
        local descriptions=()
        local icons=()
        local categories=()
        local counter=1
        
        # Query database for menu items
        while IFS='|' read -r name display_name description function_name icon category; do
            [[ -n "$name" ]] || continue
            menu_items[$counter]="$display_name"
            function_names[$counter]="$function_name"
            descriptions[$counter]="$description"
            icons[$counter]="${icon:-•}"
            categories[$counter]="${category:-General}"
            ((counter++))
        done < <(sqlite3 shared-config/menu.db "
            SELECT 
                mi.name, 
                mi.display_name, 
                mi.description, 
                mi.function_name, 
                mi.icon,
                CASE 
                    WHEN mi.item_order <= 5 THEN 'Core Operations'
                    WHEN mi.item_order <= 10 THEN 'Management'
                    WHEN mi.item_order <= 15 THEN 'Analysis'
                    ELSE 'Advanced'
                END as category
            FROM menu_items mi 
            JOIN menu_sections ms ON mi.section_id = ms.id 
            WHERE ms.name = '$section_name' AND mi.is_active = 1
            ORDER BY mi.item_order;
        " 2>/dev/null)
        
        # Display items grouped by category
        local current_category=""
        for i in "${!menu_items[@]}"; do
            [[ -z "${menu_items[i]}" ]] && continue
            
            local item_category="${categories[i]}"
            
            # Show category separator if changed
            if [[ "$item_category" != "$current_category" ]]; then
                if [[ -n "$current_category" ]]; then
                    printf "\n"
                fi
                draw_section_separator "$item_category" "$menu_category"
                current_category="$item_category"
            fi
            
            # Display menu item with visual enhancements
            local is_selected="false"
            if [[ $i -eq $((current_selection + 1)) ]]; then
                is_selected="true"
            fi
            
            draw_menu_item "$i" "${icons[i]}" "${menu_items[i]}" \
                          "${descriptions[i]}" "$is_selected" "$menu_category"
        done
    else
        # Fallback if database not available
        show_status "warning" "Menu database not available - using fallback"
    fi
    
    printf "\n"
    
    # Enhanced navigation help
    draw_navigation_help_enhanced
    
    printf "\n"
}

# Compact menu for small terminals
render_compact_menu() {
    local menu_title="$1"
    local current_selection="$4"
    shift 4
    
    # Simplified display for compact mode
    color_bright_cyan
    printf "=== %s ===\n" "$menu_title"
    color_reset
    
    local items=("$@")
    for i in "${!items[@]}"; do
        if [[ $i -eq $current_selection ]]; then
            color_reverse
            printf "> %2d. %s" "$((i+1))" "${items[i]}"
            color_reset
        else
            printf "  %2d. %s" "$((i+1))" "${items[i]}"
        fi
        printf "\n"
    done
}

# Enhanced navigation help with visual styling
draw_navigation_help_enhanced() {
    local width="${1:-$TERM_COLS}"
    
    # Create help items array
    local help_items=(
        "↑↓/jk:Navigate"
        "Enter:Select"
        "ESC/p:Back"
        "m:Main"
        "s:Search"
        "?:Help"
        "q:Quit"
    )
    
    # Draw help bar
    color_dim
    color_white
    printf "["
    
    local first=true
    for item in "${help_items[@]}"; do
        if [[ "$first" != "true" ]]; then
            printf " │ "
        fi
        printf "%s" "$item"
        first=false
    done
    
    printf "]"
    color_reset
}

# Progress indicator for operations
show_operation_progress() {
    local operation="$1"
    local current="$2"
    local total="$3"
    
    save_cursor_position
    cursor_to_position $((TERM_LINES - 2)) 1
    clear_to_end_of_line
    
    draw_progress_bar "$current" "$total" 40 "$operation"
    
    restore_cursor_position
}

# Enhanced menu navigation with visual feedback
enhanced_menu_navigation_v2() {
    local menu_title="$1"
    local menu_description="$2"
    local menu_category="$3"
    local section_name="$4"
    shift 4
    local menu_items=("$@")
    
    local total_items=${#menu_items[@]}
    local current_selection=0
    local selected_item=""
    
    # Ensure we have items
    if [[ $total_items -eq 0 ]]; then
        show_status "error" "No menu items available"
        return 1
    fi
    
    # Enter enhanced navigation mode
    enter_raw_mode
    hide_cursor
    
    # Track if we need to redraw
    local needs_redraw=true
    
    while true; do
        # Render menu if needed
        if [[ "$needs_redraw" == "true" ]]; then
            render_sqlite_menu_enhanced "$menu_title" "$menu_description" \
                                       "$menu_category" "$current_selection" "$section_name"
            needs_redraw=false
        fi
        
        # Get user input
        local key_input
        key_input=$(read_navigation_key)
        
        case "$key_input" in
            "$KEY_UP"|"UP")
                if [[ $current_selection -gt 0 ]]; then
                    ((current_selection--))
                else
                    current_selection=$((total_items - 1))
                fi
                needs_redraw=true
                ;;
                
            "$KEY_DOWN"|"DOWN")
                if [[ $current_selection -lt $((total_items - 1)) ]]; then
                    ((current_selection++))
                else
                    current_selection=0
                fi
                needs_redraw=true
                ;;
                
            "$KEY_ENTER"|"ENTER")
                selected_item=$((current_selection + 1))
                
                # Show selection feedback
                save_cursor_position
                cursor_to_position $((TERM_LINES - 1)) 1
                show_status "success" "Selected: ${menu_items[$current_selection]}"
                sleep 0.5
                restore_cursor_position
                
                break
                ;;
                
            "$KEY_ESCAPE"|"ESCAPE"|"PREVIOUS")
                selected_item="back"
                break
                ;;
                
            "$KEY_QUIT"|"QUIT")
                selected_item="quit"
                break
                ;;
                
            "$KEY_HELP"|"HELP")
                show_help_overlay
                needs_redraw=true
                ;;
                
            "MAIN")
                selected_item="main"
                break
                ;;
                
            "SEARCH")
                selected_item="search"
                break
                ;;
                
            NUMBER_*)
                local number="${key_input#NUMBER_}"
                if [[ "$number" -ge 1 && "$number" -le $total_items ]]; then
                    selected_item="$number"
                    
                    # Quick feedback
                    current_selection=$((number - 1))
                    needs_redraw=true
                    sleep 0.2
                    
                    break
                else
                    show_brief_error "Invalid selection: $number"
                fi
                ;;
                
            "TOP")
                current_selection=0
                needs_redraw=true
                ;;
                
            "BOTTOM")
                current_selection=$((total_items - 1))
                needs_redraw=true
                ;;
                
            *)
                # Unknown key - brief feedback
                save_cursor_position
                cursor_to_position $((TERM_LINES - 1)) 1
                color_yellow
                printf "Unknown key: %s" "$key_input"
                color_reset
                sleep 0.5
                cursor_to_position $((TERM_LINES - 1)) 1
                clear_to_end_of_line
                restore_cursor_position
                ;;
        esac
    done
    
    # Cleanup
    show_cursor
    exit_raw_mode
    
    echo "$selected_item"
    return 0
}

# Help overlay with visual styling
show_help_overlay() {
    clear_screen
    
    draw_enhanced_header "Navigation Help" "Enhanced Terminal Navigation Guide" "Info"
    printf "\n"
    
    # Create help content
    local help_content=(
        "NAVIGATION KEYS:"
        ""
        "  ↑ or k          Move selection up"
        "  ↓ or j          Move selection down"
        "  Enter           Select highlighted item"
        "  ESC or p        Go back to previous menu"
        ""
        "QUICK ACCESS:"
        ""
        "  1-9             Direct selection by number"
        "  g               Go to top of menu"
        "  G               Go to bottom of menu"
        "  m               Return to main menu"
        "  s               Search menu options"
        ""
        "GENERAL:"
        ""
        "  ? or h          Show this help"
        "  q or x          Quit application"
    )
    
    draw_box "Key Reference" 70 "${help_content[@]}"
    
    printf "\n"
    show_status "info" "Press any key to return to menu..."
    
    wait_for_any_key ""
}

# Test the enhanced visual menu
test_enhanced_visual_menu() {
    clear_screen
    
    echo "Testing Enhanced Visual Menu System"
    echo "===================================="
    echo ""
    
    # Test visual elements first
    test_visual_elements
    
    echo ""
    read -p "Press Enter to test the enhanced menu navigation..."
    
    # Test menu items
    local test_items=(
        "Search Accounts"
        "User Management"
        "Group Operations"
        "File Analysis"
        "System Dashboard"
        "Backup Operations"
        "Security Audit"
        "Configuration"
    )
    
    local result
    result=$(enhanced_menu_navigation_v2 \
        "GWOMBAT Test Menu" \
        "Visual Enhancement Test" \
        "System" \
        "test_menu" \
        "${test_items[@]}")
    
    echo ""
    echo "Navigation result: $result"
    
    if [[ "$result" =~ ^[0-9]+$ ]]; then
        echo "Selected: ${test_items[$((result-1))]}"
    fi
}

# Initialize enhanced menu v2
init_enhanced_menu_v2() {
    # Initialize all required modules
    init_terminal_control
    init_key_input
    init_visual_elements
    
    if [[ "${DEBUG_MENU:-}" == "true" ]]; then
        echo "Enhanced menu v2 initialized" >&2
        echo "Visual enhancements: Active" >&2
        echo "Compact mode: ${COMPACT_MODE:-false}" >&2
    fi
}

# Auto-initialize when sourced
if [[ "${SKIP_INIT:-}" != "true" ]]; then
    init_enhanced_menu_v2
fi