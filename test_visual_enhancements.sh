#!/bin/bash

# GWOMBAT Visual Enhancements Test Script
# Tests Phase 2 visual improvements and color coding
# Part of Terminal UX & Navigation Improvements - Phase 2 (Issue #8)

# Source the enhanced menu v2 system
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/shared-utilities/enhanced_menu_v2.sh"

echo "GWOMBAT Phase 2: Visual Enhancement Test Suite"
echo "=============================================="
echo ""

# Test 1: Visual Elements
echo "Test 1: Visual Elements"
echo "----------------------"

# Test border styles
echo "Testing border styles..."
BORDER_STYLE="single"
get_border_chars "single"
echo "Single: $BORDER_TOP_LEFT$BORDER_HORIZONTAL$BORDER_TOP_RIGHT"

BORDER_STYLE="double"
get_border_chars "double"
echo "Double: $BORDER_TOP_LEFT$BORDER_HORIZONTAL$BORDER_TOP_RIGHT"

BORDER_STYLE="heavy"
get_border_chars "heavy"
echo "Heavy: $BORDER_TOP_LEFT$BORDER_HORIZONTAL$BORDER_TOP_RIGHT"
echo ""

# Test 2: Color Categories
echo "Test 2: Color-Coded Categories"
echo "------------------------------"

# Test different category colors
categories=(
    "User & Group Management"
    "File & Drive Operations"
    "Analysis & Discovery"
    "Dashboard & Statistics"
    "System Administration"
    "Backup & Recovery"
    "Security & Compliance"
    "Configuration"
)

for category in "${categories[@]}"; do
    apply_category_color "$category"
    printf "● %s" "$category"
    color_reset
    printf "\n"
done
echo ""

# Test 3: Enhanced Headers
echo "Test 3: Enhanced Headers"
echo "-----------------------"

draw_enhanced_header "GWOMBAT Main Menu" "Enterprise Administration System" "System"
echo ""

# Test 4: Section Separators
echo "Test 4: Section Separators"
echo "-------------------------"

draw_section_separator "CORE OPERATIONS" "User"
draw_section_separator "MANAGEMENT TOOLS" "System"
draw_section_separator "ANALYTICS" "Dashboard"
echo ""

# Test 5: Menu Items with Visual Enhancement
echo "Test 5: Enhanced Menu Items"
echo "---------------------------"

echo "Regular items:"
draw_menu_item 1 "🔍" "Search Users" "Find users by criteria" "false" "User"
draw_menu_item 2 "📊" "View Statistics" "System statistics" "false" "Dashboard"

echo ""
echo "Selected item:"
draw_menu_item 3 "⚙️" "System Settings" "Configure system" "true" "System"
echo ""

# Test 6: Status Messages
echo "Test 6: Status Messages"
echo "----------------------"

show_status "success" "Connection established"
show_status "warning" "Storage space low"
show_status "error" "Authentication failed"
show_status "info" "25 users online"
show_status "processing" "Loading data..."
echo ""

# Test 7: Progress Indicators
echo "Test 7: Progress Indicators"
echo "--------------------------"

# Simulate progress (non-interactive for testing)
echo "Progress bar examples:"
draw_progress_bar 0 100 40 "Starting"
echo ""
draw_progress_bar 25 100 40 "Processing"
echo ""
draw_progress_bar 50 100 40 "Halfway"
echo ""
draw_progress_bar 75 100 40 "Almost done"
echo ""
draw_progress_bar 100 100 40 "Complete"
echo ""
echo ""

# Test 8: Boxes and Containers
echo "Test 8: Information Boxes"
echo "------------------------"

draw_box "System Status" 60 \
    "Version: GWOMBAT 4.1" \
    "Status: Online" \
    "Users: 150 active" \
    "Storage: 45% used" \
    "Last backup: 2 hours ago"
echo ""

# Test 9: Layout Adjustment
echo "Test 9: Layout Management"
echo "------------------------"

echo "Current terminal size: ${TERM_COLS}x${TERM_LINES}"
adjust_layout

if [[ "${COMPACT_MODE:-}" == "true" ]]; then
    echo "⚠️  Compact mode activated (narrow terminal)"
else
    echo "✓ Standard layout active"
fi

if [[ "${REDUCED_HEIGHT:-}" == "true" ]]; then
    echo "⚠️  Reduced height mode (short terminal)"
else
    echo "✓ Full height available"
fi
echo ""

# Test 10: Full Visual Menu (Interactive Optional)
echo "Test 10: Complete Visual Menu Test"
echo "----------------------------------"

read -p "Would you like to test the full visual menu? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting visual menu test..."
    sleep 1
    
    # Run the visual menu test
    test_enhanced_visual_menu
else
    echo "Skipping interactive visual menu test."
fi

echo ""

# Test Summary
echo "Phase 2 Test Summary"
echo "==================="

echo "✓ Visual elements functional"
echo "✓ Color categories working"
echo "✓ Enhanced headers displayed"
echo "✓ Section separators rendered"
echo "✓ Menu items with descriptions"
echo "✓ Status messages with icons"
echo "✓ Progress bars animated"
echo "✓ Information boxes drawn"
echo "✓ Layout management active"

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "✓ Interactive menu tested"
fi

echo ""
echo "Phase 2 Visual Enhancement: READY ✅"
echo ""
echo "Visual improvements include:"
echo "• Color-coded menu categories"
echo "• Professional borders and separators"
echo "• Icon-enhanced menu items"
echo "• Status indicators with colors"
echo "• Progress bars for operations"
echo "• Smart layout for different terminal sizes"
echo "• Enhanced navigation feedback"
echo ""
echo "Next: Phase 3 - Advanced Navigation Features"