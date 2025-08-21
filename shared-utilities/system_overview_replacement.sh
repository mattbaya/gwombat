# This is the new SQLite-driven system_overview_menu function to replace the hardcoded version

# System Overview Menu - SQLite-driven implementation  
system_overview_menu() {
    # Source database functions if not already loaded
    if ! type generate_submenu >/dev/null 2>&1; then
        source "$SHARED_UTILITIES_PATH/database_functions.sh" 2>/dev/null || {
            echo -e "${RED}Error: Cannot load database functions${NC}"
            return 1
        }
    fi
    
    local MENU_DB_FILE="${SCRIPTPATH}/shared-config/menu.db"
    
    while true; do
        clear
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}                           GWOMBAT - System Overview                            ${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Show current system status at the top (keep existing status display)
        echo -e "${CYAN}📊 Current System Status:${NC}"
        
        # Quick system health indicators
        local db_status="❌"
        local gam_status="❌" 
        local tools_status="❌"
        
        # Check database connectivity
        if sqlite3 local-config/gwombat.db "SELECT 1;" >/dev/null 2>&1; then
            db_status="✅"
        fi
        
        # Check GAM availability
        if [[ -x "$GAM" ]] && $GAM info domain >/dev/null 2>&1; then
            gam_status="✅"
        fi
        
        # Check external tools
        local tool_count=0
        [[ -x "$(command -v gyb)" ]] && ((tool_count++))
        [[ -x "$(command -v rclone)" ]] && ((tool_count++))
        if [[ $tool_count -gt 0 ]]; then
            tools_status="✅ ($tool_count/2)"
        fi
        
        echo -e "  ${WHITE}Database:${NC} $db_status  |  ${WHITE}GAM:${NC} $gam_status  |  ${WHITE}External Tools:${NC} $tools_status"
        echo ""
        
        # Generate menu options from database with grouping
        echo -e "${GREEN}=== SYSTEM OVERVIEW OPTIONS ===${NC}"
        
        # Display items in groups
        local current_group=""
        local item_count=0
        
        while IFS='|' read -r item_order display_name description icon keywords; do
            [[ -z "$item_order" ]] && continue
            
            # Group items for better organization
            local new_group=""
            if [[ $item_order -le 5 ]]; then
                new_group="System Overview"
            elif [[ $item_order -le 10 ]]; then
                new_group="Maintenance & Tools"
            else
                new_group="Information & Help"
            fi
            
            # Display group header if changed
            if [[ "$new_group" != "$current_group" ]]; then
                if [[ $item_count -gt 0 ]]; then
                    echo ""
                fi
                if [[ "$new_group" == "Maintenance & Tools" ]]; then
                    echo -e "${PURPLE}=== MAINTENANCE & TOOLS ===${NC}"
                elif [[ "$new_group" == "Information & Help" ]]; then
                    echo -e "${YELLOW}=== INFORMATION & HELP ===${NC}"
                fi
                current_group="$new_group"
            fi
            
            echo "$item_order. $icon $display_name ($description)"
            ((item_count++))
            
        done < <(sqlite3 "$MENU_DB_FILE" "
            SELECT item_order, display_name, description, icon, keywords
            FROM menu_items 
            WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_overview')
            AND is_active = 1 
            ORDER BY item_order;
        ")
        
        # Navigation options
        echo ""
        echo "b. ⬅️ Back to Dashboard & Statistics"
        echo "m. 🏠 Main menu"
        echo "s. 🔍 Search all menu options"
        echo "x. ❌ Exit"
        echo ""
        
        # Get user choice
        read -p "Select an option (1-$item_count, b, m, s, x): " overview_choice
        
        case "$overview_choice" in
            [1-9]|1[0-5]) 
                # Get function name from database
                local function_name=$(sqlite3 "$MENU_DB_FILE" "
                    SELECT function_name 
                    FROM menu_items 
                    WHERE section_id = (SELECT id FROM menu_sections WHERE name = 'system_overview')
                    AND item_order = '$overview_choice'
                    AND is_active = 1;
                ")
                
                if [[ -n "$function_name" ]]; then
                    echo ""
                    echo -e "${CYAN}Launching: $function_name${NC}"
                    
                    # Call the function (with fallback to placeholder)
                    if type "$function_name" >/dev/null 2>&1; then
                        "$function_name"
                    else
                        echo -e "${YELLOW}Function '$function_name' is not yet implemented${NC}"
                        echo "This feature is planned for future development."
                        read -p "Press Enter to continue..."
                    fi
                else
                    echo -e "${RED}Invalid option${NC}"
                    read -p "Press Enter to continue..."
                fi
                ;;
            b|B) return ;;
            m|M) main_menu ;;
            s|S) search_all_menus ;;
            x|X) exit 0 ;;
            *) 
                echo -e "${RED}Invalid option. Please select a valid choice.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}