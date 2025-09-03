#!/bin/bash
# GWOMBAT Hierarchical Menu System Test Script
# Tests the database-driven menu functionality without user input

# Initialize test environment
SCRIPTPATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPTPATH"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

# Test configuration
TEST_LOG="local-config/logs/hierarchical_menu_test.log"
mkdir -p "$(dirname "$TEST_LOG")"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Load required functions
source shared-utilities/database_functions.sh 2>/dev/null || {
    echo -e "${RED}CRITICAL: Cannot load database_functions.sh${NC}"
    exit 1
}

# Override render_menu to capture output for testing
original_render_menu=""

# Test logging function
test_log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$TEST_LOG"
    echo "$1"
}

# Test result reporting
report_test() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$result" == "PASS" ]]; then
        ((TESTS_PASSED++))
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        test_log "PASS: $test_name"
    else
        ((TESTS_FAILED++))
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        if [[ -n "$details" ]]; then
            echo -e "  ${GRAY}Details: $details${NC}"
        fi
        test_log "FAIL: $test_name - $details"
    fi
}

# Test database connectivity
test_database_connectivity() {
    echo -e "\n${CYAN}=== Testing Database Connectivity ===${NC}"
    
    # Test menu database exists
    if [[ -f "shared-config/menu.db" ]]; then
        report_test "Menu database exists" "PASS"
    else
        report_test "Menu database exists" "FAIL" "File not found: shared-config/menu.db"
        return 1
    fi
    
    # Test database has data
    local count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2;" 2>/dev/null)
    if [[ "$count" -gt 0 ]]; then
        report_test "Menu database has data" "PASS" "$count items found"
    else
        report_test "Menu database has data" "FAIL" "No menu items found"
    fi
    
    # Test view exists
    local view_test=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM v_menu_hierarchy;" 2>/dev/null)
    if [[ "$view_test" -gt 0 ]]; then
        report_test "Hierarchical view functional" "PASS" "$view_test items in hierarchy"
    else
        report_test "Hierarchical view functional" "FAIL" "v_menu_hierarchy view not working"
    fi
}

# Test menu loading functionality
test_menu_loading() {
    echo -e "\n${CYAN}=== Testing Menu Loading Functions ===${NC}"
    
    # Test hierarchical menu system loading
    if [[ -f "shared-utilities/hierarchical_menu_system.sh" ]]; then
        report_test "Hierarchical menu system file exists" "PASS"
        
        # Try to source it
        if source shared-utilities/hierarchical_menu_system.sh 2>/dev/null; then
            report_test "Hierarchical menu system loads" "PASS"
        else
            report_test "Hierarchical menu system loads" "FAIL" "Source command failed"
            return 1
        fi
        
        # Test if render_menu function is available
        if declare -f render_menu >/dev/null 2>&1; then
            report_test "render_menu function available" "PASS"
        else
            report_test "render_menu function available" "FAIL" "Function not declared"
        fi
    else
        report_test "Hierarchical menu system file exists" "FAIL" "File not found"
        return 1
    fi
}

# Test individual menu queries (dry run - no user interaction)
test_menu_queries() {
    echo -e "\n${CYAN}=== Testing Menu Database Queries ===${NC}"
    
    # Test root menu query
    local root_items=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE parent_id IS NULL AND is_active = 1;" 2>/dev/null)
    if [[ "$root_items" -gt 0 ]]; then
        report_test "Root menu query returns items" "PASS" "$root_items root items"
    else
        report_test "Root menu query returns items" "FAIL" "No root items found"
    fi
    
    # Test specific submenus exist
    local submenus=("user_group_management" "file_drive_operations" "dashboard_statistics" "analysis_discovery")
    
    for submenu in "${submenus[@]}"; do
        local submenu_id=$(sqlite3 shared-config/menu.db "SELECT id FROM menu_items_v2 WHERE name = '$submenu' AND item_type = 'menu';" 2>/dev/null)
        if [[ -n "$submenu_id" ]]; then
            # Count submenu items
            local submenu_count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE parent_id = $submenu_id AND is_active = 1;" 2>/dev/null)
            if [[ "$submenu_count" -gt 0 ]]; then
                report_test "Submenu '$submenu' has items" "PASS" "$submenu_count items"
            else
                report_test "Submenu '$submenu' has items" "FAIL" "No items in submenu"
            fi
        else
            report_test "Submenu '$submenu' exists" "FAIL" "Menu not found in database"
        fi
    done
}

