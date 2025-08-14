#!/bin/bash

# Load admin user from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi
ADMIN_USER_VAR="${ADMIN_USER:-gwombat@your-domain.edu}"

# Prompt user for their email address
read -p "Enter user email: " USER_EMAIL

# Prompt user for number of days for recent files
read -p "Enter number of days for recent files: " NUM_DAYS

# Set date format
DATE_FORMAT="%Y-%m-%dT%H:%M:%S.%N%z"

# Set file names
ALL_FILES="${USER_EMAIL}_files.csv"
RECENT_FILES="${USER_EMAIL}_recent_files.csv"
OLD_FILES="${USER_EMAIL}_old_files.csv"
REPORTSFOLDER="1bWL5G_bqjr4n1C8rx_KxuG99AqsgyGcN"

# Run GAM command to get all non-trashed files for user
GAM_CMD="/root/bin/gamadv-xtd3/gam user \"${USER_EMAIL}\" show filelist query \"trashed=false\" fields \"size,id,name,mimeType,modifiedTime\""
FILES=$(eval "$GAM_CMD")
echo "$FILES" | tail -n +2 | grep -v ",application/vnd.google-apps." > "${ALL_FILES}"

# Get recent files
DATE=$(date -d "${NUM_DAYS} days ago" +$DATE_FORMAT)
echo "Getting recent files for ${USER_EMAIL} ..."
echo "$FILES" | tail -n +2 | grep -v ",application/vnd.google-apps." | awk -v d="${DATE}" -v f="${RECENT_FILES}" -F, 'BEGIN {OFS=","; print "Size, ID, Name, Type, Modified Time"} { if ($5 > d) {print $1, $2, $3, $4, $5, $6}}' > "${RECENT_FILES}"

# Get old files
echo "Getting old files for ${USER_EMAIL} ..."
echo "$FILES" | tail -n +2 | grep -v ",application/vnd.google-apps." | awk -v d="${DATE}" -v f="${OLD_FILES}" -F, 'BEGIN {OFS=","; print "Size, ID, Name, Type, Modified Time"} { if ($5 <= d) {print $1, $2, $3, $4, $5, $6}}' > "${OLD_FILES}"

# Get count and size of recent files
RECENT_COUNT=$(cat "${RECENT_FILES}" | wc -l)
RECENT_SIZE=$(cat "${RECENT_FILES}" | awk -F, 'BEGIN {OFS=","} {sum += $6} END {print sum}')
if command -v numfmt >/dev/null 2>&1; then
  RECENT_SIZE=$(echo "${RECENT_SIZE}" | numfmt --to=iec)
fi

# Get count and size of old files
OLD_COUNT=$(cat "${OLD_FILES}" | wc -l)
OLD_SIZE=$(cat "${OLD_FILES}" | awk -F, 'BEGIN {OFS=","} {sum += $6} END {print sum}')

if command -v numfmt >/dev/null 2>&1; then
  OLD_SIZE=$(echo "${OLD_SIZE}" | numfmt --to=iec)
fi

# Print results
echo "Recent files for ${USER_EMAIL}:       ${RECENT_COUNT} files, total size ${RECENT_SIZE}"
echo "Old files for ${USER_EMAIL}:       ${OLD_COUNT} files, total size ${OLD_SIZE}"

$GAM user "$ADMIN_USER_VAR" add drivefileacl $REPORTSFOLDER user "$USER_EMAIL" role writer >/dev/null 2>&1

# Create the Google Sheets file
sheet_id=$($GAM user $USER_EMAIL create drivefile drivefilename "$USER_EMAIL Shared Files" localfile $OUTPUT_FILE mimetype "application/vnd.google-apps.spreadsheet" parentid $REPORTSFOLDER returnidonly)

$GAM user "$ADMIN_USER_VAR" delete drivefileacl $REPORTSFOLDER "$USER_EMAIL" >/dev/null 2>&1

# Add srogers@your-domain.edu as editor
$GAM user $USER_EMAIL add drivefileacl $sheet_id user "srogers@your-domain.edu" role writer >/dev/null 2>&1

$GAM user "$ADMIN_USER_VAR" show fileinfo $sheet_id fields webViewLink

