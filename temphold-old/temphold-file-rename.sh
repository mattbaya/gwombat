#!/bin/bash

# Adds (Suspended Account - Temporary Hold) to all files for this user.

# Set the path to the file containing the usernames
USER_EMAIL_FULL=$1
USER_EMAIL=$(echo $USER_EMAIL_FULL | awk -F@ '{print $1}')

GAM="/root/bin/gamadv-x/gam"

# Define files. We read the active-shares file and re-generate the unique one from that. Other scripts like label-shared reference the unique_files file too.
INPUT_FILE="/opt/your-path/mjb9/listshared/csv-files/${USER_EMAIL}_active-shares.csv"
UNIQUE_FILE="/opt/your-path/mjb9/listshared/csv-files/${USER_EMAIL}_unique_files.csv"
TEMP_FILE="/opt/your-path/mjb9/listshared/csv-files/${USER_EMAIL}_temp.csv"
ALL_FILE="/opt/your-path/mjb9/listshared/csv-files/${USER_EMAIL}_all_files.csv"
ALL_TEMP="/opt/your-path/mjb9/listshared/csv-files/${USER_EMAIL}_all_temp.csv"

# Check if active-shares file exists
#if [ ! -f "$INPUT_FILE" ] || [ ! -f "$UNIQUE_FILE" ]; then
#    echo "Either $INPUT_FILE or $UNIQUE_FILE (or both) is missing."
#  # Run the /opt/your-path/mjb9/listshared/list-users-files.sh to generate reports and CSV files.
echo "Running /opt/your-path/mjb9/listshared/list-users-files.sh $USER_EMAIL"
/opt/your-path/mjb9/listshared/list-users-files.sh $USER_EMAIL
#  else
#    echo "Yay! $INPUT_FILE and $UNIQUE_FILE already exist"
#fi

# Since it's pretty quick, let's regenerate the master list of all files owned by this account.
cat "$INPUT_FILE" | awk -F, '{print $1","$2","$3","$4","$5","$6","$7}' | sort | uniq > "$UNIQUE_FILE"
rm -f $TEMP_FILE
touch $TEMP_FILE
cat $UNIQUE_FILE | awk -F, '{print $1","$2","$3}' | sort | uniq > $TEMP_FILE
echo "$TEMP_FILE created"

echo "------------------------------------------"
echo "$USER_EMAIL | Total shared files: $(cat $TEMP_FILE | wc -l)"
echo "------------------------------------------"

# Initialize the counter
counter=0
total=$(cat $TEMP_FILE | egrep -v "(Suspended Account - Temporary Hold)"|egrep -v "owner,id,filename" | wc -l)
echo "$(cat $TEMP_FILE | wc -l) files to be renamed"
echo "$total not renamed yet"

echo "Renaming, where applicable"
echo "---------------------------------------"
# Read in the temporary file and extract the relevant information
while IFS=, read -r owner id filename; do
    if [[ -n "$filename" && $filename != *"(Suspended Account - Temporary Hold)"* ]]; then
        # Add your file renaming and label removing commands here
        echo "Current filename: $filename"
        new_filename="$filename (Suspended Account - Temporary Hold)"
        echo "Renaming to: $new_filename"
        # Example rename command
        /root/bin/gamadv-x/gam user "$USER_EMAIL_FULL" update drivefile id "$id" newfilename "$new_filename"
    else
        echo "Filename is either empty or already has the required suffix."
    fi
done < <(awk -F, 'NR != 1 && !/owner,id,filename/' $TEMP_FILE | egrep -v "(Suspended Account - Temporary Hold)" | awk -F, '{print $1","$2","$3}')

echo "done scanning files"
echo "${USER_EMAIL},$(date '+%Y-%m-%d %H:%M:%S')" >> file-rename-done.txt
echo "Resetting unique file"
cat "$INPUT_FILE" | egrep -v ".DS_Store" | awk -F, '{print $1","$2","$3","$4","$5","$6","$7}' | sort | uniq > "$UNIQUE_FILE"
echo "----------------------------------------------------------------------"
