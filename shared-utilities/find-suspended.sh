#!/bin/bash

GAM_PATH="/root/bin/gamadv-x/gam"  # Specify the path to the gam executable

# Create a file to store the users with no shared files
output_file="noshares.txt"
> "$output_file"  # Create an empty file or clear the existing one

# Query all suspended users
suspended_users=$("$GAM_PATH" print users query "isSuspended=true" | grep -E -v 'primaryEmail')

# Loop through suspended users and check file sharing
for user_email in $suspended_users; do
    # Check if the user has any files with 'True' in the last field
    if "$GAM_PATH" user "$user_email" print filelist fields id,name,shared | grep -E ",True$" > /dev/null; then
        echo "User $user_email is sharing files."
    else
        echo "User $user_email is not sharing files."
        echo "$user_email" >> "$output_file"
    fi
done

