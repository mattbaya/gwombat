#!/bin/bash
# This script removes the (PENDING DELETION) from a users filenames.
# Also removes the files from the pending deletion label as well.
# note - as of 7/31/24 the label removal part is not working, Matt will look into this later
# ./filesfix username:

# Check if a username was provided as a command-line argument
if [ -z "$1" ]; then
  echo "Please provide a username as a command-line argument."
  exit 1
fi

GAM="/root/bin/gamadv-xtd3/gam"

# Get the user input from command line
user=$1

# Define the original and main OUs
original_ou="/Suspended Accounts/Suspended - Temporary Hold"
temp_ou="/Temp"

# Move the user to the main OU
#echo "Moving $user to $main_ou"
#/root/bin/gamadv-x/gam update user "$user" org "$temp_ou"

# Check if the move was successful
#if [ $? -ne 0 ]; then
#    echo "Failed to move $user to $temp_ou"
#    exit 1
#fi

# Query the user's files and output only the files with (PENDING DELETION - CONTACT OIT) in the name
/root/bin/gamadv-x/gam user "$user" show filelist id name | grep "(PENDING DELETION - CONTACT OIT)" > /opt/your-path/mjb9/suspended/tmp/gam_output_$user.txt
TOTAL=$(cat /opt/your-path/mjb9/suspended/tmp/gam_output_$user.txt|wc -l)
counter=0

# Read in the temporary file and extract the relevant information, skipping the header line
while IFS=, read -r owner fileid filename; do
((counter++))
  # Rename the file by removing the "(PENDING DELETION - CONTACT OIT)" string
  new_filename=${filename//"(PENDING DELETION - CONTACT OIT)"/}
  if [[ "$new_filename" != "$filename" ]]; then
    # If the filename has been changed, rename the file and print a message
    /root/bin/gamadv-x/gam user "$owner" update drivefile "$fileid" newfilename "$new_filename (Suspended Account - Temporary Hold)"
    echo "$counter of $TOTAL - Renamed file: $filename -> $new_filename (Suspended Account - Temporary Hold)"
    echo "Renamed file: $fileid, $filename -> $new_filename (Suspended Account - Temporary Hold)" >>  /opt/your-path/mjb9/suspended/tmp/$user-fixed.txt
# remove the 'pending deletion' label too
#        $GAM user gamadmin process filedrivelabels $fileid deletelabelfield xIaFm0zxPw8zVL2nVZEI9L7u9eGOz15AZbJRNNEbbFcb 62BB395EC6 |grep "Deleted"
  fi
done < <(tail -n +2 /opt/your-path/mjb9/suspended/tmp/gam_output_$user.txt) # Skip the first line (header)

# Move the user back to the original OU
#echo "Moving $user back to $original_ou"
#/root/bin/gamadv-x/gam update user "$user" org "$original_ou"

# Check if the move back was successful
#if [ $? -ne 0 ]; then
#    echo "Failed to move $user back to $original_ou"
#    exit 1
#fi

echo "Completed renaming files for $user"
echo "-------------------------------------"
echo "Done. See /opt/your-path/mjb9/suspended/tmp/$user-fixed.txt"

