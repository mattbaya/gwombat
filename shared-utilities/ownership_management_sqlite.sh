#!/bin/bash

# Usage: ./ownership_management_sqlite.sh <FOLDERID> <OWNER> <ADMIN_USER> <IS_FOLDER>

FOLDERID="$1"
OWNER="$2"
ADMIN_USER="$3"
IS_FOLDER="$4"

# Load configuration from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi

SCRIPTPATH="${SCRIPT_TEMP_PATH:-./tmp}/changeowner"
# GAM path should be set in .env via GAM_PATH
GAM="${GAM_PATH:-gam}"

# Database configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"

# Ensure database migration is applied
if [[ -f "../csv_to_sqlite_migration.sql" ]]; then
    sqlite3 "$DB_PATH" < ../csv_to_sqlite_migration.sql 2>/dev/null || true
fi

# Ensure required directories exist
mkdir -p "$SCRIPTPATH/temp"

# Helper function to execute database queries
execute_db() {
    sqlite3 "$DB_PATH" "$1"
}

# Start operation tracking
OPERATION_ID=$(execute_db "
INSERT INTO file_operations (operation_type, session_id, target_id, source_user, target_user, operation_status)
VALUES ('ownership_change', '$SESSION_ID', '$FOLDERID', '$OWNER', '$ADMIN_USER', 'in_progress');
SELECT last_insert_rowid();
")

echo "Setting $ADMIN_USER as owner of $FOLDERID (Operation ID: $OPERATION_ID)"
"$GAM" user "$OWNER" add drivefileacl "$FOLDERID" user "$ADMIN_USER" role owner > "$SCRIPTPATH/temp/${FOLDERID}_change-$OWNER-to-gwombat.txt"

echo "Claiming ownership of $FOLDERID for $ADMIN_USER (this might take a while)"
OWNERSHIP_OUTPUT=$("$GAM" user "$ADMIN_USER" claim ownership $FOLDERID)

# Count claimed files and update operation
CLAIMED_COUNT=$(echo "$OWNERSHIP_OUTPUT" | wc -l)
echo "Claimed $CLAIMED_COUNT files. Checking for any externally owned files"

# Update operation with claimed files count
execute_db "
UPDATE file_operations 
SET files_processed = $CLAIMED_COUNT,
    details = json_object('claimed_files', $CLAIMED_COUNT, 'folder_id', '$FOLDERID')
WHERE id = $OPERATION_ID;
"

# Get file list and analyze ownership
temp_file="$SCRIPTPATH/temp/$FOLDERID-temp.txt"
"$GAM" user "$ADMIN_USER" print filelist select id "$FOLDERID" showownedby any fields id,owners.emailaddress > "$temp_file"

total_files=$(wc -l < "$temp_file")
total_files=$((total_files - 1)) # Adjust for header row
echo "Total files to process: $total_files"
processed_files=0
echo "------------------"

# Extract unique file owners
FILEOWNERS="$(cat $temp_file | awk -F, '{print $1}' | egrep -v "owners.0.emailAddress" | sort | uniq)"
echo "FILE OWNERS: $FILEOWNERS"
echo "------------------"

# Process owners and handle suspended accounts
echo "$FILEOWNERS" | while IFS=, read owner_email; do
    if [[ "$owner_email" == *"@${DOMAIN:-your-domain.edu}"* ]]; then
        # Check if user is suspended
        SUSPENSION_STATUS=$("$GAM" info user "$owner_email" suspended | grep "Account Suspended" | awk -F": " '{print $2}')
        
        if [[ "$SUSPENSION_STATUS" == "True" ]]; then
            echo "$owner_email is suspended, temporarily unsuspending"
            
            # Track temporary state change in database
            execute_db "
            INSERT INTO temp_user_states (operation_id, user_email, original_state, temporary_state, session_id)
            VALUES ($OPERATION_ID, '$owner_email', 'suspended', 'active', '$SESSION_ID');
            "
            
            "$GAM" update user "$owner_email" suspended off
        else
            echo "$owner_email is not suspended, proceeding"
        fi
    fi
done

# Handle folder creation for external files
FOLDER_NAME="Copied Files from External Accounts"
if [[ $IS_FOLDER == "true" ]]; then
    echo "Checking if '$FOLDER_NAME' already exists in the folder with ID '$FOLDERID'"
    EXISTING_FOLDER_INFO=$("$GAM" user "$ADMIN_USER" show filelist query "'$FOLDERID' in parents and name='$FOLDER_NAME' and mimeType='application/vnd.google-apps.folder' and trashed=false")

    if [[ "$EXISTING_FOLDER_INFO" == *"webViewLink"* ]] && [[ ! "$EXISTING_FOLDER_INFO" == *"https://drive.google.com/drive/folders/"* ]]; then
        echo "No existing folder named '$FOLDER_NAME'. Proceeding to create it."
        CREATECOPYFOLDER=$("$GAM" user "$ADMIN_USER" add drivefile drivefilename "$FOLDER_NAME" mimetype gfolder parentid $FOLDERID)
        echo "$CREATECOPYFOLDER"
        COPYFOLDER=$(echo "$CREATECOPYFOLDER" | awk -F"(" '{print $2}' | awk -F")" '{print $1}')
        echo "New folder ID is $COPYFOLDER"
    else
        WEBVIEWLINK=$(echo "$EXISTING_FOLDER_INFO" | grep "https://drive.google.com/drive/folders/" | head -n 1 | awk '{print $NF}')
        COPYFOLDER=$(echo "$WEBVIEWLINK" | sed 's|.*/||')
        echo "Folder '$FOLDER_NAME' already exists with ID $COPYFOLDER"
    fi
else
    echo "This is a file, not a folder. Just going to move it without a folder"
fi

echo "------------------"

# Process each file
files_changed=0
files_copied=0
files_failed=0

tail -n +2 "$temp_file" | while IFS=, read -r owner file_id count owner_email; do
    processed_files=$((processed_files + 1))
    echo "Processing file #$processed_files of $total_files: ID $file_id owned by $owner"

    if [[ "$owner_email" == *"@${DOMAIN:-your-domain.edu}"* ]]; then
        if [ "$owner" != "$ADMIN_USER" ]; then
            echo "Changing owner of file ID $file_id to $ADMIN_USER"
            if "$GAM" user "$owner" add drivefileacl "$file_id" user "$ADMIN_USER" role owner | grep "$file_id"; then
                files_changed=$((files_changed + 1))
                
                # Log successful ownership change
                execute_db "
                INSERT INTO file_operations (operation_type, session_id, target_id, source_user, target_user, file_id, operation_status, details)
                VALUES ('ownership_change', '$SESSION_ID', '$file_id', '$owner', '$ADMIN_USER', '$file_id', 'completed', 
                        json_object('file_id', '$file_id', 'original_owner', '$owner', 'new_owner', '$ADMIN_USER'));
                "
            else
                files_failed=$((files_failed + 1))
            fi
        else
            echo "File ID $file_id is already owned by $ADMIN_USER. Skipping."
        fi
    else
        echo "File #$processed_files of $total_files is not owned by a ${DOMAIN:-your-domain.edu} account. Making a copy."
        copied_file_id=$("$GAM" user "$ADMIN_USER" copy drivefile "$file_id" parentid "$COPYFOLDER" | awk '/New File ID: / {print $NF}')
        
        if [[ -n "$copied_file_id" ]]; then
            files_copied=$((files_copied + 1))
            echo "Made a copy of file #$processed_files of $total_files: ID $file_id in folder ID $COPYFOLDER. New file ID is $copied_file_id"
            
            # Log file copy operation
            execute_db "
            INSERT INTO file_operations (operation_type, session_id, target_id, source_user, target_user, file_id, operation_status, details)
            VALUES ('backup', '$SESSION_ID', '$file_id', '$owner', '$ADMIN_USER', '$copied_file_id', 'completed',
                    json_object('original_file_id', '$file_id', 'copied_file_id', '$copied_file_id', 'copy_location', '$COPYFOLDER'));
            "
        else
            files_failed=$((files_failed + 1))
        fi
    fi
done

echo "Processed $processed_files files out of $total_files total."
echo "Files with ownership changed: $files_changed"
echo "Files copied: $files_copied"
echo "Files failed: $files_failed"

# Update final operation status
execute_db "
UPDATE file_operations 
SET operation_status = 'completed',
    completed_at = CURRENT_TIMESTAMP,
    details = json_set(
        COALESCE(details, '{}'),
        '$.total_processed', $processed_files,
        '$.ownership_changed', $files_changed,
        '$.files_copied', $files_copied,
        '$.files_failed', $files_failed
    )
WHERE id = $OPERATION_ID;
"

# Display summary of temporary user state changes that need restoration
echo ""
echo "=== RESTORATION SUMMARY ==="
PENDING_RESTORATIONS=$(execute_db "
SELECT COUNT(*) FROM temp_user_states 
WHERE operation_id = $OPERATION_ID AND restore_needed = 1;
")

if [[ "$PENDING_RESTORATIONS" -gt 0 ]]; then
    echo "Users temporarily unsuspended that need restoration:"
    execute_db "
    SELECT user_email, changed_at FROM temp_user_states 
    WHERE operation_id = $OPERATION_ID AND restore_needed = 1
    ORDER BY changed_at;
    " | while IFS='|' read -r email timestamp; do
        echo "  - $email (unsuspended at $timestamp)"
    done
    
    echo ""
    echo "To restore these users to suspended state, run:"
    echo "sqlite3 $DB_PATH \"SELECT 'gam update user ' || user_email || ' suspended on' FROM temp_user_states WHERE operation_id = $OPERATION_ID AND restore_needed = 1;\""
    echo ""
    echo "Then mark them as restored:"
    echo "sqlite3 $DB_PATH \"UPDATE temp_user_states SET restore_needed = 0, restored_at = CURRENT_TIMESTAMP WHERE operation_id = $OPERATION_ID;\""
else
    echo "No users require restoration."
fi

echo ""
echo "Operation completed. Session ID: $SESSION_ID"
echo "Operation ID: $OPERATION_ID"