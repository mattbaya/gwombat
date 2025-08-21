#!/bin/bash

# GWOMBAT Key Input Handler
# Provides keyboard input handling for enhanced navigation
# Part of Terminal UX & Navigation Improvements (Issue #8)

# Source terminal control functions (only if not already loaded)
if [[ "${TERMINAL_CONTROL_INITIALIZED:-}" != "true" ]]; then
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$SCRIPT_DIR/terminal_control.sh"
fi

# Key constants for easy reference
declare -r KEY_UP="UP"
declare -r KEY_DOWN="DOWN"
declare -r KEY_LEFT="LEFT"
declare -r KEY_RIGHT="RIGHT"
declare -r KEY_ENTER="ENTER"
declare -r KEY_ESCAPE="ESCAPE"
declare -r KEY_TAB="TAB"
declare -r KEY_BACKSPACE="BACKSPACE"
declare -r KEY_DELETE="DELETE"
declare -r KEY_SPACE="SPACE"
declare -r KEY_QUIT="QUIT"
declare -r KEY_HELP="HELP"
declare -r KEY_SEARCH="SEARCH"
declare -r KEY_MAIN="MAIN"
declare -r KEY_PREVIOUS="PREVIOUS"

# Navigation key mappings will be defined later with configuration support

# Function to read a single key with timeout
read_single_key() {
    local timeout="${1:-0}"  # 0 = no timeout, wait indefinitely
    local key=""
    
    if [[ "$timeout" -gt 0 ]]; then
        read -rsn1 -t "$timeout" key
    else
        read -rsn1 key
    fi
    
    echo "$key"
}

# Main key input function - detects and returns key type
read_navigation_key() {
    local timeout="${1:-0}"
    local key
    
    # Read the first character
    key=$(read_single_key "$timeout")
    local exit_code=$?
    
    # Handle timeout case
    if [[ $exit_code -ne 0 ]]; then
        echo "TIMEOUT"
        return 1
    fi
    
    # Handle empty input (shouldn't happen but just in case)
    if [[ -z "$key" ]]; then
        echo "EMPTY"
        return 1
    fi
    
    # Check if it's an escape sequence (arrow keys, function keys, etc.)
    if [[ "$key" == $'\x1b' ]]; then
        # Read the escape sequence
        local seq1 seq2
        seq1=$(read_single_key 1)  # 1 second timeout for escape sequences
        
        if [[ -z "$seq1" ]]; then
            # Just ESC key pressed
            echo "$KEY_ESCAPE"
            return 0
        fi
        
        if [[ "$seq1" == '[' ]]; then
            # Standard escape sequence
            seq2=$(read_single_key 1)
            
            case "$seq2" in
                'A') echo "$KEY_UP" ;;
                'B') echo "$KEY_DOWN" ;;
                'C') echo "$KEY_RIGHT" ;;
                'D') echo "$KEY_LEFT" ;;
                '3')
                    # Delete key (might have more characters)
                    local seq3
                    seq3=$(read_single_key 1)
                    if [[ "$seq3" == '~' ]]; then
                        echo "$KEY_DELETE"
                    else
                        echo "UNKNOWN_ESC_[3$seq3"
                    fi
                    ;;
                *) echo "UNKNOWN_ESC_[$seq2" ;;
            esac
        elif [[ "$seq1" == 'O' ]]; then
            # Alternative escape sequence format
            seq2=$(read_single_key 1)
            case "$seq2" in
                'A') echo "$KEY_UP" ;;
                'B') echo "$KEY_DOWN" ;;
                'C') echo "$KEY_RIGHT" ;;
                'D') echo "$KEY_LEFT" ;;
                *) echo "UNKNOWN_ESC_O$seq2" ;;
            esac
        else
            echo "UNKNOWN_ESC_$seq1"
        fi
        return 0
    fi
    
    # Handle regular keys
    case "$key" in
        # Control characters
        $'\n'|$'\r')  # Enter/Return
            echo "$KEY_ENTER"
            ;;
        $'\t')        # Tab
            echo "$KEY_TAB"
            ;;
        $'\x7f'|$'\x08')  # Backspace
            echo "$KEY_BACKSPACE"
            ;;
        ' ')          # Space
            echo "$KEY_SPACE"
            ;;
        
        # Check navigation key mappings
        *)
            # Check if this key is mapped to a navigation action
            local nav_mapping
            nav_mapping=$(get_nav_key_mapping "$key")
            if [[ -n "$nav_mapping" ]]; then
                echo "$nav_mapping"
            elif [[ "$key" =~ ^[0-9]$ ]]; then
                # Number keys for direct selection
                echo "NUMBER_$key"
            elif [[ "$key" =~ ^[a-zA-Z]$ ]]; then
                # Letter keys not mapped to navigation
                echo "LETTER_$key"
            else
                # Any other character
                echo "CHAR_$key"
            fi
            ;;
    esac
    
    return 0
}

# Enhanced input function with visual feedback
read_navigation_key_with_feedback() {
    local timeout="${1:-0}"
    local show_prompt="${2:-false}"
    
    # Show input prompt if requested
    if [[ "$show_prompt" == "true" ]]; then
        color_dim
        printf "Use arrow keys or j/k to navigate, Enter to select, ? for help: "
        color_reset
    fi
    
    # Read the key
    local key_result
    key_result=$(read_navigation_key "$timeout")
    local exit_code=$?
    
    # Clear the prompt line if it was shown
    if [[ "$show_prompt" == "true" ]]; then
        cursor_to_column 1
        clear_to_end_of_line
    fi
    
    echo "$key_result"
    return $exit_code
}

