#!/bin/bash

# Load admin user from .env
if [[ -f "../.env" ]]; then
    source ../.env
fi
ADMIN_USER_VAR="${ADMIN_USER:-gwombat@your-domain.edu}"

# Database configuration
DB_PATH="${DB_PATH:-./config/gwombat.db}"
SESSION_ID="${SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"

# Ensure database migration is applied
if [[ -f "../csv_to_sqlite_migration.sql" ]]; then
    sqlite3 "$DB_PATH" < ../csv_to_sqlite_migration.sql 2>/dev/null || true
fi

# Helper function to execute database queries
execute_db() {
    sqlite3 "$DB_PATH" "$1"
}

# Prompt user for their email address
read -p "Enter user email: " USER_EMAIL

# Prompt user for number of days for recent files
read -p "Enter number of days for recent files: " NUM_DAYS

# Set date format
DATE_FORMAT="%Y-%m-%dT%H:%M:%S.%N%z"

# Set Google Drive folder for reports
REPORTSFOLDER="1bWL5G_bqjr4n1C8rx_KxuG99AqsgyGcN"

echo "Analyzing files for ${USER_EMAIL}..."

# Run GAM command to get all non-trashed files for user
GAM_CMD="${GAM_PATH:-gam} user \"${USER_EMAIL}\" show filelist query \"trashed=false\" fields \"size,id,name,mimeType,modifiedTime\""
FILES=$(eval "$GAM_CMD")

