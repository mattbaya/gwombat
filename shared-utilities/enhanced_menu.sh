#!/bin/bash

# GWOMBAT Enhanced Menu Renderer
# Provides enhanced menu display with highlighting and navigation
# Part of Terminal UX & Navigation Improvements (Issue #8)

# Source required modules
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/terminal_control.sh"
source "$SCRIPT_DIR/key_input.sh"

# Menu configuration (bash 3.2 compatible)
MENU_SELECTION_INDICATOR="►"
MENU_ITEM_PREFIX="  "
MENU_SELECTED_PREFIX=""
MENU_MAX_DISPLAY_ITEMS=20

# Enhanced menu display function
render_enhanced_menu() {
    local menu_title="$1"
    local current_selection="$2"
    shift 2
    local menu_items=("$@")
    
    local total_items=${#menu_items[@]}
    
    # Clear screen and position cursor
    clear_screen
    
    # Display header
    format_menu_header "$menu_title"
    printf "\n"
    
    # Display menu items with highlighting
    for i in "${!menu_items[@]}"; do
        local item_text="${menu_items[i]}"
        local item_number=$((i + 1))
        
        if [[ $i -eq $current_selection ]]; then
            # Highlight current selection
            color_reverse
            color_bold
            printf "%s %2d. %s" "$MENU_SELECTION_INDICATOR" "$item_number" "$item_text"
            color_reset
            printf "\n"
        else
            # Normal menu item
            printf "%s %2d. %s\n" "$MENU_ITEM_PREFIX" "$item_number" "$item_text"
        fi
    done
    
    printf "\n"
    
    # Display navigation help
    display_navigation_help
    
    printf "\n"
}

# Enhanced menu display with categories (for SQLite menus)
render_enhanced_menu_with_categories() {
    local menu_title="$1"
    local current_selection="$2"
    local menu_items_ref="$3"  # Reference to associative array
    local menu_categories_ref="$4"  # Reference to category info
    shift 4
    
    # Use nameref for associative arrays (bash 4.3+)
    declare -n menu_items="$menu_items_ref"
    declare -n menu_categories="$menu_categories_ref"
    
    clear_screen
    format_menu_header "$menu_title"
    printf "\n"
    
    local current_category=""
    local item_index=0
    
    # Display items grouped by category
    for key in "${!menu_items[@]}"; do
        local category="${menu_categories[$key]}"
        local item_text="${menu_items[$key]}"
        
        # Show category header if changed
        if [[ "$category" != "$current_category" ]]; then
            if [[ -n "$current_category" ]]; then
                printf "\n"  # Space between categories
            fi
            color_bright_yellow
            color_bold
            printf "=== %s ===\n" "$category"
            color_reset
            current_category="$category"
        fi
        
        # Display menu item
        local item_number=$((item_index + 1))
        if [[ $item_index -eq $current_selection ]]; then
            color_reverse
            color_bold
            printf "%s %2d. %s" "$MENU_SELECTION_INDICATOR" "$item_number" "$item_text"
            color_reset
            printf "\n"
        else
            printf "%s %2d. %s\n" "$MENU_ITEM_PREFIX" "$item_number" "$item_text"
        fi
        
        ((item_index++))
    done
    
    printf "\n"
    display_navigation_help
    printf "\n"
}

# Simple enhanced menu for SQLite integration
render_sqlite_enhanced_menu() {
    local menu_title="$1"
    local menu_description="$2"
    local current_selection="$3"
    shift 3
    
    # Arrays for menu data (bash 3.2 compatible)
    local menu_items=() 
    local function_names=()
    local descriptions=()
    local icons=()
    local categories=()
    
    # Load data into arrays (this will be called from existing SQLite menu functions)
    local counter=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --item)
                menu_items[$counter]="$2"
                shift 2
                ;;
            --function)
                function_names[$counter]="$2"
                shift 2
                ;;
            --description)
                descriptions[$counter]="$2"
                shift 2
                ;;
            --icon)
                icons[$counter]="$2"
                shift 2
                ;;
            --category)
                categories[$counter]="$2"
                ((counter++))
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    clear_screen
    format_menu_header "$menu_title"
    
    if [[ -n "$menu_description" ]]; then
        color_cyan
        printf "%s\n" "$menu_description"
        color_reset
        printf "\n"
    fi
    
    # Display items with category grouping
    local current_category=""
    for i in "${!menu_items[@]}"; do
        [[ -z "${menu_items[i]}" ]] && continue
        
        local category="${categories[i]}"
        if [[ -n "$category" && "$category" != "$current_category" ]]; then
            if [[ -n "$current_category" ]]; then
                printf "\n"
            fi
            color_bright_yellow
            printf "=== %s ===\n" "$category"
            color_reset
            current_category="$category"
        fi
        
        # Display menu item
        if [[ $i -eq $((current_selection + 1)) ]]; then
            color_reverse
            color_bold
            printf "%s %2d. %s %s" "$MENU_SELECTION_INDICATOR" "$i" "${icons[i]}" "${menu_items[i]}"
            color_reset
            printf "\n"
            if [[ -n "${descriptions[i]}" ]]; then
                color_dim
                printf "    %s\n" "${descriptions[i]}"
                color_reset
            fi
        else
            printf "%s %2d. %s %s\n" "$MENU_ITEM_PREFIX" "$i" "${icons[i]}" "${menu_items[i]}"
            if [[ -n "${descriptions[i]}" ]]; then
                color_dim
                printf "    %s\n" "${descriptions[i]}"
                color_reset
            fi
        fi
    done
    
    printf "\n"
    display_navigation_help
    printf "\n"
}

