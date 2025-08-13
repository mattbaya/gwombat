#!/bin/bash

# Script to update all menus with 'm' and 'x' options
# This will add main menu and exit options to all submenus

SCRIPT_FILE="/Users/mjb9/mjb9-gamera/suspended/temphold-master/temphold-master.sh"

# Function to update menu display with m/x options
update_menu_display() {
    local pattern="$1"
    local replacement="$2"
    
    sed -i '' "s|$pattern|$replacement|g" "$SCRIPT_FILE"
}

# Function to update case statements with m/x options
update_case_statement() {
    local return_case="$1"
    local max_option="$2"
    
    # Create the replacement pattern
    local old_pattern="${return_case}) return ;;
            \*)
                echo -e \"\\\${RED}Invalid option. Please select 1-${max_option}.\\\${NC}\"
                read -p \"Press Enter to continue...\"
                ;;"
                
    local new_pattern="${return_case}) return ;;
            m|M) return ;;
            x|X) exit 0 ;;
            \*)
                echo -e \"\\\${RED}Invalid option. Please select 1-${max_option}, m, or x.\\\${NC}\"
                read -p \"Press Enter to continue...\"
                ;;"
    
    # Use a temporary file to avoid sed issues with special characters
    local temp_file=$(mktemp)
    cp "$SCRIPT_FILE" "$temp_file"
    
    # Use perl for more reliable multi-line replacement
    perl -i -pe "s/\Q$old_pattern\E/$new_pattern/g" "$temp_file" 2>/dev/null || echo "Pattern not found: $return_case"
    
    # Check if replacement was successful
    if grep -q "m|M) return" "$temp_file"; then
        cp "$temp_file" "$SCRIPT_FILE"
        echo "Updated case statement for return case: $return_case"
    else
        echo "Failed to update case statement for return case: $return_case"
    fi
    
    rm -f "$temp_file"
}

echo "Starting menu updates..."

# Stage 4: Final Decisions Menu (6 options)
echo "Updating stage4_final_decisions_menu..."

# Update display
sed -i '' 's/echo "6\. Return to main menu"/echo ""\
        echo "6. Return to main menu"\
        echo "m. Main menu"\
        echo "x. Exit"/g' "$SCRIPT_FILE"

sed -i '' 's/read -p "Select an option (1-7):" stage4_choice/read -p "Select an option (1-7, m, x):" stage4_choice/g' "$SCRIPT_FILE"

# Stage 5: Deletion Operations Menu (5 options)
echo "Updating stage5_deletion_operations_menu..."

sed -i '' 's/echo "5\. Return to main menu"/echo ""\
        echo "5. Return to main menu"\
        echo "m. Main menu"\
        echo "x. Exit"/g' "$SCRIPT_FILE"

sed -i '' 's/read -p "Select an option (1-6):" stage5_choice/read -p "Select an option (1-6, m, x):" stage5_choice/g' "$SCRIPT_FILE"

echo "Menu display updates completed. You will need to manually update the case statements for the remaining menus."
echo "Remaining case statements to update:"
echo "- stage4_final_decisions_menu (case 7)"
echo "- stage5_deletion_operations_menu (case 6)" 
echo "- All other submenus (reports, config, audit, shared_drive, license, orphan, sharing, discovery, admin)"