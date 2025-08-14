#!/bin/bash

# Usage: ./ownership_management.sh <FOLDERID> <OWNER> <ADMIN_USER> <IS_FOLDER>

FOLDERID="$1"
OWNER="$2"
ADMIN_USER="$3"
IS_FOLDER="$4"
SCRIPTPATH="/opt/your-path/mjb9/changeowner"
GAM="/root/bin/gamadv-x/gam"
TEMP="$SCRIPTPATH/temp/$FOLDERID-unsuspended-temp.csv"
temp_file="$SCRIPTPATH/temp/$FOLDERID-temp.txt"

echo "Setting $ADMIN_USER as owner of $FOLDERID"
"$GAM" user "$OWNER" add drivefileacl "$FOLDERID" user "$ADMIN_USER" role owner > "$SCRIPTPATH/temp/${FOLDERID}_change-$OWNER-to-gwombat.txt"

echo "Claiming ownership of $FOLDERID for $ADMIN_USER (this might take a while)"
"$GAM" user "$ADMIN_USER" claim ownership $FOLDERID >> $SCRIPTPATH/temp/$FOLDERID-ownership-change-tree.csv
echo "Claimed $(cat $SCRIPTPATH/temp/$FOLDERID-ownership-change-tree.csv|wc -l) files. Checking for any externally owned files"

"$GAM" user "$ADMIN_USER" print filelist select id "$FOLDERID" showownedby any fields id,owners.emailaddress > "$temp_file"

total_files=$(wc -l < "$temp_file")
total_files=$((total_files - 1)) # Adjust for header row
echo "Total files to process: $total_files"
processed_files=0
echo "------------------"

FILEOWNERS="$(cat $temp_file |awk -F, '{print $1}'|egrep -v "owners.0.emailAddress"|sort|uniq)"
echo "FILE OWNERS: $FILEOWNERS"
echo "------------------"
echo "$FILEOWNERS"|while IFS=, read owner_email; do
if [[ "$owner_email" == *"@your-domain.edu"* ]]; then
        if [[ $($GAM info user "$owner_email" suspended | grep "Account Suspended" | awk -F": " '{print $2}') == "True" ]]; then
            echo "$owner_email is suspended, temporarily unsuspending"
            echo "$owner_email" >> "$TEMP"
            "$GAM" update user "$owner_email" suspended off
        else
            echo "$owner_email is not suspended, proceeding"
        fi
fi
done

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
tail -n +2 "$temp_file" |
while IFS=, read -r owner file_id count owner_email; do
    processed_files=$((processed_files + 1))
    echo "Processing file #$processed_files of $total_files: ID $file_id owned by $owner"

    if [[ "$owner_email" == *"@your-domain.edu"* ]]; then
        if [ "$owner" != "$ADMIN_USER" ]; then
            echo "Changing owner of file ID $file_id to $ADMIN_USER"
            "$GAM" user "$owner" add drivefileacl "$file_id" user "$ADMIN_USER" role owner | grep "$file_id"
        else
            echo "File ID $file_id is already owned by $ADMIN_USER. Skipping."
        fi
    else
        echo "File #$processed_files of $total_files is not owned by a your-domain.edu account. Making a copy."
        copied_file_id=$("$GAM" user "$ADMIN_USER" copy drivefile "$file_id" parentid "$COPYFOLDER" | awk '/New File ID: / {print $NF}')
        echo "Made a copy of file #$processed_files of $total_files: ID $file_id in folder ID $COPYFOLDER. New file ID is $copied_file_id"
    fi
done

echo "Processed $processed_files files out of $total_files total."