# Navigation help display
display_navigation_help() {
    color_dim
    printf "Navigation: "
    color_reset
    
    # Show available navigation options
    printf "↑↓ or j/k: navigate  "
    printf "Enter: select  "
    printf "ESC: back  "
    printf "?: help  "
    printf "q/x: quit"
}

# Enhanced navigation loop
enhanced_menu_navigation() {
    local menu_title="$1"
    local menu_description="$2"
    shift 2
    local menu_items=("$@")
    
    local total_items=${#menu_items[@]}
    local current_selection=0
    local selected_item=""
    
    # Ensure we have items to display
    if [[ $total_items -eq 0 ]]; then
        echo "ERROR: No menu items provided"
        return 1
    fi
    
    # Enter enhanced navigation mode
    enter_raw_mode
    hide_cursor
    
    while true; do
        # Render the menu
        render_enhanced_menu "$menu_title" "$current_selection" "${menu_items[@]}"
        
        # Get user input
        local key_input
        key_input=$(read_navigation_key)
        
        case "$key_input" in
            "$KEY_UP"|"UP")
                if [[ $current_selection -gt 0 ]]; then
                    ((current_selection--))
                else
                    # Wrap to bottom
                    current_selection=$((total_items - 1))
                fi
                ;;
            "$KEY_DOWN"|"DOWN") 
                if [[ $current_selection -lt $((total_items - 1)) ]]; then
                    ((current_selection++))
                else
                    # Wrap to top
                    current_selection=0
                fi
                ;;
            "$KEY_ENTER"|"ENTER")
                selected_item=$((current_selection + 1))
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
                show_navigation_help
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
                # Direct number selection
                local number="${key_input#NUMBER_}"
                if [[ "$number" -ge 1 && "$number" -le $total_items ]]; then
                    selected_item="$number"
                    break
                else
                    # Invalid number - show brief error
                    show_brief_error "Invalid selection: $number"
                fi
                ;;
            "TOP")
                current_selection=0
                ;;
            "BOTTOM")
                current_selection=$((total_items - 1))
                ;;
            *)
                # Unknown key - show brief feedback
                show_brief_feedback "Unknown key: $key_input"
                ;;
        esac
    done
    
    # Cleanup and exit
    show_cursor
    exit_raw_mode
    
    echo "$selected_item"
    return 0
}

