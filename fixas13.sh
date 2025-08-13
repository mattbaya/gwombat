#!/bin/bash

# Set the path to the GAM executable
GAM="/root/bin/gamadv-x/gam"

# Set the user's email address as a variable
USER_EMAIL="as13@your-domain.edu"

# List of file IDs and their correct filenames
declare -A files=(
    ["0B2nFGv2xnmtuLUl4d0N4UnN2VkU"]="IMG_3507.jpg"
    ["0B2nFGv2xnmtuLXJRVnB1anVyMm8"]="IMG_3432.jpg"
    ["0B2nFGv2xnmtuM2pTTnFqVEtpN2s"]="IMG_3470.m4v"
    ["0B2nFGv2xnmtuM3I5VWRrTGV4MTQ"]="IMG_3424.m4v"
    ["0B2nFGv2xnmtuMURUUU9ibEV5aTg"]="IMG_3620.jpg"
    ["0B2nFGv2xnmtuMWVBNUwyVWdUemc"]="IMG_3571.jpg"
    ["0B2nFGv2xnmtuN0F5SEt0Ti1hRTQ"]="IMG_3617.jpg"
    ["0B2nFGv2xnmtuN3BqcUhuZWdFRE0"]="IMG_3500.jpg"
    ["0B2nFGv2xnmtuNDhWbVdQa0tGUFk"]="IMG_3546.jpg"
    ["0B2nFGv2xnmtuNFNNeHB2YVZkc3M"]="IMG_3434.jpg"
)

# Loop through the files and rename them
for fileid in "${!files[@]}"; do
    original_filename="${files[$fileid]}"
    new_filename="${original_filename} (PENDING DELETION - CONTACT OIT)"
    $GAM user "$USER_EMAIL" update drivefile "$fileid" newfilename "$new_filename"
    echo "Updated $fileid: $original_filename -> $new_filename"
done

