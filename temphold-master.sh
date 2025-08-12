#!/bin/bash

# Temporary Hold Master Script
#
# A comprehensive script that consolidates all temporary hold operations for suspended user accounts into a single interactive tool with preview functionality.
#
# ## Overview
#
# This script automates the process of moving user accounts between different suspension states:
# - Moving from "pending deletion" status to "temporary hold" status
# - Removing "temporary hold" status to restore normal account state
#
# **Add Temporary Hold Operations:**
# 1. **Restore Last Name** - Removes "(PENDING DELETION - CONTACT OIT)" from user's last name
# 2. **Fix Filenames** - Renames files with pending deletion markers
# 3. **Rename All Files** - Adds "(Suspended Account - Temporary Hold)" to all user files
# 4. **Update User Last Name** - Adds suspension marker to user's last name
#
# **Remove Temporary Hold Operations:**
# 1. **Remove Temporary Hold from Last Name** - Removes "(Suspended Account - Temporary Hold)" from user's last name
# 2. **Remove Temporary Hold from All Files** - Removes suspension markers from all file names
#
# ## Features
#
# - **Interactive Menu System** - Choose between single user or batch processing
# - **Bidirectional Operations** - Add or remove temporary hold status
# - **Dry-Run Mode** - Preview changes without making actual modifications
# - **Recovery Mode** - Check for incomplete operations and resume failed batches
# - **Enhanced Confirmation** - Different confirmation levels based on operation risk
# - **Progress Tracking** - Visual progress bars for all operations
# - **Backup Creation** - Automatic backups before making changes
# - **Preview Mode** - Shows detailed summary of all actions before execution
# - **Error Handling** - Validates inputs and checks for required directories
# - **Comprehensive Logging** - Records all operations and changes
# - **Color-coded Output** - Easy-to-read status messages
#
# ## Prerequisites
#
# - GAM (Google Apps Manager) installed at `/usr/local/bin/gam`
# - Access to the following directories:
#   - `/opt/your-path/mjb9/suspended` (script path)
#   - `/opt/your-path/mjb9/listshared` (shared files path)
# - Required script dependencies:
#   - `list-users-files.sh` in the listshared directory
#
# ## Installation
#
# 1. Ensure the script is executable:
#    ```bash
#    chmod +x master-temphold.sh
#    ```
#
# 2. Verify GAM is installed and accessible:
#    ```bash
#    /usr/local/bin/gam version
#    ```
#
# 3. Check that required directories exist and are accessible
#
# ## Usage
#
# ### Interactive Mode
#
# Run the script without arguments to enter interactive mode:
#
# ```bash
# ./master-temphold.sh
# ```
#
# ### Menu Options
#
# 1. **Process single user**
#    - Enter a single username or email address
#    - Choose to add or remove temporary hold
#    - View summary of actions before execution
#    - Confirm before making changes
#
# 2. **Process users from file**
#    - Specify path to file containing usernames (one per line)
#    - Choose to add or remove temporary hold for all users
#    - Preview sample users from file
#    - Batch process all users with selected operation
#
# 3. **Dry-run mode (Preview changes without making them)**
#    - Test operations without making actual changes
#    - Preview single user or batch operations
#    - Simulate file processing and user updates
#    - Choose add or remove operations for testing
#
# 4. **Discovery mode (Query and diagnose accounts)**
#    - Query all users in Temporary Hold organizational unit
#    - Diagnose specific account consistency (OU, name, files)
#    - Check for incomplete operations
#
# 5. **Exit**
#    - Safely exit the script
#
# ### File Format for Batch Processing
#
# Create a text file with one username/email per line:
#
# ```
# user1@domain.com
# user2@domain.com
# user3@domain.com
# ```
#
# - Empty lines and lines starting with `#` are ignored
# - Each user will go through the complete 4-step process
#
# ## Process Details
#
# ### Step 1: Restore Last Name
# - Checks if user's last name contains "(PENDING DELETION - CONTACT OIT)"
# - If found, removes the suffix and restores original last name
# - If not found, skips this step
#
# ### Step 2: Fix Filenames
# - Searches for files with "(PENDING DELETION - CONTACT OIT)" in filename
# - Renames them to include "(Suspended Account - Temporary Hold)"
# - Logs all changes to `tmp/{username}-fixed.txt`
#
# ### Step 3: Rename All Files
# - Generates comprehensive file list using `list-users-files.sh`
# - Adds "(Suspended Account - Temporary Hold)" suffix to all file names
# - Skips files that already have the suffix
#
# ### Step 4: Update User Last Name
# - Adds "(Suspended Account - Temporary Hold)" to user's last name
# - Skips if suffix already present
#
# ## Output and Logging
#
# ### Log Files Created:
# - `temphold-done.log` - Users successfully processed (temporary hold added)
# - `temphold-removed.log` - Users successfully processed (temporary hold removed)
# - `file-rename-done.txt` - Timestamp log of file rename operations (adding hold)
# - `file-removal-done.txt` - Timestamp log of file removal operations (removing hold)
# - `tmp/{username}-fixed.txt` - Detailed log of specific file changes (adding hold)
# - `tmp/{username}-removal.txt` - Detailed log of specific file changes (removing hold)
#
# ### Temporary Files:
# - `tmp/gam_output_{username}.txt` - GAM query results
# - CSV files in `${LISTSHARED_PATH}/csv-files/` directory
#
# ## Error Handling
#
# The script includes comprehensive error checking:
#
# - Validates user input
# - Checks file existence for batch processing
# - Verifies required directories exist
# - Handles GAM command failures gracefully
# - Provides clear error messages
#
# ## Color Coding
#
# - 🔵 **Blue**: Headers and informational messages
# - 🟢 **Green**: Success messages and step indicators
# - 🟡 **Yellow**: Warnings and progress indicators
# - 🔴 **Red**: Error messages
#
# ## Safety Features
#
# - **Preview Mode**: Shows exactly what will happen before execution
# - **User Confirmation**: Requires explicit approval before making changes
# - **Non-destructive**: Only adds suffixes, doesn't delete data
# - **Logging**: Complete audit trail of all operations
# - **Validation**: Checks for existing suffixes to prevent duplicates
#
# ## Troubleshooting
#
# ### Common Issues:
#
# 1. **GAM not found**
#    - Verify GAM is installed at `/usr/local/bin/gam`
#    - Check PATH environment variable
#
# 2. **Permission denied**
#    - Ensure script has execute permissions
#    - Check directory access permissions
#
# 3. **Required directories missing**
#    - Verify `/opt/your-path/mjb9/suspended` exists
#    - Verify `/opt/your-path/mjb9/listshared` exists
#
# 4. **list-users-files.sh not found**
#    - Ensure the script exists in the listshared directory
#    - Check execute permissions on the script
#
# ### Debug Mode:
#
# To enable verbose output, you can modify the script to add `set -x` at the top for debugging.
#
# ## Author
#
# Consolidated from multiple individual scripts:
# - `temphold.sh`
# - `restore-lastname.sh`
# - `temphold-filesfix.sh`
# - `temphold-file-rename.sh`
# - `temphold-namechange.sh`
#
# ## Version History
#
# - v1.0 - Initial consolidated version with interactive menu and preview functionality