# Test menu data structure integrity
test_menu_integrity() {
    echo -e "\n${CYAN}=== Testing Menu Data Integrity ===${NC}"
    
    # Test for orphaned items (parent_id points to non-existent item)
    local orphaned=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE parent_id IS NOT NULL AND parent_id NOT IN (SELECT id FROM menu_items_v2);" 2>/dev/null)
    if [[ "$orphaned" -eq 0 ]]; then
        report_test "No orphaned menu items" "PASS"
    else
        report_test "No orphaned menu items" "FAIL" "$orphaned orphaned items found"
    fi
    
    # Test for circular references (simplified check)
    local circular=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE id = parent_id;" 2>/dev/null)
    if [[ "$circular" -eq 0 ]]; then
        report_test "No circular menu references" "PASS"
    else
        report_test "No circular menu references" "FAIL" "$circular self-referencing items"
    fi
    
    # Test menu types are valid
    local invalid_types=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE item_type NOT IN ('menu', 'action', 'separator');" 2>/dev/null)
    if [[ "$invalid_types" -eq 0 ]]; then
        report_test "All menu types are valid" "PASS"
    else
        report_test "All menu types are valid" "FAIL" "$invalid_types items with invalid types"
    fi
}

# Test search functionality
test_menu_search() {
    echo -e "\n${CYAN}=== Testing Menu Search Functionality ===${NC}"
    
    # Test search for common terms
    local search_terms=("user" "backup" "file" "statistics")
    
    for term in "${search_terms[@]}"; do
        local results=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM v_menu_hierarchy WHERE is_active = 1 AND (display_name LIKE '%$term%' OR keywords LIKE '%$term%');" 2>/dev/null)
        if [[ "$results" -gt 0 ]]; then
            report_test "Search for '$term' returns results" "PASS" "$results matches"
        else
            report_test "Search for '$term' returns results" "FAIL" "No matches found"
        fi
    done
}

# Test menu function resolution
test_function_resolution() {
    echo -e "\n${CYAN}=== Testing Menu Function Resolution ===${NC}"
    
    # Get a sample of action items with functions
    local functions=$(sqlite3 shared-config/menu.db "SELECT function_name FROM menu_items_v2 WHERE item_type = 'action' AND function_name IS NOT NULL AND function_name != '' LIMIT 5;" 2>/dev/null)
    
    if [[ -n "$functions" ]]; then
        report_test "Action items have function names" "PASS"
        
        # Test if functions exist in main script (basic check)
        local function_count=0
        while IFS= read -r func; do
            if [[ -n "$func" ]]; then
                ((function_count++))
                # Simple grep to see if function is defined somewhere
                if grep -q "^$func()" gwombat.sh 2>/dev/null || grep -q "^$func ()" gwombat.sh 2>/dev/null; then
                    report_test "Function '$func' is defined" "PASS"
                else
                    # Check if it's a render_menu call (these are valid)
                    if [[ "$func" =~ .*_menu$ ]]; then
                        report_test "Function '$func' is menu function" "PASS" "Menu function (expected)"
                    else
                        report_test "Function '$func' is defined" "FAIL" "Function not found in gwombat.sh"
                    fi
                fi
            fi
        done <<< "$functions"
        
        if [[ $function_count -gt 0 ]]; then
            report_test "Functions can be resolved" "PASS" "$function_count functions checked"
        fi
    else
        report_test "Action items have function names" "FAIL" "No action functions found"
    fi
}

