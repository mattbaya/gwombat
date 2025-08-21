#!/bin/bash

# GWOMBAT Visual Elements Module
# Provides enhanced visual elements for terminal UI
# Part of Terminal UX & Navigation Improvements - Phase 2 (Issue #8)

# Source terminal control functions (only if not already loaded)
if [[ "${TERMINAL_CONTROL_INITIALIZED:-}" != "true" ]]; then
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$SCRIPT_DIR/terminal_control.sh"
fi

# Color scheme configuration (customizable via environment)
# Menu category colors
CATEGORY_COLOR_USER="${CATEGORY_COLOR_USER:-bright_cyan}"
CATEGORY_COLOR_FILE="${CATEGORY_COLOR_FILE:-bright_green}"
CATEGORY_COLOR_ANALYSIS="${CATEGORY_COLOR_ANALYSIS:-bright_yellow}"
CATEGORY_COLOR_DASHBOARD="${CATEGORY_COLOR_DASHBOARD:-bright_blue}"
CATEGORY_COLOR_SYSTEM="${CATEGORY_COLOR_SYSTEM:-bright_magenta}"
CATEGORY_COLOR_BACKUP="${CATEGORY_COLOR_BACKUP:-bright_red}"
CATEGORY_COLOR_SECURITY="${CATEGORY_COLOR_SECURITY:-red}"
CATEGORY_COLOR_CONFIG="${CATEGORY_COLOR_CONFIG:-cyan}"

# Status indicator colors
STATUS_COLOR_SUCCESS="${STATUS_COLOR_SUCCESS:-green}"
STATUS_COLOR_WARNING="${STATUS_COLOR_WARNING:-yellow}"
STATUS_COLOR_ERROR="${STATUS_COLOR_ERROR:-red}"
STATUS_COLOR_INFO="${STATUS_COLOR_INFO:-blue}"
STATUS_COLOR_PROCESSING="${STATUS_COLOR_PROCESSING:-cyan}"

# Visual style configuration
BORDER_STYLE="${BORDER_STYLE:-double}"  # single, double, heavy, ascii
HEADER_STYLE="${HEADER_STYLE:-gradient}"  # simple, gradient, boxed
PROGRESS_STYLE="${PROGRESS_STYLE:-bar}"  # bar, spinner, percentage

# Border characters based on style
get_border_chars() {
    local style="${1:-$BORDER_STYLE}"
    
    case "$style" in
        "single")
            BORDER_TOP_LEFT="┌"
            BORDER_TOP_RIGHT="┐"
            BORDER_BOTTOM_LEFT="└"
            BORDER_BOTTOM_RIGHT="┘"
            BORDER_HORIZONTAL="─"
            BORDER_VERTICAL="│"
            BORDER_CROSS="┼"
            BORDER_T_DOWN="┬"
            BORDER_T_UP="┴"
            BORDER_T_RIGHT="├"
            BORDER_T_LEFT="┤"
            ;;
        "double")
            BORDER_TOP_LEFT="╔"
            BORDER_TOP_RIGHT="╗"
            BORDER_BOTTOM_LEFT="╚"
            BORDER_BOTTOM_RIGHT="╝"
            BORDER_HORIZONTAL="═"
            BORDER_VERTICAL="║"
            BORDER_CROSS="╬"
            BORDER_T_DOWN="╦"
            BORDER_T_UP="╩"
            BORDER_T_RIGHT="╠"
            BORDER_T_LEFT="╣"
            ;;
        "heavy")
            BORDER_TOP_LEFT="┏"
            BORDER_TOP_RIGHT="┓"
            BORDER_BOTTOM_LEFT="┗"
            BORDER_BOTTOM_RIGHT="┛"
            BORDER_HORIZONTAL="━"
            BORDER_VERTICAL="┃"
            BORDER_CROSS="╋"
            BORDER_T_DOWN="┳"
            BORDER_T_UP="┻"
            BORDER_T_RIGHT="┣"
            BORDER_T_LEFT="┫"
            ;;
        "ascii"|*)
            BORDER_TOP_LEFT="+"
            BORDER_TOP_RIGHT="+"
            BORDER_BOTTOM_LEFT="+"
            BORDER_BOTTOM_RIGHT="+"
            BORDER_HORIZONTAL="-"
            BORDER_VERTICAL="|"
            BORDER_CROSS="+"
            BORDER_T_DOWN="+"
            BORDER_T_UP="+"
            BORDER_T_RIGHT="+"
            BORDER_T_LEFT="+"
            ;;
    esac
}

