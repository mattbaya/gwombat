#!/bin/bash
# User groupname username as variables when executing
# Example: for i in $(cat 2028jas.txt); do ./add-members-to-group.sh 2028jas $i;done

# Check if a group address was provided as a command-line argument
if [ -z "$1" ]; then
  echo "Please provide a groupname as a command-line argument."
  exit 1
fi
# Check if a username address was provided as a command-line argument
if [ -z "$2" ]; then
  echo "Please provide a username as a command-line argument."
  exit 1
fi
# Load configuration from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi
# GAM path should be set in .env via GAM_PATH
GAM="${GAM_PATH:-gam}"

# Get the user input from command line
group=$1
username=$2

$GAM update group $group add member allmail user $username


