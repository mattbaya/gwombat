#!/bin/bash
#
# clean-duplicate-folders.sh
# Usage: clean-duplicate-folders.sh PARENT_FOLDER_ID FOLDER_NAME
#   Finds all Drive folders named exactly FOLDER_NAME under that parent,
#   keeps only the newest, deletes the rest, and prints exactly one ID to stdout.
#

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 PARENT_FOLDER_ID FOLDER_NAME" >&2
  exit 1
fi

PARENT_ID="$1"
FOLDER_NAME="$2"
GAM_USER="gamadmin@your-domain.edu"
GAM="/usr/local/bin/gam"
echo "Cleaning up duplicate $FOLDER_NAME folders"

# 1) List only the IDs of matching folders, drop header, extract the ID column
mapfile -t ids < <(
  {
    $GAM user "$GAM_USER" print filelist \
      query "mimeType='application/vnd.google-apps.folder' and name='${FOLDER_NAME}' and '${PARENT_ID}' in parents" \
      fields id \
      2>/dev/null
  } | tail -n +2 | cut -d',' -f2
)

count=${#ids[@]}

# 2) Log how many were found to stderr
echo "Found $count folders named '$FOLDER_NAME' under '$PARENT_ID'." >&2

# 3) If none, exit quietly
if (( count == 0 )); then
  exit 0
fi

# 4) If exactly one, print it and exit
if (( count == 1 )); then
  printf '%s' "${ids[0]}"
  exit 0
fi

# 5) More than one → fetch each folder's createdTime
declare -a id_times
for id in "${ids[@]}"; do
  created=$(
    $GAM user "$GAM_USER" show fileinfo "$id" fields createdTime \
      | awk -F": " '/createdTime/{print $2}'
  )
  id_times+=( "$id,$created" )
done

# 6) Sort by timestamp (newest last) and pick the newest ID
IFS=$'\n' sorted=($(printf '%s\n' "${id_times[@]}" | sort -t',' -k2))
newest="${sorted[-1]%%,*}"
echo "Keeping newest folder: $newest" >&2

# 7) Delete all but the newest
for entry in "${sorted[@]:0:$((${#sorted[@]}-1))}"; do
  old="${entry%%,*}"
  echo "Deleting old folder $old" >&2
  $GAM user "$GAM_USER" delete drivefile "$old"
done
$GAM user "$GAM_USER" empty drivetrash

echo "Done cleaning folders"

# 8) Output the one remaining ID on stdout
printf '%s' "$newest"
