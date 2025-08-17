# CSV to SQLite Migration Guide

This document outlines the migration from CSV-based data storage to SQLite database for GWOMBAT utility scripts.

## Overview

The migration replaces temporary CSV files with persistent SQLite database tables, providing:
- **Better data integrity** - ACID compliance and proper data types
- **Persistent storage** - No more temporary files that can be lost
- **Query capabilities** - SQL queries for complex data analysis
- **Audit trails** - Complete history of operations
- **Concurrent access** - Multiple scripts can safely access the same data

## Migrated Scripts

### 1. ownership_management.sh → ownership_management_sqlite.sh

**Old CSV Usage:**
- `$FOLDERID-unsuspended-temp.csv` - Temporary list of unsuspended users
- `$FOLDERID-ownership-change-tree.csv` - Log of GAM ownership changes

**New SQLite Tables:**
- `file_operations` - Tracks all file operations with status
- `temp_user_states` - Manages temporary user state changes
- Full audit trail with session tracking

**Key Improvements:**
- Automatic restoration tracking for suspended users
- Complete operation history with status tracking
- Session correlation for debugging
- Proper error handling and rollback capabilities

### 2. recent4.sh → recent4_sqlite.sh

**Old CSV Usage:**
- `${USER_EMAIL}_files.csv` - All user files
- `${USER_EMAIL}_recent_files.csv` - Files modified in last N days
- `${USER_EMAIL}_old_files.csv` - Files older than N days

**New SQLite Tables:**
- `file_analysis_reports` - Analysis metadata and statistics
- `file_records` - Individual file details with categorization
- Historical analysis tracking per user

**Key Improvements:**
- Persistent storage of analysis results
- Historical trend analysis capabilities
- Automatic statistics calculation
- Better categorization and filtering

## New Database Schema

### Core Tables Added

```sql
-- File operations tracking
CREATE TABLE file_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL,
    session_id TEXT,
    target_id TEXT NOT NULL,
    operation_status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- ... additional fields
);

-- Temporary user state management
CREATE TABLE temp_user_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id INTEGER,
    user_email TEXT NOT NULL,
    original_state TEXT NOT NULL,
    temporary_state TEXT NOT NULL,
    restore_needed INTEGER DEFAULT 1
    -- ... additional fields
);

-- File analysis reports
CREATE TABLE file_analysis_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    analysis_type TEXT NOT NULL,
    total_files INTEGER,
    recent_files INTEGER,
    old_files INTEGER
    -- ... additional fields
);

-- Individual file records
CREATE TABLE file_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id INTEGER,
    file_id TEXT NOT NULL,
    file_category TEXT,
    FOREIGN KEY (analysis_id) REFERENCES file_analysis_reports(id)
    -- ... additional fields
);
```

## Migration Steps

### 1. Initialize Database
```bash
# Apply migration schema
./shared-utilities/sqlite_operations.sh init
```

### 2. Update Script Usage

**Old ownership management:**
```bash
./shared-utilities/ownership_management.sh folder_id owner admin_user true
```

**New ownership management:**
```bash
./shared-utilities/ownership_management_sqlite.sh folder_id owner admin_user true
```

**Old file analysis:**
```bash
./shared-utilities/recent4.sh
```

**New file analysis:**
```bash
./shared-utilities/recent4_sqlite.sh
```

### 3. Manage Operations

**List pending user restorations:**
```bash
./shared-utilities/sqlite_operations.sh list-pending
```

**Restore all suspended users:**
```bash
./shared-utilities/sqlite_operations.sh restore-users
```

**View operation history:**
```bash
./shared-utilities/sqlite_operations.sh list-operations
```

**View analysis history:**
```bash
./shared-utilities/sqlite_operations.sh list-analyses
```

## Key Features

### 1. Automatic User State Restoration

The new system automatically tracks when users are temporarily unsuspended and provides easy restoration:

```bash
# View users needing restoration
./shared-utilities/sqlite_operations.sh list-pending

# Restore all users
./shared-utilities/sqlite_operations.sh restore-users

# Restore specific session
./shared-utilities/sqlite_operations.sh restore-session 20250815_143022_12345
```

### 2. Operation Tracking

Every file operation is tracked with:
- Unique operation ID
- Session correlation
- Status tracking (pending → in_progress → completed/failed)
- Detailed JSON metadata
- Timing information

### 3. Analysis History

File analyses are preserved with:
- Complete file inventories
- Statistical summaries
- Historical comparison capability
- Export functionality

### 4. Data Integrity

- ACID transactions ensure data consistency
- Foreign key constraints maintain relationships
- Proper data types prevent corruption
- Automatic cleanup of old records

## Backward Compatibility

The new scripts maintain backward compatibility by:
- Still generating CSV export files
- Preserving the same Google Sheets integration
- Maintaining identical command-line interfaces
- Providing the same output formats

## Database Maintenance

### Regular Cleanup
```bash
# Clean up old records (automated)
./shared-utilities/sqlite_operations.sh cleanup-old
```

### Export Data
```bash
# Export analysis to CSV
./shared-utilities/sqlite_operations.sh export-csv 123

# View database statistics
./shared-utilities/sqlite_operations.sh stats
```

### Manual Queries
```bash
# Direct database access
sqlite3 ./config/gwombat.db

# View recent operations
sqlite3 ./config/gwombat.db "SELECT * FROM file_operations ORDER BY created_at DESC LIMIT 10;"

# Check pending restorations
sqlite3 ./config/gwombat.db "SELECT * FROM pending_restorations;"
```

## Benefits

1. **Reliability** - No more lost temporary files
2. **Persistence** - Complete operation history
3. **Debugging** - Session tracking and detailed logs
4. **Analytics** - SQL queries for complex analysis
5. **Automation** - Scheduled cleanup and maintenance
6. **Safety** - Automatic restoration tracking
7. **Scalability** - Handles large datasets efficiently

## Migration Timeline

1. **Phase 1** - Deploy new SQLite scripts alongside existing CSV scripts
2. **Phase 2** - Test new scripts in production environment
3. **Phase 3** - Update main GWOMBAT application to use SQLite scripts
4. **Phase 4** - Deprecate old CSV scripts after validation period

## Troubleshooting

### Database Issues
```bash
# Check database integrity
sqlite3 ./config/gwombat.db "PRAGMA integrity_check;"

# Rebuild database if needed
sqlite3 ./config/gwombat.db "VACUUM;"
```

### Migration Issues
```bash
# Re-initialize tables
./shared-utilities/sqlite_operations.sh init

# Check table structure
sqlite3 ./config/gwombat.db ".schema file_operations"
```

### Data Recovery
```bash
# Export all data
sqlite3 ./config/gwombat.db ".dump" > backup.sql

# Restore from backup
sqlite3 ./config/gwombat.db < backup.sql
```

This migration significantly improves the reliability and maintainability of GWOMBAT while preserving all existing functionality.