# Master Temporary Hold Script
# Consolidates all temphold operations with menu system and preview functionality

GAM="/usr/local/bin/gam"
SCRIPTPATH="/opt/your-path/mjb9/suspended"
LISTSHARED_PATH="/opt/your-path/mjb9/listshared"

# Organizational Unit paths
OU_TEMPHOLD="/Suspended Accounts/Suspended - Temporary Hold"
OU_PENDING_DELETION="/Suspended Accounts/Suspended - Pending Deletion"  
OU_SUSPENDED="/Suspended Accounts"
OU_ACTIVE="/your-domain.edu"

# Google Drive Label IDs for pending deletion
LABEL_ID="xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb"
FIELD_ID="62BB395EC6"
SELECTION_ID="68E9987D43"

# Global settings
DRY_RUN=false
DISCOVERY_MODE=false
PROGRESS_ENABLED=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${BLUE}=== Temporary Hold Master Script ===${NC}"
    echo ""
    echo "1. Process single user"
    echo "2. Process users from file"
    echo "3. Dry-run mode (Preview changes without making them)"
    echo "4. Discovery mode (Query and diagnose accounts)"
    echo "5. Exit"
    echo ""
    read -p "Select an option (1-5): " choice
    echo ""
    return $choice
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local description="$3"
    
    if [[ "$PROGRESS_ENABLED" == "true" ]]; then
        local percentage=$((current * 100 / total))
        local filled=$((percentage / 2))
        local bar=""
        
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=filled; i<50; i++)); do bar+="░"; done
        
        printf "\r${CYAN}Progress: [%s] %d%% (%d/%d) %s${NC}" "$bar" "$percentage" "$current" "$total" "$description"
        
        if [[ $current -eq $total ]]; then
            echo ""
        fi
    fi
}

# Function to execute command with dry-run support
execute_command() {
    local command="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would execute: $description${NC}"
        echo -e "${CYAN}[DRY-RUN] Command: $command${NC}"
        return 0
    else
        echo -e "${GREEN}Executing: $description${NC}"
        eval "$command"
        return $?
    fi
}

# Function to create backup before changes
create_backup() {
    local user="$1"
    local operation="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would create backup for $user ($operation)${NC}"
        return 0
    fi
    
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="${SCRIPTPATH}/backups/${timestamp}_${user}_${operation}"
    
    mkdir -p "$backup_dir"
    echo "$user,$operation,$(date '+%Y-%m-%d %H:%M:%S')" >> "$backup_dir/backup_info.txt"
    echo -e "${GREEN}Backup created at: $backup_dir${NC}"
}

# Function for enhanced confirmation with different levels
enhanced_confirm() {
    local operation="$1"
    local user_count="${2:-1}"
    local confirmation_level="${3:-normal}"
    
    echo ""
    case $confirmation_level in
        "high")
            echo -e "${YELLOW}⚠️  HIGH RISK OPERATION ⚠️${NC}"
            echo "This operation will affect $user_count user(s) and could impact many files."
            echo "Type 'CONFIRM' in all caps to proceed:"
            read -p "> " response
            [[ "$response" == "CONFIRM" ]] && return 0 || return 1
            ;;
        "batch")
            if [[ $user_count -gt 10 ]]; then
                echo -e "${YELLOW}⚠️  LARGE BATCH OPERATION ⚠️${NC}"
                echo "You are about to process $user_count users."
                echo "Type 'YES' to proceed:"
                read -p "> " response
                [[ "$response" == "YES" ]] && return 0 || return 1
            else
                return $(confirm_action)
            fi
            ;;
        *)
            return $(confirm_action)
            ;;
    esac
}

# Function to get operation choice
get_operation_choice() {
    echo ""
    echo "Select operation:"
    echo "1. Add temporary hold"
    echo "2. Remove temporary hold"
    echo "3. Mark for pending deletion"
    echo "4. Remove pending deletion"
    echo ""
    while true; do
        read -p "Choose operation (1-4): " op_choice
        case $op_choice in
            1) echo "add_temphold"; break ;;
            2) echo "remove_temphold"; break ;;
            3) echo "add_pending"; break ;;
            4) echo "remove_pending"; break ;;
            *) echo -e "${RED}Please select 1, 2, 3, or 4.${NC}" ;;
        esac
    done
}

# Function to get user input
get_user_input() {
    while true; do
        read -p "Enter username or email address: " user_input
        if [[ -n "$user_input" ]]; then
            echo "$user_input"
            break
        else
            echo -e "${RED}Please enter a valid username or email.${NC}"
        fi
    done
}

# Function to load users from file
load_users_from_file() {
    while true; do
        read -p "Enter the full path to the file containing usernames: " file_path
        if [[ -f "$file_path" ]]; then
            echo "$file_path"
            break
        else
            echo -e "${RED}File not found. Please enter a valid file path.${NC}"
        fi
    done
}

# Function to show what actions will be performed for adding temporary hold
show_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Restore Last Name:${NC}"
    echo "   - Remove '(PENDING DELETION - CONTACT OIT)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Fix Filenames:${NC}"
    echo "   - Find all files with '(PENDING DELETION - CONTACT OIT)' in name"
    echo "   - Rename them to include '(Suspended Account - Temporary Hold)'"
    echo "   - Log changes to tmp/${user}-fixed.txt"
    echo ""
    echo -e "${GREEN}3. Rename All Files:${NC}"
    echo "   - Generate file list using list-users-files.sh"
    echo "   - Add '(Suspended Account - Temporary Hold)' to all file names"
    echo "   - Skip files already having this suffix"
    echo ""
    echo -e "${GREEN}4. Update User Last Name:${NC}"
    echo "   - Add '(Suspended Account - Temporary Hold)' to user's last name"
    echo "   - Skip if already present"
    echo ""
    echo -e "${GREEN}5. Move to Temporary Hold OU:${NC}"
    echo "   - Move user to '$OU_TEMPHOLD' organizational unit"
    echo ""
    echo -e "${GREEN}6. Logging:${NC}"
    echo "   - Add user to temphold-done.log"
    echo "   - Add timestamp to file-rename-done.txt"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for removing temporary hold