# Apply category color based on menu section
apply_category_color() {
    local category="$1"
    
    case "$category" in
        *[Uu]ser*|*[Gg]roup*)
            color_${CATEGORY_COLOR_USER}
            ;;
        *[Ff]ile*|*[Dd]rive*)
            color_${CATEGORY_COLOR_FILE}
            ;;
        *[Aa]nalysis*|*[Dd]iscovery*)
            color_${CATEGORY_COLOR_ANALYSIS}
            ;;
        *[Dd]ashboard*|*[Ss]tatistics*)
            color_${CATEGORY_COLOR_DASHBOARD}
            ;;
        *[Ss]ystem*|*[Aa]dmin*)
            color_${CATEGORY_COLOR_SYSTEM}
            ;;
        *[Bb]ackup*|*[Rr]ecovery*)
            color_${CATEGORY_COLOR_BACKUP}
            ;;
        *[Ss]ecurity*|*[Cc]ompliance*)
            color_${CATEGORY_COLOR_SECURITY}
            ;;
        *[Cc]onfig*|*[Ss]ettings*)
            color_${CATEGORY_COLOR_CONFIG}
            ;;
        *)
            color_white
            ;;
    esac
}

# Draw enhanced menu header with styling
draw_enhanced_header() {
    local title="$1"
    local subtitle="${2:-}"
    local category="${3:-}"
    local width="${4:-$TERM_COLS}"
    
    get_border_chars
    
    # Top border
    apply_category_color "$category"
    color_bold
    printf "%s" "$BORDER_TOP_LEFT"
    printf "%*s" "$((width-2))" "" | tr ' ' "$BORDER_HORIZONTAL"
    printf "%s\n" "$BORDER_TOP_RIGHT"
    
    # Title line
    printf "%s" "$BORDER_VERTICAL"
    
    # Center the title
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    
    color_bright_white
    printf "%*s%s%*s" "$padding" "" "$title" "$((width - title_len - padding - 2))" ""
    
    apply_category_color "$category"
    printf "%s\n" "$BORDER_VERTICAL"
    
    # Subtitle if provided
    if [[ -n "$subtitle" ]]; then
        printf "%s" "$BORDER_VERTICAL"
        
        # Center the subtitle
        local subtitle_len=${#subtitle}
        local sub_padding=$(( (width - subtitle_len - 2) / 2 ))
        
        color_dim
        color_white
        printf "%*s%s%*s" "$sub_padding" "" "$subtitle" "$((width - subtitle_len - sub_padding - 2))" ""
        
        apply_category_color "$category"
        printf "%s\n" "$BORDER_VERTICAL"
    fi
    
    # Bottom border
    printf "%s" "$BORDER_BOTTOM_LEFT"
    printf "%*s" "$((width-2))" "" | tr ' ' "$BORDER_HORIZONTAL"
    printf "%s\n" "$BORDER_BOTTOM_RIGHT"
    
    color_reset
}

# Draw section separator with category styling
draw_section_separator() {
    local section_name="$1"
    local category="${2:-}"
    local width="${3:-$TERM_COLS}"
    
    printf "\n"
    apply_category_color "$category"
    color_bold
    
    # Draw separator line with section name
    local name_len=${#section_name}
    local line_len=$(( (width - name_len - 6) / 2 ))
    
    printf "%*s" "$line_len" "" | tr ' ' "═"
    printf " %s " "$section_name"
    printf "%*s" "$line_len" "" | tr ' ' "═"
    
    color_reset
    printf "\n"
}

# Draw a progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local label="${4:-Progress}"
    
    local percentage=$(( (current * 100) / total ))
    local filled=$(( (current * width) / total ))
    local empty=$(( width - filled ))
    
    # Draw the label
    printf "%s: " "$label"
    
    # Draw the bar
    printf "["
    color_${STATUS_COLOR_SUCCESS}
    printf "%*s" "$filled" "" | tr ' ' '█'
    color_dim
    printf "%*s" "$empty" "" | tr ' ' '░'
    color_reset
    printf "] %3d%%" "$percentage"
}

# Animated spinner for processing
# Usage: show_spinner "pid" "message"
show_spinner() {
    local pid="$1"
    local message="${2:-Processing...}"
    local spinners=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local spinner_count=${#spinners[@]}
    local i=0
    
    hide_cursor
    
    while kill -0 "$pid" 2>/dev/null; do
        color_${STATUS_COLOR_PROCESSING}
        printf "\r%s %s " "${spinners[$i]}" "$message"
        color_reset
        
        i=$(( (i + 1) % spinner_count ))
        sleep 0.1
    done
    
    # Clear the spinner line
    printf "\r%*s\r" "$((${#message} + 4))" ""
    show_cursor
}

# Show status message with icon and color
show_status() {
    local status_type="$1"
    local message="$2"
    local icon=""
    
    case "$status_type" in
        "success")
            icon="✓"
            color_${STATUS_COLOR_SUCCESS}
            ;;
        "warning")
            icon="⚠"
            color_${STATUS_COLOR_WARNING}
            ;;
        "error")
            icon="✗"
            color_${STATUS_COLOR_ERROR}
            ;;
        "info")
            icon="ℹ"
            color_${STATUS_COLOR_INFO}
            ;;
        "processing")
            icon="⟳"
            color_${STATUS_COLOR_PROCESSING}
            ;;
        *)
            icon="•"
            color_white
            ;;
    esac
    
    color_bold
    printf "%s " "$icon"
    color_reset
    
    # Apply status color (bash 3.2 compatible)
    case "$status_type" in
        "success") color_${STATUS_COLOR_SUCCESS} ;;
        "warning") color_${STATUS_COLOR_WARNING} ;;
        "error") color_${STATUS_COLOR_ERROR} ;;
        "info") color_${STATUS_COLOR_INFO} ;;
        "processing") color_${STATUS_COLOR_PROCESSING} ;;
    esac
    
    printf "%s\n" "$message"
    color_reset
}