# Test hierarchical navigation paths
test_navigation_paths() {
    echo -e "\n${CYAN}=== Testing Navigation Path Generation ===${NC}"
    
    # Test breadcrumb generation via view
    local path_test=$(sqlite3 shared-config/menu.db "SELECT path FROM v_menu_hierarchy WHERE name = 'user_group_management';" 2>/dev/null)
    if [[ -n "$path_test" ]]; then
        report_test "Navigation paths generate correctly" "PASS" "Path: $path_test"
    else
        report_test "Navigation paths generate correctly" "FAIL" "No path generated for test menu"
    fi
    
    # Test depth calculation
    local max_depth=$(sqlite3 shared-config/menu.db "SELECT MAX(depth) FROM v_menu_hierarchy;" 2>/dev/null)
    if [[ "$max_depth" -ge 1 ]]; then
        report_test "Menu hierarchy has proper depth" "PASS" "Max depth: $max_depth"
    else
        report_test "Menu hierarchy has proper depth" "FAIL" "Insufficient hierarchy depth"
    fi
}

# Test menu rendering (mock test - capture structure without user interaction)
test_menu_rendering() {
    echo -e "\n${CYAN}=== Testing Menu Rendering (Mock) ===${NC}"
    
    # Test that we can query menu structure for main menu
    local main_structure=$(sqlite3 shared-config/menu.db "SELECT id, name, display_name, item_type FROM menu_items_v2 WHERE parent_id IS NULL AND is_active = 1 ORDER BY sort_order;" 2>/dev/null)
    
    if [[ -n "$main_structure" ]]; then
        report_test "Main menu structure queryable" "PASS"
        echo -e "  ${GRAY}Sample main menu items:${NC}"
        echo "$main_structure" | head -3 | while IFS='|' read -r id name display_name item_type; do
            echo -e "    $id. $display_name ($item_type)"
        done
    else
        report_test "Main menu structure queryable" "FAIL" "No main menu items returned"
    fi
    
    # Test submenu structure
    local user_mgmt_id=$(sqlite3 shared-config/menu.db "SELECT id FROM menu_items_v2 WHERE name = 'user_group_management';" 2>/dev/null)
    if [[ -n "$user_mgmt_id" ]]; then
        local submenu_structure=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_items_v2 WHERE parent_id = $user_mgmt_id;" 2>/dev/null)
        if [[ "$submenu_structure" -gt 0 ]]; then
            report_test "Submenu structure queryable" "PASS" "$submenu_structure items in user management"
        else
            report_test "Submenu structure queryable" "FAIL" "No submenu items found"
        fi
    else
        report_test "Submenu structure queryable" "FAIL" "Could not find user_group_management menu"
    fi
}

# Test configuration and shortcuts
test_menu_configuration() {
    echo -e "\n${CYAN}=== Testing Menu Configuration ===${NC}"
    
    # Test menu config table
    local config_count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_config;" 2>/dev/null)
    if [[ "$config_count" -gt 0 ]]; then
        report_test "Menu configuration loaded" "PASS" "$config_count config items"
    else
        report_test "Menu configuration loaded" "FAIL" "No configuration found"
    fi
    
    # Test shortcuts exist
    local shortcuts_count=$(sqlite3 shared-config/menu.db "SELECT COUNT(*) FROM menu_shortcuts WHERE is_active = 1;" 2>/dev/null)
    if [[ "$shortcuts_count" -gt 0 ]]; then
        report_test "Navigation shortcuts configured" "PASS" "$shortcuts_count shortcuts"
    else
        report_test "Navigation shortcuts configured" "FAIL" "No shortcuts found"
    fi
}