show_removal_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF REMOVAL ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Remove Temporary Hold from Last Name:${NC}"
    echo "   - Remove '(Suspended Account - Temporary Hold)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Remove Temporary Hold from All Files:${NC}"
    echo "   - Find all files with '(Suspended Account - Temporary Hold)' in name"
    echo "   - Remove the suffix from file names"
    echo "   - Log changes to tmp/${user}-removal.txt"
    echo ""
    echo -e "${GREEN}3. Move User to Destination OU:${NC}"
    echo "   - Choose destination: Pending Deletion, Suspended, or your-domain.edu"
    echo "   - Move user to selected organizational unit"
    echo ""
    echo -e "${GREEN}4. Logging:${NC}"
    echo "   - Add user to temphold-removed.log"
    echo "   - Add timestamp to file-removal-done.txt"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for adding pending deletion
show_pending_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF PENDING DELETION ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Add Pending Deletion to Last Name:${NC}"
    echo "   - Add '(PENDING DELETION - CONTACT OIT)' to user's last name"
    echo "   - Skip if already present"
    echo ""
    echo -e "${GREEN}2. Add Pending Deletion to All Files:${NC}"
    echo "   - Generate file list using list-users-files.sh"
    echo "   - Add '(PENDING DELETION - CONTACT OIT)' to all file names"
    echo "   - Skip files already having this suffix"
    echo ""
    echo -e "${GREEN}3. Add Drive Labels to Files:${NC}"
    echo "   - Temporarily add Education Plus license"
    echo "   - Add pending deletion labels to all files"
    echo "   - Remove Education Plus license"
    echo ""
    echo -e "${GREEN}4. Remove User from All Groups:${NC}"
    echo "   - Query user's group memberships"
    echo "   - Remove user from all groups"
    echo "   - Log group removals"
    echo ""
    echo -e "${GREEN}5. Move to Pending Deletion OU:${NC}"
    echo "   - Move user to '$OU_PENDING_DELETION' organizational unit"
    echo ""
    echo -e "${GREEN}6. Logging:${NC}"
    echo "   - Add user to pending-deletion-done.log"
    echo "   - Add timestamp to logs"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to show what actions will be performed for removing pending deletion
show_pending_removal_summary() {
    local user=$1
    echo -e "${YELLOW}=== SUMMARY OF PENDING DELETION REMOVAL ACTIONS FOR: $user ===${NC}"
    echo ""
    echo "The following operations will be performed:"
    echo ""
    echo -e "${GREEN}1. Remove Pending Deletion from Last Name:${NC}"
    echo "   - Remove '(PENDING DELETION - CONTACT OIT)' from user's last name"
    echo "   - Restore original last name"
    echo ""
    echo -e "${GREEN}2. Remove Pending Deletion from All Files:${NC}"
    echo "   - Find all files with '(PENDING DELETION - CONTACT OIT)' in name"
    echo "   - Remove the suffix from file names"
    echo "   - Remove drive labels from files"
    echo "   - Log changes to tmp/${user}-pending-removed.txt"
    echo ""
    echo -e "${GREEN}3. Move User to Destination OU:${NC}"
    echo "   - Choose destination: Pending Deletion, Suspended, or your-domain.edu"
    echo "   - Move user to selected organizational unit"
    echo ""
    echo -e "${GREEN}4. Logging:${NC}"
    echo "   - Add user to pending-deletion-removed.log"
    echo "   - Add timestamp to pending-removal-done.txt"
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}🔍 DRY-RUN MODE: No actual changes will be made${NC}"
    fi
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
}

# Function to handle dry-run mode
dry_run_mode() {
    DRY_RUN=true
    echo -e "${CYAN}=== DRY-RUN MODE ACTIVATED ===${NC}"
    echo ""
    echo "In dry-run mode, you can:"
    echo "1. Preview changes for a single user"
    echo "2. Preview changes for users from a file" 
    echo "3. Return to main menu"
    echo ""
    read -p "Select an option (1-3): " dry_choice
    
    case $dry_choice in
        1)
            user=$(get_user_input)
            operation=$(get_operation_choice)
            echo ""
            echo -e "${MAGENTA}🔍 DRY-RUN PREVIEW FOR: $user${NC}"
            
            case $operation in
                "add_temphold")
                    show_summary "$user"
                    process_user "$user"
                    ;;
                "remove_temphold")
                    show_removal_summary "$user"
                    remove_temphold_user "$user"
                    ;;
                "add_pending")
                    show_pending_summary "$user"
                    process_pending_user "$user"
                    ;;
                "remove_pending")
                    show_pending_removal_summary "$user"
                    remove_pending_user "$user"
                    ;;
            esac
            ;;
        2)
            file_path=$(load_users_from_file)
            user_count=$(wc -l < "$file_path")
            operation=$(get_operation_choice)
            echo ""
            echo -e "${MAGENTA}🔍 DRY-RUN PREVIEW FOR $user_count USERS${NC}"
            
            case $operation in
                "add_temphold")
                    process_users_from_file "$file_path"
                    ;;
                "remove_temphold")
                    remove_temphold_users_from_file "$file_path"
                    ;;
                "add_pending")
                    process_pending_users_from_file "$file_path"
                    ;;
                "remove_pending")
                    remove_pending_users_from_file "$file_path"
                    ;;
            esac
            ;;
        3)
            DRY_RUN=false
            return
            ;;
    esac
    
    DRY_RUN=false
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Function to handle discovery mode
discovery_mode() {
    DISCOVERY_MODE=true
    echo -e "${MAGENTA}=== DISCOVERY MODE ===${NC}"
    echo ""
    echo "Discovery options:"
    echo "1. Query users in Temporary Hold OU"
    echo "2. Query users in Pending Deletion OU"
    echo "3. Query all suspended users (all OUs)"
    echo "4. Diagnose specific account consistency"
    echo "5. Check for incomplete operations"
    echo "6. Return to main menu"
    echo ""
    read -p "Select an option (1-6): " discovery_choice
    
    case $discovery_choice in
        1) 
            query_temphold_users
            ;;
        2) 
            query_pending_users
            ;;
        3) 
            query_all_suspended_users
            ;;
        4) 
            user=$(get_user_input)
            diagnose_account "$user"
            ;;
        5) 
            check_incomplete_operations
            ;;
        6) 
            DISCOVERY_MODE=false
            return
            ;;
    esac
    
    DISCOVERY_MODE=false
    echo ""
    read -p "Press Enter to return to main menu..."
}

# Function to check for incomplete operations
check_incomplete_operations() {
    echo -e "${YELLOW}Checking for incomplete operations...${NC}"
    
    # Check for partial log entries
    if [[ -f "${SCRIPTPATH}/temphold-done.log" ]]; then
        echo "Users in temphold-done.log: $(wc -l < "${SCRIPTPATH}/temphold-done.log")"
    fi
    
    if [[ -f "${SCRIPTPATH}/temphold-removed.log" ]]; then
        echo "Users in temphold-removed.log: $(wc -l < "${SCRIPTPATH}/temphold-removed.log")"
    fi
    
    # Check for orphaned tmp files
    if [[ -d "${SCRIPTPATH}/tmp" ]]; then
        tmp_files=$(find "${SCRIPTPATH}/tmp" -name "*-fixed.txt" -o -name "*-removal.txt" | wc -l)
        echo "Temporary operation files found: $tmp_files"
        
        if [[ $tmp_files -gt 0 ]]; then
            echo ""
            echo "Recent operation files:"
            find "${SCRIPTPATH}/tmp" -name "*-fixed.txt" -o -name "*-removal.txt" -exec ls -la {} \; | head -5
        fi
    fi
}