# Draw a box around content
draw_box() {
    local title="$1"
    local width="${2:-60}"
    shift 2
    local content=("$@")
    
    get_border_chars
    
    # Top border with title
    color_cyan
    printf "%s" "$BORDER_TOP_LEFT"
    
    if [[ -n "$title" ]]; then
        printf "%s" "$BORDER_HORIZONTAL"
        color_bright_white
        printf " %s " "$title"
        color_cyan
        local title_len=$((${#title} + 2))
        printf "%*s" "$((width - title_len - 2))" "" | tr ' ' "$BORDER_HORIZONTAL"
    else
        printf "%*s" "$((width - 2))" "" | tr ' ' "$BORDER_HORIZONTAL"
    fi
    
    printf "%s\n" "$BORDER_TOP_RIGHT"
    
    # Content lines
    for line in "${content[@]}"; do
        printf "%s " "$BORDER_VERTICAL"
        color_reset
        printf "%-*s" "$((width - 3))" "$line"
        color_cyan
        printf "%s\n" "$BORDER_VERTICAL"
    done
    
    # Bottom border
    printf "%s" "$BORDER_BOTTOM_LEFT"
    printf "%*s" "$((width - 2))" "" | tr ' ' "$BORDER_HORIZONTAL"
    printf "%s\n" "$BORDER_BOTTOM_RIGHT"
    
    color_reset
}

# Enhanced menu item with icon and description
draw_menu_item() {
    local number="$1"
    local icon="$2"
    local text="$3"
    local description="${4:-}"
    local is_selected="${5:-false}"
    local category="${6:-}"
    
    if [[ "$is_selected" == "true" ]]; then
        color_reverse
        color_bold
        printf "► %2d. %s %s" "$number" "$icon" "$text"
        color_reset
        
        if [[ -n "$description" ]]; then
            printf "\n"
            color_dim
            printf "     %s" "$description"
            color_reset
        fi
    else
        printf "  %2d. " "$number"
        
        # Apply category color to icon
        if [[ -n "$category" ]]; then
            apply_category_color "$category"
        fi
        printf "%s " "$icon"
        color_reset
        
        printf "%s" "$text"
        
        if [[ -n "$description" ]]; then
            printf "\n"
            color_dim
            printf "     %s" "$description"
            color_reset
        fi
    fi
    
    printf "\n"
}

# Smart layout management - adjust to terminal size
adjust_layout() {
    detect_terminal_capabilities
    
    local min_width=60
    local min_height=20
    
    if [[ $TERM_COLS -lt $min_width ]]; then
        show_status "warning" "Terminal width ($TERM_COLS) is below recommended minimum ($min_width)"
        COMPACT_MODE="true"
    else
        COMPACT_MODE="false"
    fi
    
    if [[ $TERM_LINES -lt $min_height ]]; then
        show_status "warning" "Terminal height ($TERM_LINES) is below recommended minimum ($min_height)"
        REDUCED_HEIGHT="true"
    else
        REDUCED_HEIGHT="false"
    fi
    
    export COMPACT_MODE REDUCED_HEIGHT
}

# Test visual elements
test_visual_elements() {
    clear_screen
    
    echo "Visual Elements Test Suite"
    echo "=========================="
    echo ""
    
    # Test headers
    draw_enhanced_header "GWOMBAT Main Menu" "Google Workspace Administration" "System"
    echo ""
    
    # Test section separators
    draw_section_separator "USER MANAGEMENT" "User"
    echo ""
    
    # Test menu items
    draw_menu_item 1 "🔍" "Search Users" "Find users by various criteria" "false" "User"
    draw_menu_item 2 "👥" "Group Management" "Manage groups and memberships" "true" "User"
    draw_menu_item 3 "📊" "User Statistics" "View user statistics and reports" "false" "Dashboard"
    echo ""
    
    # Test status messages
    show_status "success" "Operation completed successfully"
    show_status "warning" "Some items need attention"
    show_status "error" "Failed to connect to service"
    show_status "info" "10 users found matching criteria"
    echo ""
    
    # Test progress bar
    draw_progress_bar 45 100 50 "Processing Users"
    echo ""
    
    # Test box
    draw_box "System Information" 60 \
        "GWOMBAT Version: 4.1" \
        "Terminal: ${TERM_COLS}x${TERM_LINES}" \
        "Colors: $TERM_COLORS" \
        "ANSI Support: $ANSI_SUPPORTED"
    
    echo ""
    echo "Visual elements test complete."
}

# Initialize visual elements
init_visual_elements() {
    get_border_chars
    adjust_layout
    
    if [[ "${DEBUG_VISUAL:-}" == "true" ]]; then
        echo "Visual elements initialized" >&2
        echo "Border style: $BORDER_STYLE" >&2
        echo "Compact mode: ${COMPACT_MODE:-false}" >&2
    fi
}

# Auto-initialize when sourced
if [[ "${SKIP_INIT:-}" != "true" ]] && [[ "${VISUAL_ELEMENTS_INITIALIZED:-}" != "true" ]]; then
    init_visual_elements
    VISUAL_ELEMENTS_INITIALIZED="true"
fi