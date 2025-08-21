#!/bin/bash

# Simple test for Phase 2 visual enhancements
# Avoids any interactive elements that might hang

echo "Phase 2 Visual Enhancement Test"
echo "================================"
echo ""

# Source only what we need
TERMINAL_CONTROL_INITIALIZED="false"
KEY_INPUT_INITIALIZED="false" 
VISUAL_ELEMENTS_INITIALIZED="false"

source ./shared-utilities/visual_elements.sh

echo "1. Color Categories Test:"
categories=("User Management" "File Operations" "Dashboard" "System" "Backup" "Security")
for cat in "${categories[@]}"; do
    apply_category_color "$cat"
    printf "  ● %s" "$cat"
    color_reset
    echo ""
done
echo ""

echo "2. Enhanced Header:"
draw_enhanced_header "Test Menu" "Subtitle" "System"
echo ""

echo "3. Section Separator:"
draw_section_separator "TEST SECTION" "Dashboard"
echo ""

echo "4. Menu Items:"
draw_menu_item 1 "🔍" "Search" "Search for items" "false" "User"
draw_menu_item 2 "⚙️" "Settings" "Configure system" "true" "System"
echo ""

echo "5. Status Messages:"
show_status "success" "Test passed"
show_status "warning" "Check this"
show_status "error" "Test error"
echo ""

echo "6. Progress Bar:"
draw_progress_bar 75 100 40 "Loading"
echo ""
echo ""

echo "7. Information Box:"
draw_box "Info" 50 "Line 1" "Line 2" "Line 3"
echo ""

echo "✅ Phase 2 Visual Elements Working!"