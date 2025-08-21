#!/bin/bash
# Test menu choice functionality

source shared-utilities/database_functions.sh

# Source the show_main_menu function from gwombat.sh
test_show_main_menu() {
    # Simulate the function call
    echo "Testing menu choice handling..."
    
    # Simulate user input 'x' (exit)
    choice="x"
    
    # Convert letters to numbers for case handling (copied from show_main_menu)
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then
        choice=10  # Exit
    elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
        choice=99  # Configuration
    elif [[ "$choice" == "s" || "$choice" == "S" ]]; then
        choice=98  # Search
    elif [[ "$choice" == "i" || "$choice" == "I" ]]; then
        choice=97  # Index
    fi
    
    MENU_CHOICE=$choice
    echo "MENU_CHOICE set to: $MENU_CHOICE"
    
    # Test case handling
    case $MENU_CHOICE in
        10) echo "Exit case matched - script should exit" ;;
        *) echo "Other case: $MENU_CHOICE" ;;
    esac
}

test_show_main_menu