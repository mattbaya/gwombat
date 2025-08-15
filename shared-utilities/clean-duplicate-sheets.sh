#!/bin/bash
#
# clean-duplicate-sheets.sh
# Usage: clean-duplicate-sheets.sh PARENT_FOLDER_ID SHEET_NAME
#
# 1) Find all Drive sheets named SHEET_NAME under PARENT_FOLDER_ID
# 2) Report how many were found
# 3) If >1, retrieve each ID’s createdTime, sort, keep newest, delete the rest
# 4) Print the single remaining sheet ID (or nothing if none existed)
#

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 PARENT_FOLDER_ID SHEET_NAME" >&2
  exit 1
fi

PARENT_ID="$1"
SHEET_NAME="$2"
# Load configuration from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi
# GAM path should be set in .env via GAM_PATH
GAM="${GAM_PATH:-gam}"
GAM_USER="${ADMIN_USER:-gwombat@your-domain.edu}"
echo "#################Removing Duplicate Sheets####################"
#echo "Cleaning duplicate '$SHEET_NAME' sheets"

# 1) List only the IDs of matching sheets,
#    drop header (Owner,id) then cut out the id column
mapfile -t sheet_ids < <(
  $GAM user "$GAM_USER" print filelist \
    query "name='${SHEET_NAME}' and mimeType='application/vnd.google-apps.spreadsheet' and '${PARENT_ID}' in parents" \
    fields id \
    2>/dev/null \
  | tail -n +2 \
  | cut -d',' -f2
)

count=${#sheet_ids[@]}

# 2) Report count
if (( count == 0 )); then
  echo "Found 0 copies of sheet '$SHEET_NAME' in folder '$PARENT_ID'. Nothing to clean up."
  exit 0
elif (( count == 1 )); then
  echo "Found 1 copy of sheet '$SHEET_NAME' in folder '$PARENT_ID'. No duplicates to delete."
  printf '%s' "${sheet_ids[0]}"
  exit 0
else
  echo "Found $count copies of sheet '$SHEET_NAME' in folder '$PARENT_ID'."
fi

# 3) Retrieve each ID’s creation time
declare -a id_times
for id in "${sheet_ids[@]}"; do
  created=$(
    $GAM user "$GAM_USER" show fileinfo "$id" fields createdTime \
      | awk -F": " '/createdTime/{print $2}'
  )
  id_times+=( "$id,$created" )
done

# 4) Sort by timestamp (newest last) and determine which to keep
IFS=$'\n' sorted=($(printf '%s\n' "${id_times[@]}" | sort -t',' -k2))
newest_id="${sorted[-1]%%,*}"
echo "✔ Keeping newest: $newest_id"

# 5) Delete all but the newest
duplicates=$((count - 1))
echo "🗑️  Deleting $duplicates older copies..."
for entry in "${sorted[@]:0:duplicates}"; do
  old_id="${entry%%,*}"
  echo "  • Deleting $old_id"
  $GAM user "$GAM_USER" delete drivefile "$old_id"
done

echo "Done cleaning sheets"
$GAM user "$GAM_USER" empty drivetrash


# 6) Print the one remaining ID for callers
printf '%s' "$newest_id"