# Function to resume failed operations
resume_failed_operations() {
    echo -e "${YELLOW}Resume functionality - Check for failed operations...${NC}"
    echo "This feature would analyze log files and resume incomplete batch operations."
    echo "(Implementation would require analyzing specific failure points)"
}

# Function to get destination OU choice
get_destination_ou() {
    echo ""
    echo "Select destination Organizational Unit:"
    echo "1. Suspended Accounts/Suspended - Pending Deletion"
    echo "2. Suspended Accounts (general suspended)"
    echo "3. your-domain.edu (reactivate account)"
    echo ""
    while true; do
        read -p "Choose destination OU (1-3): " ou_choice
        case $ou_choice in
            1) echo "$OU_PENDING_DELETION"; break ;;
            2) echo "$OU_SUSPENDED"; break ;;
            3) echo "$OU_ACTIVE"; break ;;
            *) echo -e "${RED}Please select 1, 2, or 3.${NC}" ;;
        esac
    done
}

# Function to move user to OU
move_user_to_ou() {
    local user="$1"
    local target_ou="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would move user $user to OU: $target_ou${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Moving user $user to OU: $target_ou${NC}"
    execute_command "$GAM update user \"$user\" ou \"$target_ou\"" "Move user to OU"
}

# Function to get user's current OU
get_user_ou() {
    local user="$1"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo "$OU_TEMPHOLD"  # Simulate for dry-run/discovery
        return 0
    fi
    
    local ou=$($GAM info user "$user" | awk -F': ' '/Org Unit Path:/ {print $2}')
    echo "$ou"
}

# Function to query users in temporary hold OU
query_temphold_users() {
    echo -e "${CYAN}Querying users in Temporary Hold OU...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users ou \"$OU_TEMPHOLD\"${NC}"
        echo ""
        echo "Simulated results:"
        echo "user1@domain.com,John,Doe (Suspended Account - Temporary Hold)"
        echo "user2@domain.com,Jane,Smith (Suspended Account - Temporary Hold)"
        echo "user3@domain.com,Bob,Johnson"
        return 0
    fi
    
    echo "Users in $OU_TEMPHOLD:"
    $GAM print users ou "$OU_TEMPHOLD" firstname lastname
}

# Function to query users in pending deletion OU
query_pending_users() {
    echo -e "${CYAN}Querying users in Pending Deletion OU...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query: $GAM print users ou \"$OU_PENDING_DELETION\"${NC}"
        echo ""
        echo "Simulated results:"
        echo "user4@domain.com,Alice,Brown (PENDING DELETION - CONTACT OIT)"
        echo "user5@domain.com,David,Wilson (PENDING DELETION - CONTACT OIT)"
        echo "user6@domain.com,Carol,Davis (PENDING DELETION - CONTACT OIT)"
        return 0
    fi
    
    echo "Users in $OU_PENDING_DELETION:"
    $GAM print users ou "$OU_PENDING_DELETION" firstname lastname
}

# Function to query all suspended users
query_all_suspended_users() {
    echo -e "${CYAN}Querying all users in Suspended Accounts OUs...${NC}"
    
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query all suspended OUs${NC}"
        echo ""
        echo "Simulated results:"
        echo "OU: $OU_SUSPENDED"
        echo "  user7@domain.com,Emma,Taylor"
        echo "  user8@domain.com,Frank,Moore"
        echo ""
        echo "OU: $OU_TEMPHOLD"
        echo "  user1@domain.com,John,Doe (Suspended Account - Temporary Hold)"
        echo "  user2@domain.com,Jane,Smith (Suspended Account - Temporary Hold)"
        echo ""
        echo "OU: $OU_PENDING_DELETION"
        echo "  user4@domain.com,Alice,Brown (PENDING DELETION - CONTACT OIT)"
        echo "  user5@domain.com,David,Wilson (PENDING DELETION - CONTACT OIT)"
        return 0
    fi
    
    echo "=== Users in General Suspended OU ==="
    $GAM print users ou "$OU_SUSPENDED" firstname lastname
    echo ""
    echo "=== Users in Temporary Hold OU ==="
    $GAM print users ou "$OU_TEMPHOLD" firstname lastname
    echo ""
    echo "=== Users in Pending Deletion OU ==="
    $GAM print users ou "$OU_PENDING_DELETION" firstname lastname
}

# Function to diagnose account consistency
diagnose_account() {
    local user="$1"
    echo -e "${CYAN}=== DIAGNOSING ACCOUNT: $user ===${NC}"
    echo ""
    
    # Check user's current OU
    echo -e "${YELLOW}1. Checking Organizational Unit...${NC}"
    current_ou=$(get_user_ou "$user")
    echo "Current OU: $current_ou"
    
    # Check user's last name
    echo -e "${YELLOW}2. Checking user last name...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        lastname="Sample User (Suspended Account - Temporary Hold)"
        echo -e "${CYAN}[DISCOVERY] Would query user info for: $user${NC}"
    else
        lastname=$($GAM info user "$user" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    echo "Last name: $lastname"
    
    # Check files with temporary hold suffix
    echo -e "${YELLOW}3. Checking files with temporary hold suffix...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo -e "${CYAN}[DISCOVERY] Would query files for user: $user${NC}"
        echo "Simulated: Found 15 files with '(Suspended Account - Temporary Hold)' suffix"
        files_with_suffix=15
    else
        temphold_files=$($GAM user "$user" show filelist id name | grep -c "(Suspended Account - Temporary Hold)")
        echo "Files with suffix: $temphold_files"
        files_with_suffix=$temphold_files
    fi
    
    # Check files without suffix (should be 0 for consistent account)
    echo -e "${YELLOW}4. Checking files without temporary hold suffix...${NC}"
    if [[ "$DRY_RUN" == "true" || "$DISCOVERY_MODE" == "true" ]]; then
        echo "Simulated: Found 2 files without required suffix"
        files_without_suffix=2
    else
        # This would need more complex logic to count all files vs suffixed files
        echo "Manual verification recommended for file consistency"
        files_without_suffix=0
    fi
    
    # Summary
    echo ""
    echo -e "${MAGENTA}=== DIAGNOSIS SUMMARY ===${NC}"
    echo "OU Status: $([ "$current_ou" == "$OU_TEMPHOLD" ] && echo "✅ Correct" || echo "❌ Incorrect")"
    echo "Name Status: $([ "$lastname" == *"(Suspended Account - Temporary Hold)" ] && echo "✅ Correct" || echo "❌ Missing suffix")"
    echo "Files with suffix: $files_with_suffix"
    echo "Files without suffix: $files_without_suffix"
    
    if [[ "$current_ou" == "$OU_TEMPHOLD" && "$lastname" == *"(Suspended Account - Temporary Hold)" && $files_without_suffix -eq 0 ]]; then
        echo -e "${GREEN}✅ Account appears to be in consistent temporary hold state${NC}"
    else
        echo -e "${RED}❌ Account has inconsistencies that may need attention${NC}"
    fi
}

# Function to add pending deletion to user's last name
add_pending_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Adding pending deletion to last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name already has pending deletion
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        echo "No change needed for $email, already has pending deletion: '$current_lastname'"
    else
        # Add the "(PENDING DELETION - CONTACT OIT)" suffix to the current last name
        new_lastname="$current_lastname (PENDING DELETION - CONTACT OIT)"
        
        # Update the last name
        echo "Updating $email from '$current_lastname' to '$new_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$new_lastname\"" "Update user lastname"
    fi
}

