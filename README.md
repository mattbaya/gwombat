# Temporary Hold Master Script

A comprehensive script that consolidates all temporary hold operations for suspended user accounts into a single interactive tool with preview functionality.

## Overview

This script automates the process of moving user accounts from "pending deletion" status to "temporary hold" status. It performs four main operations:

1. **Restore Last Name** - Removes "(PENDING DELETION - CONTACT OIT)" from user's last name
2. **Fix Filenames** - Renames files with pending deletion markers
3. **Rename All Files** - Adds "(Suspended Account - Temporary Hold)" to all user files
4. **Update User Last Name** - Adds suspension marker to user's last name

## Features

- **Interactive Menu System** - Choose between single user or batch processing
- **Preview Mode** - Shows detailed summary of all actions before execution
- **User Confirmation** - Requires approval before making any changes
- **Progress Tracking** - Shows progress when processing multiple users
- **Error Handling** - Validates inputs and checks for required directories
- **Comprehensive Logging** - Records all operations and changes
- **Color-coded Output** - Easy-to-read status messages

## Prerequisites

- GAM (Google Apps Manager) installed at `/usr/local/bin/gam`
- Access to the following directories:
  - `/opt/your-path/mjb9/suspended` (script path)
  - `/opt/your-path/mjb9/listshared` (shared files path)
- Required script dependencies:
  - `list-users-files.sh` in the listshared directory

## Installation

1. Ensure the script is executable:
   ```bash
   chmod +x master-temphold.sh
   ```

2. Verify GAM is installed and accessible:
   ```bash
   /usr/local/bin/gam version
   ```

3. Check that required directories exist and are accessible

## Usage

### Interactive Mode

Run the script without arguments to enter interactive mode:

```bash
./master-temphold.sh
```

### Menu Options

1. **Process user by username/email**
   - Enter a single username or email address
   - View summary of actions
   - Confirm before execution

2. **Load users from file**
   - Specify path to file containing usernames (one per line)
   - Preview sample users from file
   - Batch process all users

3. **Exit**
   - Safely exit the script

### File Format for Batch Processing

Create a text file with one username/email per line:

```
user1@domain.com
user2@domain.com
user3@domain.com
```

- Empty lines and lines starting with `#` are ignored
- Each user will go through the complete 4-step process

## Process Details

### Step 1: Restore Last Name
- Checks if user's last name contains "(PENDING DELETION - CONTACT OIT)"
- If found, removes the suffix and restores original last name
- If not found, skips this step

### Step 2: Fix Filenames
- Searches for files with "(PENDING DELETION - CONTACT OIT)" in filename
- Renames them to include "(Suspended Account - Temporary Hold)"
- Logs all changes to `tmp/{username}-fixed.txt`

### Step 3: Rename All Files
- Generates comprehensive file list using `list-users-files.sh`
- Adds "(Suspended Account - Temporary Hold)" suffix to all file names
- Skips files that already have the suffix

### Step 4: Update User Last Name
- Adds "(Suspended Account - Temporary Hold)" to user's last name
- Skips if suffix already present

## Output and Logging

### Log Files Created:
- `temphold-done.log` - Users successfully processed
- `file-rename-done.txt` - Timestamp log of file rename operations
- `tmp/{username}-fixed.txt` - Detailed log of specific file changes

### Temporary Files:
- `tmp/gam_output_{username}.txt` - GAM query results
- CSV files in `${LISTSHARED_PATH}/csv-files/` directory

## Error Handling

The script includes comprehensive error checking:

- Validates user input
- Checks file existence for batch processing
- Verifies required directories exist
- Handles GAM command failures gracefully
- Provides clear error messages

## Color Coding

- 🔵 **Blue**: Headers and informational messages
- 🟢 **Green**: Success messages and step indicators
- 🟡 **Yellow**: Warnings and progress indicators
- 🔴 **Red**: Error messages

## Safety Features

- **Preview Mode**: Shows exactly what will happen before execution
- **User Confirmation**: Requires explicit approval before making changes
- **Non-destructive**: Only adds suffixes, doesn't delete data
- **Logging**: Complete audit trail of all operations
- **Validation**: Checks for existing suffixes to prevent duplicates

## Troubleshooting

### Common Issues:

1. **GAM not found**
   - Verify GAM is installed at `/usr/local/bin/gam`
   - Check PATH environment variable

2. **Permission denied**
   - Ensure script has execute permissions
   - Check directory access permissions

3. **Required directories missing**
   - Verify `/opt/your-path/mjb9/suspended` exists
   - Verify `/opt/your-path/mjb9/listshared` exists

4. **list-users-files.sh not found**
   - Ensure the script exists in the listshared directory
   - Check execute permissions on the script

### Debug Mode:

To enable verbose output, you can modify the script to add `set -x` at the top for debugging.

## Author

Consolidated from multiple individual scripts:
- `temphold.sh`
- `restore-lastname.sh`
- `temphold-filesfix.sh`
- `temphold-file-rename.sh`
- `temphold-namechange.sh`

## Version History

- v1.0 - Initial consolidated version with interactive menu and preview functionality