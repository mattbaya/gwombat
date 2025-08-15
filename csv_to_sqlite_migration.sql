-- Migration schema to replace CSV files with SQLite tables
-- Run this after the main database_schema.sql

-- Table for file operations and ownership changes
CREATE TABLE IF NOT EXISTS file_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL CHECK(operation_type IN ('ownership_change', 'file_analysis', 'backup', 'restore')),
    session_id TEXT,
    target_id TEXT NOT NULL, -- folder_id, user_email, etc.
    source_user TEXT,
    target_user TEXT,
    file_id TEXT,
    file_name TEXT,
    file_size INTEGER,
    mime_type TEXT,
    modified_time TEXT,
    operation_status TEXT DEFAULT 'pending' CHECK(operation_status IN ('pending', 'in_progress', 'completed', 'failed')),
    details TEXT, -- JSON with additional details
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Table for temporarily modified user states (like unsuspended users)
CREATE TABLE IF NOT EXISTS temp_user_states (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id INTEGER,
    user_email TEXT NOT NULL,
    original_state TEXT NOT NULL, -- 'suspended', 'active', etc.
    temporary_state TEXT NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    restored_at TIMESTAMP,
    restore_needed INTEGER DEFAULT 1, -- 1 if needs to be restored, 0 if already restored
    session_id TEXT,
    notes TEXT,
    FOREIGN KEY (operation_id) REFERENCES file_operations(id) ON DELETE CASCADE
);

-- Table for file analysis reports
CREATE TABLE IF NOT EXISTS file_analysis_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    analysis_type TEXT NOT NULL CHECK(analysis_type IN ('recent_old_split', 'sharing_analysis', 'storage_analysis')),
    cutoff_days INTEGER,
    total_files INTEGER,
    recent_files INTEGER,
    old_files INTEGER,
    total_size INTEGER,
    recent_size INTEGER,
    old_size INTEGER,
    report_generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    parameters TEXT, -- JSON with analysis parameters
    report_path TEXT -- path to generated report if needed
);

-- Table for individual file records (detailed file information)
CREATE TABLE IF NOT EXISTS file_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id INTEGER,
    file_id TEXT NOT NULL,
    file_name TEXT,
    file_size INTEGER,
    mime_type TEXT,
    modified_time TEXT,
    owner_email TEXT,
    shared_with TEXT, -- JSON array of sharing permissions
    file_category TEXT CHECK(file_category IN ('recent', 'old', 'shared', 'external')),
    drive_location TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (analysis_id) REFERENCES file_analysis_reports(id) ON DELETE CASCADE
);

-- Table for cleanup operations tracking
CREATE TABLE IF NOT EXISTS cleanup_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL CHECK(operation_type IN ('shared_drive_cleanup', 'file_rename', 'label_removal')),
    target_id TEXT NOT NULL, -- drive_id, folder_id, etc.
    files_processed INTEGER DEFAULT 0,
    files_renamed INTEGER DEFAULT 0,
    files_failed INTEGER DEFAULT 0,
    labels_removed INTEGER DEFAULT 0,
    operation_status TEXT DEFAULT 'pending' CHECK(operation_status IN ('pending', 'in_progress', 'completed', 'failed')),
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    session_id TEXT,
    log_file_path TEXT,
    summary TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_file_operations_session ON file_operations(session_id);
CREATE INDEX IF NOT EXISTS idx_file_operations_target ON file_operations(target_id);
CREATE INDEX IF NOT EXISTS idx_temp_user_states_email ON temp_user_states(user_email);
CREATE INDEX IF NOT EXISTS idx_temp_user_states_restore ON temp_user_states(restore_needed);
CREATE INDEX IF NOT EXISTS idx_file_analysis_user ON file_analysis_reports(user_email);
CREATE INDEX IF NOT EXISTS idx_file_records_analysis ON file_records(analysis_id);
CREATE INDEX IF NOT EXISTS idx_file_records_category ON file_records(file_category);
CREATE INDEX IF NOT EXISTS idx_cleanup_operations_type ON cleanup_operations(operation_type);

-- Views for common queries
CREATE VIEW IF NOT EXISTS pending_restorations AS
SELECT 
    tus.id,
    tus.user_email,
    tus.original_state,
    tus.temporary_state,
    tus.changed_at,
    tus.session_id,
    fo.operation_type,
    fo.target_id
FROM temp_user_states tus
LEFT JOIN file_operations fo ON tus.operation_id = fo.id
WHERE tus.restore_needed = 1
ORDER BY tus.changed_at;

CREATE VIEW IF NOT EXISTS operation_summary AS
SELECT 
    fo.id,
    fo.operation_type,
    fo.target_id,
    fo.operation_status,
    fo.created_at,
    fo.completed_at,
    COUNT(tus.id) as temp_state_changes,
    COUNT(CASE WHEN tus.restore_needed = 1 THEN 1 END) as pending_restorations
FROM file_operations fo
LEFT JOIN temp_user_states tus ON fo.id = tus.operation_id
GROUP BY fo.id, fo.operation_type, fo.target_id, fo.operation_status, fo.created_at, fo.completed_at
ORDER BY fo.created_at DESC;

CREATE VIEW IF NOT EXISTS file_analysis_summary AS
SELECT 
    far.id,
    far.user_email,
    far.analysis_type,
    far.cutoff_days,
    far.total_files,
    far.recent_files,
    far.old_files,
    ROUND(far.total_size / 1048576.0, 2) as total_size_mb,
    ROUND(far.recent_size / 1048576.0, 2) as recent_size_mb,
    ROUND(far.old_size / 1048576.0, 2) as old_size_mb,
    far.report_generated_at,
    COUNT(fr.id) as detailed_records
FROM file_analysis_reports far
LEFT JOIN file_records fr ON far.id = fr.analysis_id
GROUP BY far.id
ORDER BY far.report_generated_at DESC;