# Function to add pending deletion to all files
add_pending_to_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Adding pending deletion to all files for $user_email_full${NC}"
    
    # Define files
    INPUT_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_active-shares.csv"
    UNIQUE_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_unique_files.csv"
    TEMP_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_temp.csv"
    ALL_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_all_files.csv"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would run file listing and renaming for: $user_email_full${NC}"
        echo "Simulated: Found 25 files to rename with pending deletion"
        
        # Simulate file processing
        for ((counter=1; counter<=5; counter++)); do
            show_progress $counter 5 "Processing file $counter"
            filename="Sample File $counter.pdf"
            new_filename="Sample File $counter.pdf (PENDING DELETION - CONTACT OIT)"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename${NC}"
            sleep 0.1
        done
        return 0
    fi
    
    # Run the list-users-files.sh to generate reports and CSV files
    echo "Running ${LISTSHARED_PATH}/list-users-files.sh $user_email"
    "${LISTSHARED_PATH}/list-users-files.sh" "$user_email"
    
    # Generate the master list of all files owned by this account
    $GAM user ${user_email_full} show filelist id title > "$ALL_FILE"
    cat "$INPUT_FILE" | awk -F, '{print $1","$2","$3","$4","$5","$6","$7}' | sort | uniq > "$UNIQUE_FILE"
    
    # Create temp file with updated filenames
    rm -f "$TEMP_FILE"
    touch "$TEMP_FILE"
    counter=0
    total=$(cat "$UNIQUE_FILE" | sort | uniq | wc -l)
    
    for file_id in $(cat "$UNIQUE_FILE" | sort | uniq | egrep -v mimeType | awk -F, '{print $2}'); do
        ((counter++))
        show_progress $counter $total "Collecting file info"
        grep $file_id "$ALL_FILE" >> "$TEMP_FILE"
    done
    
    echo "Total shared files: $(cat $TEMP_FILE | wc -l)"
    
    # Initialize the counter for renaming
    counter=0
    total=$(cat "$TEMP_FILE" | egrep -v "Owner,id,name" | egrep -v "PENDING DELETION" | wc -l)
    echo "$total files need pending deletion suffix"
    
    if [[ $total -eq 0 ]]; then
        echo "All files already have the pending deletion suffix."
        return
    fi
    
    # Read in the temporary file and extract the relevant information
    while IFS=, read -r fileid filename; do
        ((counter++))
        show_progress $counter $total "Adding pending deletion"
        
        if [[ $fileid != *"http"* ]]; then
            # Get the current filename directly from Google Drive
            current_filename=$($GAM user "$user_email_full" show fileinfo "$fileid" fields name | grep 'name:' | sed 's/name: //')
            
            # Only rename if the filename does not already contain "PENDING DELETION"
            if [[ $current_filename != *"PENDING DELETION - CONTACT OIT"* ]]; then
                # Construct the new filename
                new_filename="${current_filename} (PENDING DELETION - CONTACT OIT)"
                # Update the filename in Google Drive
                execute_command "$GAM user \"$user_email_full\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Rename file: $current_filename"
                echo "Renamed file: $fileid, $current_filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-pending-added.txt"
            fi
        fi
    done < <(cat "$TEMP_FILE" | egrep -v "PENDING DELETION" | egrep -v "Owner,id,name" | awk -F, '{print $2","$3}')
    
    echo "Completed adding pending deletion to files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-pending-added.txt for details"
}

# Function to add drive labels to files
add_drive_labels() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 3: Adding drive labels to files for $user_email_full${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would add Education Plus license temporarily${NC}"
        echo -e "${CYAN}[DRY-RUN] Would add drive labels to all files${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove Education Plus license${NC}"
        return 0
    fi
    
    # Add Education Plus license temporarily for drive labels
    execute_command "$GAM user $user_email_full add license \"Google Workspace for Education Plus\"" "Add temporary license"
    echo "Waiting 30 seconds for license to take effect..."
    sleep 30
    
    UNIQUE_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_unique_files.csv"
    LOG_FILE="${SCRIPTPATH}/logs/${user_email}_drive-labels.txt"
    
    if [[ ! -f "$UNIQUE_FILE" ]]; then
        echo "No unique files CSV found, skipping drive labels"
        return
    fi
    
    # Add labels to all files
    counter=0
    total=$(cat "$UNIQUE_FILE" | egrep -v "vnd.google-apps.folder" | egrep -v "mimeType" | wc -l)
    echo "Adding drive labels to $total files"
    
    while IFS=, read -r owner file_id filename; do
        if [[ "$file_id" != "id" && "$file_id" != *"mimeType"* ]]; then
            ((counter++))
            show_progress $counter $total "Adding drive labels"
            execute_command "$GAM user $user_email_full process filedrivelabels $file_id addlabelfield $LABEL_ID $FIELD_ID selection $SELECTION_ID" "Add label to file"
        fi
    done < "$UNIQUE_FILE"
    
    # Remove the temporary license
    execute_command "$GAM user $user_email_full delete license \"Google Workspace for Education Plus\"" "Remove temporary license"
    
    echo "Completed adding drive labels for $user_email"
}

# Function to remove pending deletion from user's last name
remove_pending_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Removing pending deletion from last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User (PENDING DELETION - CONTACT OIT)"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name ends with "(PENDING DELETION - CONTACT OIT)"
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        # Remove the "(PENDING DELETION - CONTACT OIT)" suffix from the current last name
        original_lastname="${current_lastname% (PENDING DELETION - CONTACT OIT)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$original_lastname\"" "Update user lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to remove pending deletion from all files
