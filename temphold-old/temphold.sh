#!/bin/bash
# Check if a username was provided as a command-line argument
if [ -z "$1" ]; then
  echo "Please provide a username as a command-line argument."
  exit 1
fi

GAM="/root/bin/gamadv-xtd3/gam"
SCRIPTPATH=/opt/your-path/mjb9/suspended

# Get the user input from command line
user=$1

echo "Removing Pending Deletion from username"
$SCRIPTPATH/restore-lastname.sh $user
echo "Removing Pending Deletion from filenames"
$SCRIPTPATH/temphold-filesfix.sh $user
echo "Making sure all shared files are labeled with new label"
$SCRIPTPATH/temphold-file-rename.sh $user
echo "Adding Temporary Hold to username"
$SCRIPTPATH/temphold-namechange.sh $user
echo $user >> temphold-done.log