# Create analysis report record
ANALYSIS_ID=$(execute_db "
INSERT INTO file_analysis_reports (user_email, analysis_type, cutoff_days, session_id, parameters)
VALUES ('$USER_EMAIL', 'recent_old_split', $NUM_DAYS, '$SESSION_ID', 
        json_object('cutoff_days', $NUM_DAYS, 'analysis_date', datetime('now')));
SELECT last_insert_rowid();
")

echo "Created analysis report with ID: $ANALYSIS_ID"

# Get cutoff date for recent vs old files
DATE=$(date -d "${NUM_DAYS} days ago" +$DATE_FORMAT)
echo "Cutoff date for recent files: $DATE"

# Process files and categorize them
total_files=0
recent_files=0
old_files=0
total_size=0
recent_size=0
old_size=0

echo "Processing file data..."
echo "$FILES" | tail -n +2 | grep -v ",application/vnd.google-apps." | while IFS=',' read -r size file_id name mime_type modified_time rest; do
    # Clean up the fields (remove quotes, handle commas in names)
    size=$(echo "$size" | tr -d '"' | tr -d ' ')
    file_id=$(echo "$file_id" | tr -d '"')
    mime_type=$(echo "$mime_type" | tr -d '"')
    modified_time=$(echo "$modified_time" | tr -d '"')
    
    # Skip empty lines or invalid data
    [[ -z "$file_id" ]] && continue
    
    # Escape single quotes for SQL
    name=$(echo "$name" | sed "s/'/''/g")
    
    # Determine if file is recent or old
    if [[ "$modified_time" > "$DATE" ]]; then
        category="recent"
    else
        category="old"
    fi
    
    # Insert file record into database
    execute_db "
    INSERT INTO file_records (analysis_id, file_id, file_name, file_size, mime_type, modified_time, file_category)
    VALUES ($ANALYSIS_ID, '$file_id', '$name', $size, '$mime_type', '$modified_time', '$category');
    "
done

# Calculate statistics from database
STATS=$(execute_db "
SELECT 
    COUNT(*) as total_files,
    COUNT(CASE WHEN file_category = 'recent' THEN 1 END) as recent_files,
    COUNT(CASE WHEN file_category = 'old' THEN 1 END) as old_files,
    COALESCE(SUM(file_size), 0) as total_size,
    COALESCE(SUM(CASE WHEN file_category = 'recent' THEN file_size ELSE 0 END), 0) as recent_size,
    COALESCE(SUM(CASE WHEN file_category = 'old' THEN file_size ELSE 0 END), 0) as old_size
FROM file_records 
WHERE analysis_id = $ANALYSIS_ID;
")

# Parse statistics
IFS='|' read -r total_files recent_files old_files total_size recent_size old_size <<< "$STATS"

# Format file sizes
if command -v numfmt >/dev/null 2>&1; then
    RECENT_SIZE_FORMATTED=$(echo "${recent_size}" | numfmt --to=iec)
    OLD_SIZE_FORMATTED=$(echo "${old_size}" | numfmt --to=iec)
    TOTAL_SIZE_FORMATTED=$(echo "${total_size}" | numfmt --to=iec)
else
    RECENT_SIZE_FORMATTED="${recent_size} bytes"
    OLD_SIZE_FORMATTED="${old_size} bytes"
    TOTAL_SIZE_FORMATTED="${total_size} bytes"
fi

# Update analysis report with final statistics
execute_db "
UPDATE file_analysis_reports 
SET total_files = $total_files,
    recent_files = $recent_files,
    old_files = $old_files,
    total_size = $total_size,
    recent_size = $recent_size,
    old_size = $old_size
WHERE id = $ANALYSIS_ID;
"

# Display results
echo ""
echo "=== FILE ANALYSIS RESULTS ==="
echo "Total files for ${USER_EMAIL}: ${total_files} files, total size ${TOTAL_SIZE_FORMATTED}"
echo "Recent files (last ${NUM_DAYS} days): ${recent_files} files, total size ${RECENT_SIZE_FORMATTED}"
echo "Old files (older than ${NUM_DAYS} days): ${old_files} files, total size ${OLD_SIZE_FORMATTED}"

# Generate CSV export files for backwards compatibility
TEMP_DIR="${SCRIPT_TEMP_PATH:-./tmp}"
mkdir -p "$TEMP_DIR"

ALL_FILES="${TEMP_DIR}/${USER_EMAIL}_files.csv"
RECENT_FILES="${TEMP_DIR}/${USER_EMAIL}_recent_files.csv"
OLD_FILES="${TEMP_DIR}/${USER_EMAIL}_old_files.csv"

echo "Generating CSV export files..."

# Export all files
execute_db "
.headers on
.mode csv
.output '$ALL_FILES'
SELECT file_size as Size, file_id as ID, file_name as Name, mime_type as Type, modified_time as 'Modified Time'
FROM file_records 
WHERE analysis_id = $ANALYSIS_ID
ORDER BY modified_time DESC;
.output stdout
"

# Export recent files
execute_db "
.headers on
.mode csv
.output '$RECENT_FILES'
SELECT file_size as Size, file_id as ID, file_name as Name, mime_type as Type, modified_time as 'Modified Time'
FROM file_records 
WHERE analysis_id = $ANALYSIS_ID AND file_category = 'recent'
ORDER BY modified_time DESC;
.output stdout
"

# Export old files
execute_db "
.headers on
.mode csv
.output '$OLD_FILES'
SELECT file_size as Size, file_id as ID, file_name as Name, mime_type as Type, modified_time as 'Modified Time'
FROM file_records 
WHERE analysis_id = $ANALYSIS_ID AND file_category = 'old'
ORDER BY modified_time DESC;
.output stdout
"

echo "CSV files generated:"
echo "  - All files: $ALL_FILES"
echo "  - Recent files: $RECENT_FILES"  
echo "  - Old files: $OLD_FILES"

# Grant access to reports folder
echo "Granting access to reports folder..."
$GAM user "$ADMIN_USER_VAR" add drivefileacl $REPORTSFOLDER user "$USER_EMAIL" role writer >/dev/null 2>&1

# Create Google Sheets file with summary data
echo "Creating Google Sheets report..."
SUMMARY_CSV="${TEMP_DIR}/${USER_EMAIL}_summary.csv"
cat > "$SUMMARY_CSV" << EOF
Category,File Count,Total Size (bytes),Total Size (formatted)
All Files,$total_files,$total_size,$TOTAL_SIZE_FORMATTED
Recent Files (${NUM_DAYS} days),$recent_files,$recent_size,$RECENT_SIZE_FORMATTED
Old Files (${NUM_DAYS}+ days),$old_files,$old_size,$OLD_SIZE_FORMATTED
EOF

sheet_id=$($GAM user $USER_EMAIL create drivefile drivefilename "$USER_EMAIL File Analysis Report" localfile "$SUMMARY_CSV" mimetype "application/vnd.google-apps.spreadsheet" parentid $REPORTSFOLDER returnidonly)

# Clean up temporary summary file
rm -f "$SUMMARY_CSV"

# Remove access from reports folder
$GAM user "$ADMIN_USER_VAR" delete drivefileacl $REPORTSFOLDER "$USER_EMAIL" >/dev/null 2>&1

# Add additional user as editor (configurable)
if [[ -n "${REPORT_EDITOR_EMAIL:-}" ]]; then
    $GAM user $USER_EMAIL add drivefileacl $sheet_id user "${REPORT_EDITOR_EMAIL}" role writer >/dev/null 2>&1
fi

# Display sheet information
$GAM user "$ADMIN_USER_VAR" show fileinfo $sheet_id fields webViewLink

# Update analysis report with generated files
execute_db "
UPDATE file_analysis_reports 
SET report_path = json_object(
    'google_sheet_id', '$sheet_id',
    'all_files_csv', '$ALL_FILES',
    'recent_files_csv', '$RECENT_FILES',
    'old_files_csv', '$OLD_FILES'
)
WHERE id = $ANALYSIS_ID;
"

echo ""
echo "=== ANALYSIS COMPLETE ==="
echo "Analysis ID: $ANALYSIS_ID"
echo "Session ID: $SESSION_ID"
echo "Google Sheet ID: $sheet_id"

# Show database summary
echo ""
echo "Database Summary:"
execute_db "
SELECT 
    'Analysis Reports: ' || COUNT(*) as summary
FROM file_analysis_reports 
WHERE user_email = '$USER_EMAIL'
UNION ALL
SELECT 
    'Total File Records: ' || COUNT(*) as summary
FROM file_records fr
JOIN file_analysis_reports far ON fr.analysis_id = far.id
WHERE far.user_email = '$USER_EMAIL';
"

echo ""
echo "To view analysis history for this user:"
echo "sqlite3 $DB_PATH \"SELECT id, analysis_type, cutoff_days, total_files, recent_files, old_files, report_generated_at FROM file_analysis_reports WHERE user_email = '$USER_EMAIL' ORDER BY report_generated_at DESC;\""