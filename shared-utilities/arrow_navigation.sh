#!/bin/bash

# Arrow Key Navigation System for GWOMBAT
# Provides arrow key navigation with visual highlighting for menu selections

# Key codes for arrow keys and special keys
KEY_UP=$'\033[A'
KEY_DOWN=$'\033[B' 
KEY_LEFT=$'\033[D'
KEY_RIGHT=$'\033[C'
KEY_ENTER=$'\n'
KEY_ESC=$'\033'
KEY_TAB=$'\t'

# Visual highlighting colors
HIGHLIGHT_COLOR="\033[48;5;17m\033[97m"  # Blue background, white text
NORMAL_COLOR="\033[0m"
CURSOR_COLOR="\033[92m▶\033[0m"          # Green arrow
BORDER_COLOR="\033[38;5;239m"

# Function to hide cursor
hide_cursor() {
    echo -ne "\033[?25l"
}

# Function to show cursor
show_cursor() {
    echo -ne "\033[?25h"
}

# Function to move cursor to specific position
move_cursor() {
    local row=$1
    local col=$2
    echo -ne "\033[${row};${col}H"
}

# Function to clear from cursor to end of line
clear_to_eol() {
    echo -ne "\033[K"
}

# Function to save cursor position
save_cursor() {
    echo -ne "\033[s"
}

# Function to restore cursor position
restore_cursor() {
    echo -ne "\033[u"
}

# Read a single character (including escape sequences)
read_key() {
    local key
    IFS= read -rsn1 key 2>/dev/null
    
    if [[ $key == $'\033' ]]; then
        # Read the next two characters for escape sequences
        local seq
        IFS= read -rsn2 seq 2>/dev/null
        key+="$seq"
    fi
    
    echo "$key"
}

# Arrow-navigated menu function
arrow_menu() {
    local menu_title="$1"
    shift
    local -a menu_items=("$@")
    local selected=0
    local num_items=${#menu_items[@]}
    local key
    local menu_start_row=5  # Starting row for menu items
    
    # Validate we have menu items
    if [[ $num_items -eq 0 ]]; then
        echo "Error: No menu items provided"
        return 1
    fi
    
    # Clear screen and hide cursor
    clear
    hide_cursor
    
    # Set up cleanup trap
    trap 'show_cursor; exit' INT TERM EXIT
    
    # Display header
    echo -e "${BORDER_COLOR}═══════════════════════════════════════════════════════════════════════════════${NORMAL_COLOR}"
    echo -e "${GREEN}                              ${menu_title}${NORMAL_COLOR}"
    echo -e "${BORDER_COLOR}═══════════════════════════════════════════════════════════════════════════════${NORMAL_COLOR}"
    echo ""
    
    # Initial menu display
    display_menu() {
        local i
        for i in "${!menu_items[@]}"; do
            move_cursor $((menu_start_row + i)) 1
            clear_to_eol
            
            if [[ $i -eq $selected ]]; then
                echo -e "  ${CURSOR_COLOR} ${HIGHLIGHT_COLOR}$((i + 1)). ${menu_items[i]}${NORMAL_COLOR}"
            else
                echo -e "    ${CYAN}$((i + 1)).${NORMAL_COLOR} ${menu_items[i]}"
            fi
        done
        
        # Show navigation help
        local help_row=$((menu_start_row + num_items + 2))
        move_cursor $help_row 1
        echo -e "${BORDER_COLOR}─────────────────────────────────────────────────────────────────────────────────${NORMAL_COLOR}"
        move_cursor $((help_row + 1)) 1
        echo -e "${YELLOW}Navigation:${NORMAL_COLOR} ↑↓ Select | Enter Confirm | Esc/q Quit | Numbers 1-$num_items Direct"
        move_cursor $((help_row + 2)) 1
        echo -e "${BORDER_COLOR}─────────────────────────────────────────────────────────────────────────────────${NORMAL_COLOR}"
    }
    
    # Initial display
    display_menu
    
    # Main input loop
    while true; do
        key=$(read_key)
        
        case "$key" in
            "$KEY_UP")
                ((selected--))
                if [[ $selected -lt 0 ]]; then
                    selected=$((num_items - 1))
                fi
                display_menu
                ;;
            "$KEY_DOWN")
                ((selected++))
                if [[ $selected -ge $num_items ]]; then
                    selected=0
                fi
                display_menu
                ;;
            "$KEY_ENTER")
                show_cursor
                return $selected
                ;;
            "$KEY_ESC"|q|Q)
                show_cursor
                return 255  # Special exit code
                ;;
            [1-9])
                local num_choice=$((key - 1))
                if [[ $num_choice -ge 0 && $num_choice -lt $num_items ]]; then
                    selected=$num_choice
                    display_menu
                    # Small delay then select
                    sleep 0.2
                    show_cursor
                    return $selected
                fi
                ;;
            *)
                # Ignore other keys
                ;;
        esac
    done
}

# Enhanced menu with arrow navigation and fallback
enhanced_arrow_menu() {
    local menu_title="$1"
    shift
    local -a menu_items=("$@")
    
    echo -e "${CYAN}🎯 Enhanced Menu Navigation Available${NORMAL_COLOR}"
    echo "Choose navigation method:"
    echo "1. Arrow key navigation (recommended)"
    echo "2. Traditional number input"
    echo ""
    read -p "Select method (1-2): " nav_method
    
    case "$nav_method" in
        1)
            arrow_menu "$menu_title" "${menu_items[@]}"
            return $?
            ;;
        2|*)
            # Traditional menu display
            clear
            echo -e "${GREEN}=== $menu_title ===${NORMAL_COLOR}"
            echo ""
            local i
            for i in "${!menu_items[@]}"; do
                echo "$((i + 1)). ${menu_items[i]}"
            done
            echo ""
            read -p "Select option (1-${#menu_items[@]}): " choice
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [[ $choice -ge 1 && $choice -le ${#menu_items[@]} ]]; then
                return $((choice - 1))
            else
                return 255  # Invalid choice
            fi
            ;;
    esac
}

# Demo function for arrow navigation
demo_arrow_navigation() {
    local -a demo_items=(
        "👥 User & Group Management"
        "💾 File & Drive Operations" 
        "🔍 Analysis & Discovery"
        "📋 Account List Management"
        "🎯 Dashboard & Statistics"
        "📈 Reports & Monitoring"
        "⚙️  System Administration"
        "🔐 SCuBA Compliance Management"
        "⚙️  Configuration Management"
    )
    
    echo "Starting Arrow Navigation Demo..."
    echo ""
    
    enhanced_arrow_menu "GWOMBAT - Arrow Navigation Demo" "${demo_items[@]}"
    local result=$?
    
    clear
    show_cursor
    
    if [[ $result -eq 255 ]]; then
        echo "Menu cancelled or invalid selection"
    else
        echo "You selected: ${demo_items[$result]}"
        echo "Selection index: $result"
    fi
    
    echo ""
    read -p "Press Enter to continue..."
}

# Export functions for use in other scripts
export -f arrow_menu
export -f enhanced_arrow_menu
export -f demo_arrow_navigation
export -f hide_cursor
export -f show_cursor