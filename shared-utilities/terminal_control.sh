#!/bin/bash

# GWOMBAT Terminal Control Module
# Provides terminal manipulation functions for enhanced navigation
# Part of Terminal UX & Navigation Improvements (Issue #8)

# Terminal capability detection
detect_terminal_capabilities() {
    local capabilities=""
    
    # Check if we have tput
    if command -v tput >/dev/null 2>&1; then
        TERM_COLS=$(tput cols 2>/dev/null || echo "80")
        TERM_LINES=$(tput lines 2>/dev/null || echo "24") 
        TERM_COLORS=$(tput colors 2>/dev/null || echo "8")
        capabilities="tput"
    else
        TERM_COLS=80
        TERM_LINES=24
        TERM_COLORS=8
    fi
    
    # Test ANSI support
    if [[ "$TERM" =~ (xterm|screen|tmux|color) ]]; then
        ANSI_SUPPORTED=true
        capabilities="${capabilities} ansi"
    else
        ANSI_SUPPORTED=false
    fi
    
    # Export for other modules
    export TERM_COLS TERM_LINES TERM_COLORS ANSI_SUPPORTED
    
    # Debug info (can be removed later)
    if [[ "${DEBUG_TERMINAL:-}" == "true" ]]; then
        echo "Terminal capabilities: $capabilities" >&2
        echo "Size: ${TERM_COLS}x${TERM_LINES}, Colors: $TERM_COLORS" >&2
    fi
}

# Cursor movement functions
cursor_up() {
    local count="${1:-1}"
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%dA' "$count"
    fi
}

cursor_down() {
    local count="${1:-1}"  
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%dB' "$count"
    fi
}

cursor_left() {
    local count="${1:-1}"
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%dD' "$count"
    fi
}

cursor_right() {
    local count="${1:-1}"
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%dC' "$count"
    fi
}

cursor_to_column() {
    local column="$1"
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%dG' "$column"
    fi
}

cursor_to_position() {
    local row="$1" col="$2"
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[%d;%dH' "$row" "$col"
    fi
}

# Screen control functions
clear_screen() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[2J\033[H'
    else
        clear 2>/dev/null || printf '\n%.0s' {1..50}
    fi
}

clear_line() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[2K\r'
    else
        printf '\r%*s\r' "$TERM_COLS" ""
    fi
}

clear_to_end_of_line() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[K'
    fi
}

clear_to_end_of_screen() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[J'
    fi
}

# Cursor visibility
hide_cursor() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[?25l'
    fi
}

show_cursor() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[?25h'
    fi
}

# Color and formatting functions
color_reset() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[0m'
    fi
}

color_bold() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[1m'
    fi
}

color_dim() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[2m'
    fi
}

color_underline() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[4m'
    fi
}

color_reverse() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[7m'
    fi
}

# Standard colors
color_black() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;30m'; }
color_red() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;31m'; }
color_green() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;32m'; }
color_yellow() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;33m'; }
color_blue() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;34m'; }
color_magenta() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;35m'; }
color_cyan() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;36m'; }
color_white() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[0;37m'; }

# Bright colors
color_bright_black() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;30m'; }
color_bright_red() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;31m'; }
color_bright_green() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;32m'; }
color_bright_yellow() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;33m'; }
color_bright_blue() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;34m'; }
color_bright_magenta() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;35m'; }
color_bright_cyan() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;36m'; }
color_bright_white() { [[ "$ANSI_SUPPORTED" == "true" ]] && printf '\033[1;37m'; }

# Utility functions
save_cursor_position() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[s'
    fi
}

restore_cursor_position() {
    if [[ "$ANSI_SUPPORTED" == "true" ]]; then
        printf '\033[u'
    fi
}

# Terminal state management
enter_raw_mode() {
    # Save current terminal settings
    if command -v stty >/dev/null 2>&1; then
        SAVED_STTY=$(stty -g 2>/dev/null)
        # Disable canonical mode and echo
        stty -icanon -echo min 0 time 0 2>/dev/null
        RAW_MODE_ACTIVE=true
    fi
}

exit_raw_mode() {
    # Restore terminal settings
    if [[ "${RAW_MODE_ACTIVE:-}" == "true" ]] && [[ -n "${SAVED_STTY:-}" ]]; then
        stty "$SAVED_STTY" 2>/dev/null
        RAW_MODE_ACTIVE=false
    fi
}

# Cleanup function for safe exit
cleanup_terminal() {
    show_cursor
    color_reset
    exit_raw_mode
}

# Set up cleanup on script exit
setup_terminal_cleanup() {
    # Set up trap for cleanup on exit/interrupt
    trap cleanup_terminal EXIT INT TERM
}

# High-level utility functions
draw_horizontal_line() {
    local length="${1:-$TERM_COLS}"
    local char="${2:-─}"
    
    printf '%*s' "$length" '' | tr ' ' "$char"
}

draw_border_top() {
    local width="${1:-$TERM_COLS}"
    printf '┌%*s┐' "$((width-2))" '' | tr ' ' '─'
}

draw_border_bottom() {
    local width="${1:-$TERM_COLS}"
    printf '└%*s┘' "$((width-2))" '' | tr ' ' '─'
}

# Text formatting helpers
format_menu_header() {
    local text="$1"
    local width="${2:-$TERM_COLS}"
    
    color_bold
    color_bright_cyan
    printf '%*s' "$width" '' | tr ' ' '═'
    printf '\n'
    
    # Center the text
    local text_len=${#text}
    local padding=$(( (width - text_len) / 2 ))
    
    printf '%*s%s%*s\n' "$padding" '' "$text" "$padding" ''
    
    printf '%*s' "$width" '' | tr ' ' '═'
    color_reset
    printf '\n'
}

# Initialize terminal control module
init_terminal_control() {
    detect_terminal_capabilities
    setup_terminal_cleanup
    
    # Set enhanced navigation flag if not already set
    if [[ -z "${ENHANCED_NAVIGATION:-}" ]]; then
        ENHANCED_NAVIGATION="true"  # Default to enabled
        export ENHANCED_NAVIGATION
    fi
    
    if [[ "${DEBUG_TERMINAL:-}" == "true" ]]; then
        echo "Terminal control module initialized" >&2
        echo "Enhanced navigation: $ENHANCED_NAVIGATION" >&2
    fi
}

# Auto-initialize when sourced (can be disabled with SKIP_INIT=true)
# Prevent multiple initializations
if [[ "${SKIP_INIT:-}" != "true" ]] && [[ "${TERMINAL_CONTROL_INITIALIZED:-}" != "true" ]]; then
    init_terminal_control
    TERMINAL_CONTROL_INITIALIZED="true"
fi