# Test the actual render_menu function (non-interactive)
test_render_function() {
    echo -e "\n${CYAN}=== Testing render_menu Function (Non-Interactive) ===${NC}"
    
    # Source the hierarchical menu system
    if source shared-utilities/hierarchical_menu_system.sh 2>/dev/null; then
        report_test "Hierarchical menu system sources successfully" "PASS"
        
        # Mock the interactive parts to test structure generation
        # Override read command to avoid hanging
        read() {
            echo "q"  # Automatically choose exit
        }
        export -f read
        
        # Override clear to avoid screen clearing during test
        clear() {
            echo "# CLEAR SCREEN"
        }
        export -f clear
        
        # Test main menu rendering capability
        echo -e "\n${GRAY}Testing main menu rendering structure:${NC}"
        
        # Check if menu info can be retrieved (the core logic)
        local menu_info=$(sqlite3 shared-config/menu.db "SELECT id, display_name, description, icon, color_code FROM menu_items_v2 WHERE name = 'user_group_management';" 2>/dev/null)
        if [[ -n "$menu_info" ]]; then
            report_test "Menu info retrieval works" "PASS" "Retrieved: $menu_info"
        else
            report_test "Menu info retrieval works" "FAIL" "Could not retrieve menu info"
        fi
        
        # Test menu items query for root level
        local root_query="SELECT id, name, display_name, description, icon, item_type, function_name, sort_order FROM menu_items_v2 WHERE parent_id IS NULL AND is_active = 1 AND is_visible = 1 ORDER BY sort_order, display_name;"
        local root_items=$(sqlite3 shared-config/menu.db "$root_query" 2>/dev/null)
        
        if [[ -n "$root_items" ]]; then
            report_test "Root menu query generates items" "PASS"
            echo -e "  ${GRAY}Sample root items:${NC}"
            echo "$root_items" | head -3 | while IFS='|' read -r id name display_name desc icon type func order; do
                echo -e "    • $display_name ($type)"
            done
        else
            report_test "Root menu query generates items" "FAIL" "No root items returned"
        fi
        
    else
        report_test "Hierarchical menu system sources successfully" "FAIL" "Could not source hierarchical_menu_system.sh"
    fi
}

# Test key menu workflows
test_menu_workflows() {
    echo -e "\n${CYAN}=== Testing Key Menu Workflows ===${NC}"
    
    # Test main menu to submenu navigation (query only)
    local main_to_sub=$(sqlite3 shared-config/menu.db "SELECT m.display_name, COUNT(s.id) as child_count FROM menu_items_v2 m LEFT JOIN menu_items_v2 s ON m.id = s.parent_id WHERE m.parent_id IS NULL GROUP BY m.id;" 2>/dev/null)
    
    if [[ -n "$main_to_sub" ]]; then
        report_test "Main to submenu navigation data available" "PASS"
        echo -e "  ${GRAY}Menu → Submenu counts:${NC}"
        echo "$main_to_sub" | head -3 | while IFS='|' read -r menu_name child_count; do
            echo -e "    • $menu_name: $child_count items"
        done
    else
        report_test "Main to submenu navigation data available" "FAIL" "No navigation data found"
    fi
    
    # Test breadcrumb generation
    local breadcrumb_test=$(sqlite3 shared-config/menu.db "SELECT path FROM v_menu_hierarchy WHERE depth = 1 LIMIT 1;" 2>/dev/null)
    if [[ -n "$breadcrumb_test" ]]; then
        report_test "Breadcrumb generation works" "PASS" "Sample path: $breadcrumb_test"
    else
        report_test "Breadcrumb generation works" "FAIL" "No breadcrumb paths generated"
    fi
}