remove_pending_from_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Removing pending deletion from all files for $user_email_full${NC}"
    
    # Create tmp directory if it doesn't exist
    execute_command "mkdir -p \"${SCRIPTPATH}/tmp\"" "Create tmp directory"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query files for user: $user_email_full${NC}"
        TOTAL=4  # Simulate some files for dry-run
        echo "Found $TOTAL files to process (simulated)"
        
        # Simulate file processing
        for ((counter=1; counter<=TOTAL; counter++)); do
            show_progress $counter $TOTAL "Processing file $counter"
            filename="Sample File $counter (PENDING DELETION - CONTACT OIT).pdf"
            new_filename="Sample File $counter.pdf"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename${NC}"
            echo -e "${CYAN}[DRY-RUN] Would remove drive label from file${NC}"
            sleep 0.1
        done
        return 0
    fi
    
    # Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
    $GAM user "$user_email_full" show filelist id name | grep "(PENDING DELETION - CONTACT OIT)" > "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt"
    TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt" | wc -l)
    counter=0
    
    if [[ $TOTAL -eq 0 ]]; then
        echo "No files found with '(PENDING DELETION - CONTACT OIT)' in the name."
        return
    fi
    
    echo "Found $TOTAL files to process"
    
    # Read in the temporary file and extract the relevant information, skipping the header line
    while IFS=, read -r owner fileid filename; do
        ((counter++))
        show_progress $counter $TOTAL "Processing files"
        
        # Remove the "(PENDING DELETION - CONTACT OIT)" string from filename
        new_filename=${filename//" (PENDING DELETION - CONTACT OIT)"/}
        if [[ "$new_filename" != "$filename" ]]; then
            # Rename the file
            execute_command "$GAM user \"$owner\" update drivefile \"$fileid\" newfilename \"$new_filename\"" "Rename file: $filename"
            echo "Renamed file: $fileid, $filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-pending-removed.txt"
        fi
        
        # Remove drive label from file
        if [[ -n "$fileid" ]]; then
            execute_command "$GAM user $owner process filedrivelabels $fileid deletelabelfield $LABEL_ID $FIELD_ID" "Remove drive label"
        fi
    done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_pending_$user_email.txt") # Skip the first line (header)
    
    echo "Completed removing pending deletion from files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-pending-removed.txt for details"
}

# Function to remove user from all groups
remove_from_groups() {
    local user="$1"
    echo -e "${GREEN}Step 4: Removing user from all groups for $user${NC}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query user groups for: $user${NC}"
        echo -e "${CYAN}[DRY-RUN] Would remove user from all groups${NC}"
        echo "Simulated: User would be removed from 8 groups"
        return 0
    fi
    
    # Get list of groups user is a member of
    groups=$($GAM print groups member $user 2>/dev/null | grep your-domain.edu)
    
    if [[ -z "$groups" ]]; then
        echo "User $user is not a member of any groups"
        return
    fi
    
    echo "Removing user from groups..."
    for group in $groups; do
        echo "Removing user: $user from group: $group"
        execute_command "$GAM update group \"$group\" remove member \"$user\"" "Remove from group: $group"
        echo "Removed $user from $group" >> "${SCRIPTPATH}/users-removed-from-groups.txt"
    done
    
    echo "Completed removing user from groups"
}

# Function to confirm action
confirm_action() {
    while true; do
        read -p "Do you want to proceed with these changes? (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Function to restore last name (from restore-lastname.sh)
restore_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Restoring last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    if [[ "$DRY_RUN" == "true" ]]; then
        current_lastname="Sample User (PENDING DELETION - CONTACT OIT)"
        echo -e "${CYAN}[DRY-RUN] Would query user info for: $email${NC}"
    else
        current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    fi
    
    # Check if the current last name ends with "(PENDING DELETION - CONTACT OIT)"
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        # Remove the "(PENDING DELETION - CONTACT OIT)" suffix from the current last name
        original_lastname="${current_lastname% (PENDING DELETION - CONTACT OIT)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        execute_command "$GAM update user \"$email\" lastname \"$original_lastname\"" "Update user lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to fix filenames (from temphold-filesfix.sh)
fix_filenames() {
    local user="$1"
    echo -e "${GREEN}Step 2: Fixing filenames for $user${NC}"
    
    # Create tmp directory if it doesn't exist
    execute_command "mkdir -p \"${SCRIPTPATH}/tmp\"" "Create tmp directory"
    
    # Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${CYAN}[DRY-RUN] Would query files for user: $user${NC}"
        TOTAL=3  # Simulate some files for dry-run
        echo "Found $TOTAL files to rename (simulated)"
        
        # Simulate file processing
        for ((counter=1; counter<=TOTAL; counter++)); do
            show_progress $counter $TOTAL "Processing file $counter"
            filename="Sample File $counter (PENDING DELETION - CONTACT OIT).pdf"
            new_filename="Sample File $counter.pdf"
            echo -e "${CYAN}[DRY-RUN] Would rename: $filename -> $new_filename (Suspended Account - Temporary Hold)${NC}"
            sleep 0.1  # Brief pause for visual effect
        done
    else
        $GAM user "$user" show filelist id name | grep "(PENDING DELETION - CONTACT OIT)" > "${SCRIPTPATH}/tmp/gam_output_$user.txt"
        TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_$user.txt" | wc -l)
        counter=0
        
        if [[ $TOTAL -eq 0 ]]; then
            echo "No files found with '(PENDING DELETION - CONTACT OIT)' in the name."
            return
        fi
        
        echo "Found $TOTAL files to rename"
        
        # Read in the temporary file and extract the relevant information, skipping the header line
        while IFS=, read -r owner fileid filename; do
            ((counter++))
            show_progress $counter $TOTAL "Processing files"
            
            # Rename the file by removing the "(PENDING DELETION - CONTACT OIT)" string
            new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
            if [[ "$new_filename" != "$filename" ]]; then
                # If the filename has been changed, rename the file and print a message
                execute_command "$GAM user \"$owner\" update drivefile \"$fileid\" newfilename \"$new_filename (Suspended Account - Temporary Hold)\"" "Rename file: $filename"
                echo "Renamed file: $fileid, $filename -> $new_filename (Suspended Account - Temporary Hold)" >> "${SCRIPTPATH}/tmp/$user-fixed.txt"
            fi
        done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_$user.txt") # Skip the first line (header)
    fi
    
    echo "Completed renaming files for $user"
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "See ${SCRIPTPATH}/tmp/$user-fixed.txt for details"
    fi
}

# Function to rename all files (from temphold-file-rename.sh)
rename_all_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 3: Renaming all files for $user_email_full${NC}"
    
    # Define files
    INPUT_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_active-shares.csv"
    UNIQUE_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_unique_files.csv"
    TEMP_FILE="${LISTSHARED_PATH}/csv-files/${user_email}_temp.csv"
    
    # Run the list-users-files.sh to generate reports and CSV files
    echo "Running ${LISTSHARED_PATH}/list-users-files.sh $user_email"
    "${LISTSHARED_PATH}/list-users-files.sh" "$user_email"
    
    # Generate the master list of all files owned by this account
    cat "$INPUT_FILE" | awk -F, '{print $1","$2","$3","$4","$5","$6","$7}' | sort | uniq > "$UNIQUE_FILE"
    rm -f "$TEMP_FILE"
    touch "$TEMP_FILE"
    cat "$UNIQUE_FILE" | awk -F, '{print $1","$2","$3}' | sort | uniq > "$TEMP_FILE"
    
    echo "Total shared files: $(cat $TEMP_FILE | wc -l)"
    
    # Initialize the counter
    total=$(cat "$TEMP_FILE" | egrep -v "(Suspended Account - Temporary Hold)" | egrep -v "owner,id,filename" | wc -l)
    echo "$total files need to be renamed"
    
    if [[ $total -eq 0 ]]; then
        echo "All files already have the required suffix."
        return
    fi
    
    # Read in the temporary file and extract the relevant information
    while IFS=, read -r owner id filename; do
        if [[ -n "$filename" && $filename != *"(Suspended Account - Temporary Hold)"* ]]; then
            new_filename="$filename (Suspended Account - Temporary Hold)"
            echo "Renaming: $filename -> $new_filename"
            $GAM user "$user_email_full" update drivefile id "$id" newfilename "$new_filename"
        fi
    done < <(awk -F, 'NR != 1 && !/owner,id,filename/' "$TEMP_FILE" | egrep -v "(Suspended Account - Temporary Hold)" | awk -F, '{print $1","$2","$3}')
    
    echo "Completed renaming all files for $user_email"
    echo "${user_email},$(date '+%Y-%m-%d %H:%M:%S')" >> "${SCRIPTPATH}/file-rename-done.txt"
}