# Function to wait for any key press
wait_for_any_key() {
    local message="${1:-Press any key to continue...}"
    
    color_dim
    printf "%s" "$message"
    color_reset
    
    read_single_key
    
    # Clear the message
    cursor_to_column 1
    clear_to_end_of_line
}

# Function to get user confirmation with y/n
get_confirmation() {
    local message="$1"
    local default="${2:-n}"  # Default to 'n' if not specified
    
    while true; do
        color_yellow
        if [[ "$default" == "y" ]]; then
            printf "%s [Y/n]: " "$message"
        else
            printf "%s [y/N]: " "$message"
        fi
        color_reset
        
        local key
        key=$(read_single_key)
        
        # Clear the prompt line
        cursor_to_column 1
        clear_to_end_of_line
        
        case "$key" in
            'y'|'Y')
                echo "yes"
                return 0
                ;;
            'n'|'N')
                echo "no"
                return 1
                ;;
            $'\n'|$'\r')
                # Enter pressed - use default
                if [[ "$default" == "y" ]]; then
                    echo "yes"
                    return 0
                else
                    echo "no"
                    return 1
                fi
                ;;
            *)
                # Invalid input, try again
                color_red
                printf "Please press y or n (or Enter for default): "
                color_reset
                sleep 1
                cursor_to_column 1
                clear_to_end_of_line
                ;;
        esac
    done
}

# Function to get numeric input with validation
get_numeric_input() {
    local prompt="$1"
    local min_val="${2:-1}"
    local max_val="${3:-999}"
    local timeout="${4:-0}"
    
    local input=""
    local key
    
    while true; do
        color_cyan
        printf "%s (%d-%d): %s" "$prompt" "$min_val" "$max_val" "$input"
        color_reset
        
        key=$(read_single_key "$timeout")
        
        case "$key" in
            [0-9])
                input="$input$key"
                ;;
            $'\n'|$'\r')
                if [[ -n "$input" ]] && [[ "$input" -ge "$min_val" ]] && [[ "$input" -le "$max_val" ]]; then
                    cursor_to_column 1
                    clear_to_end_of_line
                    echo "$input"
                    return 0
                else
                    cursor_to_column 1
                    clear_to_end_of_line
                    color_red
                    printf "Invalid input. Please enter a number between %d and %d: " "$min_val" "$max_val"
                    color_reset
                    sleep 1
                    cursor_to_column 1
                    clear_to_end_of_line
                    input=""
                fi
                ;;
            $'\x7f'|$'\x08')  # Backspace
                if [[ -n "$input" ]]; then
                    input="${input%?}"
                fi
                cursor_to_column 1
                clear_to_end_of_line
                ;;
            $'\x1b')  # Escape - cancel
                cursor_to_column 1
                clear_to_end_of_line
                echo "CANCELLED"
                return 1
                ;;
            *)
                # Ignore other keys
                ;;
        esac
    done
}

# Debug function to test key input
test_key_input() {
    echo "Key Input Test Mode"
    echo "Press keys to test detection (press 'q' to quit):"
    echo ""
    
    enter_raw_mode
    
    while true; do
        local key_result
        key_result=$(read_navigation_key)
        
        printf "Key detected: %s\n" "$key_result"
        
        if [[ "$key_result" == "$KEY_QUIT" ]]; then
            break
        fi
    done
    
    exit_raw_mode
    echo "Test completed."
}

# Navigation key mapping configuration (bash 3.2 compatible)
VIM_NAVIGATION="true"
POWER_USER_KEYS="true"

configure_navigation_keys() {
    local vim_mode="${1:-true}"
    local power_user="${2:-true}"
    
    VIM_NAVIGATION="$vim_mode"
    POWER_USER_KEYS="$power_user"
}

# Updated mapping function that respects configuration
get_nav_key_mapping() {
    local key="$1"
    
    case "$key" in
        'j') [[ "$VIM_NAVIGATION" == "true" ]] && echo "DOWN" ;;
        'k') [[ "$VIM_NAVIGATION" == "true" ]] && echo "UP" ;;
        'h') [[ "$VIM_NAVIGATION" == "true" ]] && echo "LEFT" ;;
        'l') [[ "$VIM_NAVIGATION" == "true" ]] && echo "RIGHT" ;;
        'g') [[ "$POWER_USER_KEYS" == "true" ]] && echo "TOP" ;;
        'G') [[ "$POWER_USER_KEYS" == "true" ]] && echo "BOTTOM" ;;
        '?') echo "HELP" ;;        # Always available
        's') echo "SEARCH" ;;      # Always available
        'm') echo "MAIN" ;;        # Always available
        'p') echo "PREVIOUS" ;;    # Always available
        'q') echo "QUIT" ;;        # Always available
        'x') echo "QUIT" ;;        # Always available
        *) echo "" ;;              # No mapping
    esac
}

# Initialize key input handler
init_key_input() {
    # Load configuration from environment
    local vim_mode="${VIM_NAVIGATION:-true}"
    local power_user="${POWER_USER_KEYS:-true}"
    
    configure_navigation_keys "$vim_mode" "$power_user"
    
    if [[ "${DEBUG_KEYS:-}" == "true" ]]; then
        echo "Key input handler initialized" >&2
        echo "Vim mode: $vim_mode, Power user: $power_user" >&2
    fi
}

# Auto-initialize when sourced (can be disabled with SKIP_INIT=true)
if [[ "${SKIP_INIT:-}" != "true" ]] && [[ "${KEY_INPUT_INITIALIZED:-}" != "true" ]]; then
    init_key_input
    KEY_INPUT_INITIALIZED="true"
fi