# Show brief error message
show_brief_error() {
    local message="$1"
    
    save_cursor_position
    cursor_to_position $((TERM_LINES - 2)) 1
    color_red
    color_bold
    printf "Error: %s" "$message"
    color_reset
    
    sleep 1
    
    cursor_to_position $((TERM_LINES - 2)) 1
    clear_to_end_of_line
    restore_cursor_position
}

# Show brief feedback message
show_brief_feedback() {
    local message="$1"
    
    save_cursor_position
    cursor_to_position $((TERM_LINES - 1)) 1
    color_yellow
    printf "%s" "$message"
    color_reset
    
    sleep 0.5
    
    cursor_to_position $((TERM_LINES - 1)) 1
    clear_to_end_of_line
    restore_cursor_position
}

# Show detailed navigation help
show_navigation_help() {
    clear_screen
    format_menu_header "Navigation Help"
    printf "\n"
    
    color_bright_white
    printf "Enhanced Navigation Controls:\n\n"
    color_reset
    
    printf "  %-20s %s\n" "↑ or k" "Move selection up"
    printf "  %-20s %s\n" "↓ or j" "Move selection down"
    printf "  %-20s %s\n" "Enter" "Select highlighted item"
    printf "  %-20s %s\n" "1-9" "Direct selection by number"
    printf "  %-20s %s\n" "ESC or p" "Go back to previous menu"
    printf "  %-20s %s\n" "g" "Go to top of menu"
    printf "  %-20s %s\n" "G" "Go to bottom of menu"
    printf "  %-20s %s\n" "m" "Return to main menu"
    printf "  %-20s %s\n" "s" "Search menu options"
    printf "  %-20s %s\n" "? or h" "Show this help"
    printf "  %-20s %s\n" "q or x" "Quit application"
    
    printf "\n"
    color_dim
    printf "Enhanced navigation can be disabled by setting ENHANCED_NAVIGATION=false\n"
    printf "in your local-config/.env file.\n"
    color_reset
    
    printf "\n"
    wait_for_any_key
}

# Compatibility function for existing menus
enhanced_menu_wrapper() {
    local menu_title="$1"
    local enhanced_mode="${ENHANCED_NAVIGATION:-true}"
    
    # Check if enhanced navigation is enabled
    if [[ "$enhanced_mode" != "true" ]]; then
        # Fall back to traditional menu (this would call existing menu function)
        return 1  # Indicates fallback needed
    fi
    
    # Enhanced navigation enabled
    shift
    enhanced_menu_navigation "$menu_title" "" "$@"
}

# Test function for development
test_enhanced_menu() {
    local test_items=(
        "🔍 Search Accounts by Criteria"
        "👤 Account Profile Analysis"
        "🏢 Department Analysis"
        "📧 Email Pattern Analysis"
        "📊 Storage Usage Analysis"
        "🔐 Login Activity Analysis"
        "📅 Account Activity Patterns"
        "💾 Drive Usage Analysis"
    )
    
    echo "Testing enhanced menu navigation..."
    echo "This will demonstrate the new navigation system."
    echo ""
    read -p "Press Enter to start the test..."
    
    local result
    result=$(enhanced_menu_navigation "Test Menu" "Test menu for enhanced navigation" "${test_items[@]}")
    
    echo ""
    echo "Navigation result: $result"
    
    case "$result" in
        [1-8])
            echo "Selected item $result: ${test_items[$((result-1))]}"
            ;;
        "back")
            echo "User selected back"
            ;;
        "quit")
            echo "User selected quit"
            ;;
        "main")
            echo "User selected main menu"
            ;;
        *)
            echo "Other selection: $result"
            ;;
    esac
}

# Initialize enhanced menu system
init_enhanced_menu() {
    if [[ "${DEBUG_MENU:-}" == "true" ]]; then
        echo "Enhanced menu system initialized" >&2
        echo "Enhanced navigation: ${ENHANCED_NAVIGATION:-true}" >&2
    fi
}

# Auto-initialize when sourced (can be disabled with SKIP_INIT=true)
if [[ "${SKIP_INIT:-}" != "true" ]]; then
    init_enhanced_menu
fi