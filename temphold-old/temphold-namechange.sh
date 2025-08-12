#!/bin/bash

# This script appends "(Suspended Account - Temporary Hold)" to the user's last name if it is not already appended.
# Usage: ./update_lastname.sh <username>

# Check if the username is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

# Assign the username argument to a variable
username="$1"

# Get the current last name of the user using GAM
lastname=$(/root/bin/gamadv-x/gam info user "$username" | awk -F': ' '/Last Name:/ {print $2}')

# Check if the last name already ends with "(Suspended Account - Temporary Hold)"
if [[ "$lastname" == *"(Suspended Account - Temporary Hold)" ]]; then
    echo "Last name is already changed - $lastname"
else
    # Add "(Suspended Account - Temporary Hold)" to the last name
    new_lastname="$lastname (Suspended Account - Temporary Hold)"
    
    # Echo the username and new last name
    echo "$username $lastname to $new_lastname"
    
    # Update the user's last name using GAM
    /root/bin/gamadv-x/gam update user "$username" lastname "$new_lastname"
fi