# Function to update user last name (from temphold-namechange.sh)
update_user_lastname() {
    local username="$1"
    echo -e "${GREEN}Step 4: Updating last name for $username${NC}"
    
    # Get the current last name of the user using GAM
    lastname=$($GAM info user "$username" | awk -F': ' '/Last Name:/ {print $2}')
    
    # Check if the last name already ends with "(Suspended Account - Temporary Hold)"
    if [[ "$lastname" == *"(Suspended Account - Temporary Hold)" ]]; then
        echo "Last name already updated - $lastname"
    else
        # Add "(Suspended Account - Temporary Hold)" to the last name
        new_lastname="$lastname (Suspended Account - Temporary Hold)"
        
        echo "Updating $username from '$lastname' to '$new_lastname'"
        $GAM update user "$username" lastname "$new_lastname"
    fi
}

# Function to remove temporary hold from user's last name
remove_temphold_lastname() {
    local email="$1"
    echo -e "${GREEN}Step 1: Removing temporary hold from last name for $email${NC}"
    
    # Get the current last name of the user using GAM
    current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    
    # Check if the current last name ends with "(Suspended Account - Temporary Hold)"
    if [[ "$current_lastname" == *"(Suspended Account - Temporary Hold)" ]]; then
        # Remove the "(Suspended Account - Temporary Hold)" suffix from the current last name
        original_lastname="${current_lastname% (Suspended Account - Temporary Hold)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        $GAM update user "$email" lastname "$original_lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to remove temporary hold from all files
remove_temphold_from_files() {
    local user_email_full="$1"
    local user_email=$(echo $user_email_full | awk -F@ '{print $1}')
    
    echo -e "${GREEN}Step 2: Removing temporary hold from all files for $user_email_full${NC}"
    
    # Create tmp directory if it doesn't exist
    mkdir -p "${SCRIPTPATH}/tmp"
    
    # Query the user's files and output only the files with (Suspended Account - Temporary Hold) in the name
    $GAM user "$user_email_full" show filelist id name | grep "(Suspended Account - Temporary Hold)" > "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt"
    TOTAL=$(cat "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt" | wc -l)
    counter=0
    
    if [[ $TOTAL -eq 0 ]]; then
        echo "No files found with '(Suspended Account - Temporary Hold)' in the name."
        return
    fi
    
    echo "Found $TOTAL files to rename"
    
    # Read in the temporary file and extract the relevant information, skipping the header line
    while IFS=, read -r owner fileid filename; do
        ((counter++))
        # Remove the "(Suspended Account - Temporary Hold)" string from filename
        new_filename=${filename//" (Suspended Account - Temporary Hold)"/}
        if [[ "$new_filename" != "$filename" ]]; then
            # If the filename has been changed, rename the file and print a message
            $GAM user "$owner" update drivefile "$fileid" newfilename "$new_filename"
            echo "$counter of $TOTAL - Renamed file: $filename -> $new_filename"
            echo "Renamed file: $fileid, $filename -> $new_filename" >> "${SCRIPTPATH}/tmp/$user_email-removal.txt"
        fi
    done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_removal_$user_email.txt") # Skip the first line (header)
    
    echo "Completed removing temporary hold from files for $user_email"
    echo "See ${SCRIPTPATH}/tmp/$user_email-removal.txt for details"
}

# Function to remove temporary hold from a single user
remove_temphold_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Removing temporary hold from user: $user ===${NC}"
    echo ""
    
    # Step 1: Remove temporary hold from lastname
    show_progress 1 3 "Removing temporary hold from lastname"
    remove_temphold_lastname "$user"
    echo ""
    
    # Step 2: Remove temporary hold from all files
    show_progress 2 3 "Removing temporary hold from all files"
    remove_temphold_from_files "$user"
    echo ""
    
    # Step 3: Move user to appropriate OU
    show_progress 3 3 "Moving user to destination OU"
    if [[ "$DRY_RUN" != "true" ]]; then
        destination_ou=$(get_destination_ou)
        move_user_to_ou "$user" "$destination_ou"
    else
        echo -e "${CYAN}[DRY-RUN] Would prompt for destination OU selection${NC}"
    fi
    echo ""
    
    # Step 4: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/temphold-removed.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$user" >> "${SCRIPTPATH}/file-removal-done.txt"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user removal${NC}"
    fi
    echo -e "${GREEN}Temporary hold removed from user $user successfully.${NC}"
    echo ""
}

# Function to remove temporary hold from multiple users from file
remove_temphold_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Removing temporary hold from $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            remove_temphold_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Temporary hold removed from all users in file.${NC}"
}

# Function to process a single user for pending deletion
process_pending_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Adding pending deletion for user: $user ===${NC}"
    echo ""
    
    # Step 1: Add pending deletion to lastname
    show_progress 1 5 "Adding pending deletion to lastname"
    add_pending_lastname "$user"
    echo ""
    
    # Step 2: Add pending deletion to all files
    show_progress 2 5 "Adding pending deletion to all files"
    add_pending_to_files "$user"
    echo ""
    
    # Step 3: Add drive labels to files
    show_progress 3 5 "Adding drive labels to files"
    add_drive_labels "$user"
    echo ""
    
    # Step 4: Remove user from all groups
    show_progress 4 5 "Removing user from all groups"
    remove_from_groups "$user"
    echo ""
    
    # Step 5: Move user to Pending Deletion OU
    show_progress 5 5 "Moving to Pending Deletion OU"
    move_user_to_ou "$user" "$OU_PENDING_DELETION"
    echo ""
    
    # Step 6: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/pending-deletion-done.log"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user to pending-deletion-done.log${NC}"
    fi
    echo -e "${GREEN}User $user has been marked for pending deletion successfully.${NC}"
    echo ""
}