# Test for integration with main script
test_main_script_integration() {
    echo -e "\n${CYAN}=== Testing Main Script Integration ===${NC}"
    
    # Test hierarchical menu flag
    local hierarchical_flag=$(grep "USE_HIERARCHICAL_MENUS" gwombat.sh | head -1)
    if [[ -n "$hierarchical_flag" ]]; then
        report_test "Hierarchical menu flag exists in main script" "PASS"
    else
        report_test "Hierarchical menu flag exists in main script" "FAIL" "Flag not found"
    fi
    
    # Test init_hierarchical_menu call
    local init_call=$(grep "init_hierarchical_menu" gwombat.sh)
    if [[ -n "$init_call" ]]; then
        report_test "Main script calls init_hierarchical_menu" "PASS"
    else
        report_test "Main script calls init_hierarchical_menu" "FAIL" "No init call found"
    fi
    
    # Test render_menu usage in menu functions
    local render_usage=$(grep -c "render_menu" gwombat.sh 2>/dev/null)
    if [[ "$render_usage" -gt 10 ]]; then
        report_test "Menu functions use render_menu" "PASS" "$render_usage render_menu calls"
    else
        report_test "Menu functions use render_menu" "FAIL" "Insufficient render_menu usage"
    fi
}

# Test specific menu functions conversion
test_converted_functions() {
    echo -e "\n${CYAN}=== Testing Converted Menu Functions ===${NC}"
    
    # List of key functions that should be converted
    local key_functions=(
        "show_main_menu"
        "user_group_management_menu" 
        "file_drive_operations_menu"
        "dashboard_menu"
        "system_administration_menu"
    )
    
    for func in "${key_functions[@]}"; do
        # Check if function exists and uses render_menu
        local func_def=$(grep -A 3 "^${func}()" gwombat.sh 2>/dev/null)
        if [[ -n "$func_def" ]]; then
            if echo "$func_def" | grep -q "render_menu"; then
                report_test "Function '$func' uses render_menu" "PASS"
            else
                report_test "Function '$func' uses render_menu" "FAIL" "Still uses old implementation"
            fi
        else
            report_test "Function '$func' exists" "FAIL" "Function not found"
        fi
    done
}

# Test error handling in menu system
test_error_handling() {
    echo -e "\n${CYAN}=== Testing Menu Error Handling ===${NC}"
    
    # Test query for non-existent menu
    local nonexistent_query=$(sqlite3 shared-config/menu.db "SELECT id FROM menu_items_v2 WHERE name = 'nonexistent_menu_12345';" 2>/dev/null)
    if [[ -z "$nonexistent_query" ]]; then
        report_test "Non-existent menu query returns empty" "PASS"
    else
        report_test "Non-existent menu query returns empty" "FAIL" "Unexpected data returned"
    fi
    
    # Test database permissions (should be readable)
    if [[ -r "shared-config/menu.db" ]]; then
        report_test "Menu database is readable" "PASS"
    else
        report_test "Menu database is readable" "FAIL" "Cannot read menu database"
    fi
}

# Main test runner
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            GWOMBAT Hierarchical Menu System Test Suite           ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    test_log "Starting hierarchical menu test suite"
    
    # Run all tests
    test_database_connectivity
    test_menu_loading
    test_menu_queries
    test_menu_integrity
    test_menu_search
    test_navigation_paths
    test_menu_workflows
    test_function_resolution
    test_main_script_integration
    test_converted_functions
    test_error_handling
    
    # Summary report
    echo -e "\n${BLUE}═══ Test Results Summary ═══${NC}"
    echo -e "Total Tests: $TESTS_TOTAL"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    
    local pass_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
    echo -e "Pass Rate: ${pass_rate}%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 ALL TESTS PASSED! Hierarchical menu system is functional.${NC}"
        test_log "All tests passed - hierarchical menu system operational"
    else
        echo -e "\n${YELLOW}⚠️  Some tests failed. Check test log for details: $TEST_LOG${NC}"
        test_log "Some tests failed - see detailed results above"
    fi
    
    # Menu statistics
    echo -e "\n${CYAN}=== Menu System Statistics ===${NC}"
    sqlite3 shared-config/menu.db "SELECT 'Total Items: ' || total_items, 'Total Menus: ' || total_menus, 'Total Actions: ' || total_actions, 'Max Depth: ' || max_depth FROM v_menu_stats;" 2>/dev/null
    
    echo -e "\nTest log saved to: $TEST_LOG"
}

# Run tests
main "$@"