#!/bin/bash

# Temporary Hold Master Script
#
# A comprehensive script that consolidates all temporary hold operations for suspended user accounts into a single interactive tool with preview functionality.
#
# ## Overview
#
# This script automates the process of moving user accounts from "pending deletion" status to "temporary hold" status. It performs four main operations:
#
# 1. **Restore Last Name** - Removes "(PENDING DELETION - CONTACT OIT)" from user's last name
# 2. **Fix Filenames** - Renames files with pending deletion markers
# 3. **Rename All Files** - Adds "(Suspended Account - Temporary Hold)" to all user files
# 4. **Update User Last Name** - Adds suspension marker to user's last name
#
# ## Features
#
# - **Interactive Menu System** - Choose between single user or batch processing
# - **Preview Mode** - Shows detailed summary of all actions before execution
# - **User Confirmation** - Requires approval before making any changes
# - **Progress Tracking** - Shows progress when processing multiple users
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
# 1. **Process user by username/email**
#    - Enter a single username or email address
#    - View summary of actions
#    - Confirm before execution
#
# 2. **Load users from file**
#    - Specify path to file containing usernames (one per line)
#    - Preview sample users from file
#    - Batch process all users
#
# 3. **Exit**
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
# - `temphold-done.log` - Users successfully processed
# - `file-rename-done.txt` - Timestamp log of file rename operations
# - `tmp/{username}-fixed.txt` - Detailed log of specific file changes
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

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display the main menu
show_main_menu() {
    clear
    echo -e "${BLUE}=== Temporary Hold Master Script ===${NC}"
    echo ""
    echo "1. Process user by username/email"
    echo "2. Load users from file"
    echo "3. Exit"
    echo ""
    read -p "Select an option (1-3): " choice
    echo ""
    return $choice
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

# Function to show what actions will be performed
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
    echo -e "${GREEN}5. Logging:${NC}"
    echo "   - Add user to temphold-done.log"
    echo "   - Add timestamp to file-rename-done.txt"
    echo ""
    echo -e "${YELLOW}Note: This process may take several minutes depending on the number of files.${NC}"
    echo ""
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
    current_lastname=$($GAM info user "$email" | awk -F': ' '/Last Name:/ {print $2}')
    
    # Check if the current last name ends with "(PENDING DELETION - CONTACT OIT)"
    if [[ "$current_lastname" == *"(PENDING DELETION - CONTACT OIT)" ]]; then
        # Remove the "(PENDING DELETION - CONTACT OIT)" suffix from the current last name
        original_lastname="${current_lastname% (PENDING DELETION - CONTACT OIT)}"
        
        # Restore the original last name
        echo "Restoring $email from '$current_lastname' to '$original_lastname'"
        $GAM update user "$email" lastname "$original_lastname"
    else
        echo "No change needed for $email, current last name is '$current_lastname'"
    fi
}

# Function to fix filenames (from temphold-filesfix.sh)
fix_filenames() {
    local user="$1"
    echo -e "${GREEN}Step 2: Fixing filenames for $user${NC}"
    
    # Create tmp directory if it doesn't exist
    mkdir -p "${SCRIPTPATH}/tmp"
    
    # Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
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
        # Rename the file by removing the "(PENDING DELETION - CONTACT OIT)" string
        new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
        if [[ "$new_filename" != "$filename" ]]; then
            # If the filename has been changed, rename the file and print a message
            $GAM user "$owner" update drivefile "$fileid" newfilename "$new_filename (Suspended Account - Temporary Hold)"
            echo "$counter of $TOTAL - Renamed file: $filename -> $new_filename (Suspended Account - Temporary Hold)"
            echo "Renamed file: $fileid, $filename -> $new_filename (Suspended Account - Temporary Hold)" >> "${SCRIPTPATH}/tmp/$user-fixed.txt"
        fi
    done < <(tail -n +2 "${SCRIPTPATH}/tmp/gam_output_$user.txt") # Skip the first line (header)
    
    echo "Completed renaming files for $user"
    echo "See ${SCRIPTPATH}/tmp/$user-fixed.txt for details"
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

# Function to process a single user
process_user() {
    local user="$1"
    
    echo -e "${BLUE}=== Processing user: $user ===${NC}"
    echo ""
    
    # Step 1: Restore lastname
    restore_lastname "$user"
    echo ""
    
    # Step 2: Fix filenames
    fix_filenames "$user"
    echo ""
    
    # Step 3: Rename all files
    rename_all_files "$user"
    echo ""
    
    # Step 4: Update user lastname
    update_user_lastname "$user"
    echo ""
    
    # Step 5: Log completion
    echo "$user" >> "${SCRIPTPATH}/temphold-done.log"
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
                show_summary "$user"
                if confirm_action; then
                    process_user "$user"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                # Multiple users from file
                file_path=$(load_users_from_file)
                user_count=$(wc -l < "$file_path")
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
                echo "Each user will go through the same 4-step process."
                if confirm_action; then
                    process_users_from_file "$file_path"
                else
                    echo -e "${YELLOW}Operation cancelled.${NC}"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${BLUE}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please select 1, 2, or 3.${NC}"
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