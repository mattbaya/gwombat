#!/bin/bash

GAM="/root/bin/gamadv-x/gam"
ADMINUSER=gwombat@your-domain.edu
SCRIPTPATH="/opt/your-path/mjb9/misc/"
earliestDate="2023-05-01T00:00:00Z"
earliestTimestamp=$(date -d "$earliestDate" +%s)

# Check if a file ID is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <FILE_ID>"
    exit 1
fi

FILE_ID="$1"
OWNER="$("$GAM" show ownership "$FILE_ID" | awk -F": " '{print $2}' | awk -F, '{print $1}')"

# This script is written to help fix the dates on various files shared with
# Daniel Aalberts that had their last modification date changed when my other
# scripts renamed them with '(PENDING DELETION - CONTACT OIT)'
#
# This script will do several things
# 1) Change ownership of the file to Daniel Aalberts.
# 2) Rename the script to remove the 'Pending deletion' text
# 3) (if Daniel approves) Rename the file to include its former owners username at the beginning (ala "(mjb9) Filename here")
# 4) Query the files activity history and find the last modified date closest to but before May 2023.
ACTIVITY=$($GAM user $OWNER show driveactivity fileid $FILE_ID )

closestEventTime=""
closestTimestampDiff=$((earliestTimestamp + 1)) # Initialize with a value larger than any possible difference

# Skip the header row and process the rest using process substitution
while IFS= read -r line; do
    # Extracting the 6th field (eventTime)
    eventTime=$(echo "$line" | cut -d',' -f6)

#    echo "Debug: Processing line with eventTime = $eventTime"  # Additional debugging

    # Check if eventTime is in valid ISO 8601 format (YYYY-MM-DDTHH:MM:SSZ)
    if [[ $eventTime =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
        # Convert eventTime to Unix timestamp
        eventTimestamp=$(date -d "$eventTime" +%s)
#        echo "Debug: Converted timestamp for $eventTime is $eventTimestamp"  # Additional debugging

        # Find the date closest to but before the earliestDate
        if [[ "$eventTimestamp" -lt "$earliestTimestamp" ]]; then
            timestampDiff=$((earliestTimestamp - eventTimestamp))
#            echo "Debug: Difference is $timestampDiff for date $eventTime"  # Additional debugging
            if [[ -z "$closestEventTime" ]] || [[ "$timestampDiff" -lt "$closestTimestampDiff" ]]; then
                closestEventTime="$eventTime"
                closestTimestampDiff="$timestampDiff"
#                echo "Debug: New closest event time is $closestEventTime with difference $timestampDiff"  # Additional debugging
            fi
        fi
    fi
done < <(echo "$ACTIVITY" | tail -n +2)

# Output the result
if [ -n "$closestEventTime" ]; then
    echo "Date closest to $earliestDate : $closestEventTime"
else
    echo "No event found before $earlistDate"
    exit
fi

# 5) Set that date as the last modified date.
# NEWDATE should be formatted appropriately for GAM command
#$GAM user $ADMINUSER update drivefile id $FILE_ID modifieddate $NEWDATE
$GAM user $OWNER update drivefile id $FILE_ID modifieddate $closestEventTime