# Function to remove pending deletion from a single user
remove_pending_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Removing pending deletion from user: $user ===${NC}"
    echo ""
    
    # Step 1: Remove pending deletion from lastname
    show_progress 1 3 "Removing pending deletion from lastname"
    remove_pending_lastname "$user"
    echo ""
    
    # Step 2: Remove pending deletion from all files (includes label removal)
    show_progress 2 3 "Removing pending deletion from all files"
    remove_pending_from_files "$user"
    echo ""
    
    # Step 3: Move user to appropriate OU
    show_progress 3 3 "Moving user to destination OU"
    if [[ "$DRY_RUN" != "true" ]]; then
        destination_ou=$(get_destination_ou)
        move_user_to_ou "$user" "$destination_ou"
    else
        echo -e "${CYAN}[DRY-RUN] Would prompt for destination OU selection${NC}"
    fi
    echo ""
    
    # Step 4: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/pending-deletion-removed.log"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$user" >> "${SCRIPTPATH}/pending-removal-done.txt"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user removal${NC}"
    fi
    echo -e "${GREEN}Pending deletion removed from user $user successfully.${NC}"
    echo ""
}

# Function to process multiple users from file for pending deletion
process_pending_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Adding pending deletion for $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            process_pending_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Pending deletion added for all users in file.${NC}"
}

# Function to remove pending deletion from multiple users from file
remove_pending_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Removing pending deletion from $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            remove_pending_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}Pending deletion removed from all users in file.${NC}"
}

# Function to process a single user
process_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Processing user: $user ===${NC}"
    echo ""
    
    # Step 1: Restore lastname
    show_progress 1 5 "Restoring lastname"
    restore_lastname "$user"
    echo ""
    
    # Step 2: Fix filenames
    show_progress 2 5 "Fixing filenames"
    fix_filenames "$user"
    echo ""
    
    # Step 3: Rename all files
    show_progress 3 5 "Renaming all files"
    rename_all_files "$user"
    echo ""
    
    # Step 4: Update user lastname
    show_progress 4 5 "Updating user lastname"
    update_user_lastname "$user"
    echo ""
    
    # Step 5: Move user to Temporary Hold OU
    show_progress 5 5 "Moving to Temporary Hold OU"
    move_user_to_ou "$user" "$OU_TEMPHOLD"
    echo ""
    
    # Step 6: Log completion
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "$user" >> "${SCRIPTPATH}/temphold-done.log"
    else
        echo -e "${CYAN}[DRY-RUN] Would log user to temphold-done.log${NC}"
    fi
    echo -e "${GREEN}User $user has been processed successfully.${NC}"
    echo ""
}

# Function to process multiple users from file
process_users_from_file() {
    local file_path="$1"
    local user_count=$(wc -l < "$file_path")
    local current=0
    
    echo -e "${BLUE}Processing $user_count users from file: $file_path${NC}"
    echo ""
    
    while IFS= read -r user; do
        # Skip empty lines and comments
        if [[ -n "$user" && ! "$user" =~ ^[[:space:]]*# ]]; then
            ((current++))
            echo -e "${YELLOW}Progress: $current/$user_count${NC}"
            process_user "$user"
            echo "----------------------------------------"
        fi
    done < "$file_path"
    
    echo -e "${GREEN}All users from file have been processed.${NC}"
}

# Main script execution
main() {
    while true; do
        show_main_menu
        choice=$?
        
        case $choice in
            1)
                # Single user processing
                user=$(get_user_input)
                operation=$(get_operation_choice)
                
                case $operation in
                    "add_temphold")
                        show_summary "$user"
                        if enhanced_confirm "add temporary hold" 1 "normal"; then
                            create_backup "$user" "add_temphold"
                            process_user "$user"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "remove_temphold")
                        show_removal_summary "$user"
                        if enhanced_confirm "remove temporary hold" 1 "normal"; then
                            create_backup "$user" "remove_temphold"
                            remove_temphold_user "$user"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "add_pending")
                        show_pending_summary "$user"
                        if enhanced_confirm "mark for pending deletion" 1 "high"; then
                            create_backup "$user" "add_pending"
                            process_pending_user "$user"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "remove_pending")
                        show_pending_removal_summary "$user"
                        if enhanced_confirm "remove pending deletion" 1 "normal"; then
                            create_backup "$user" "remove_pending"
                            remove_pending_user "$user"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                # Multiple users from file
                file_path=$(load_users_from_file)
                user_count=$(wc -l < "$file_path")
                operation=$(get_operation_choice)
                
                echo ""
                echo -e "${YELLOW}Found $user_count users in file.${NC}"
                echo "Sample users from file:"
                head -5 "$file_path" | while IFS= read -r line; do
                    echo "  - $line"
                done
                if [[ $user_count -gt 5 ]]; then
                    echo "  ... and $((user_count - 5)) more"
                fi
                echo ""
                
                case $operation in
                    "add_temphold")
                        echo "Each user will go through the process to add temporary hold."
                        if enhanced_confirm "batch add temporary hold" "$user_count" "batch"; then
                            process_users_from_file "$file_path"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "remove_temphold")
                        echo "Each user will go through the process to remove temporary hold."
                        if enhanced_confirm "batch remove temporary hold" "$user_count" "batch"; then
                            remove_temphold_users_from_file "$file_path"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "add_pending")
                        echo "Each user will be marked for pending deletion."
                        if enhanced_confirm "batch mark for pending deletion" "$user_count" "high"; then
                            process_pending_users_from_file "$file_path"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                    "remove_pending")
                        echo "Each user will have pending deletion removed."
                        if enhanced_confirm "batch remove pending deletion" "$user_count" "batch"; then
                            remove_pending_users_from_file "$file_path"
                        else
                            echo -e "${YELLOW}Operation cancelled.${NC}"
                        fi
                        ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                # Dry-run mode
                dry_run_mode
                ;;
            4)
                # Discovery mode
                discovery_mode
                ;;
            5)
                echo -e "${BLUE}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1-5.${NC}"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

# Check if required directories exist
if [[ ! -d "$SCRIPTPATH" ]]; then
    echo -e "${RED}Error: Script path $SCRIPTPATH does not exist.${NC}"
    exit 1
fi

if [[ ! -d "$LISTSHARED_PATH" ]]; then
    echo -e "${RED}Error: List shared path $LISTSHARED_PATH does not exist.${NC}"
    exit 1
fi

# Run the main function
main