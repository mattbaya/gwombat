-- Account Lifecycle Management Database Schema
-- Tracks account states, lists/tags, and verification status

-- Main accounts table
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE NOT NULL,
    display_name TEXT,
    current_stage TEXT NOT NULL CHECK(current_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row', 'deleted', 'reactivated')),
    ou_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_verified_at TIMESTAMP,
    notes TEXT
);

-- Lists/Tags for grouping accounts
CREATE TABLE IF NOT EXISTS account_lists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    target_stage TEXT CHECK(target_stage IN ('recently_suspended', 'pending_deletion', 'temporary_hold', 'exit_row', 'deleted', 'reactivated')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1
);

-- Many-to-many relationship between accounts and lists
CREATE TABLE IF NOT EXISTS account_list_memberships (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    list_id INTEGER NOT NULL,
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    FOREIGN KEY (list_id) REFERENCES account_lists(id) ON DELETE CASCADE,
    UNIQUE(account_id, list_id)
);

-- Lifecycle stage history tracking
CREATE TABLE IF NOT EXISTS stage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    from_stage TEXT,
    to_stage TEXT NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by TEXT DEFAULT 'system',
    operation_details TEXT, -- JSON or text description
    session_id TEXT,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE
);

-- Verification status for each account at each stage
CREATE TABLE IF NOT EXISTS verification_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    stage TEXT NOT NULL,
    verification_type TEXT NOT NULL, -- 'lastname_check', 'file_renamed', 'ou_moved', 'groups_removed', etc.
    status TEXT NOT NULL CHECK(status IN ('verified', 'failed', 'pending', 'skipped')),
    verified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT, -- JSON with specific verification results
    auto_verified INTEGER DEFAULT 0, -- 1 if verified automatically, 0 if manual
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    UNIQUE(account_id, stage, verification_type)
);

-- Operation log for audit trail
CREATE TABLE IF NOT EXISTS operation_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER,
    list_id INTEGER,
    operation TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('success', 'error', 'warning', 'info')),
    message TEXT,
    details TEXT, -- JSON with operation specifics
    session_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE SET NULL,
    FOREIGN KEY (list_id) REFERENCES account_lists(id) ON DELETE SET NULL
);

-- Account operations history for suspend/restore tracking
CREATE TABLE IF NOT EXISTS account_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    operation TEXT NOT NULL CHECK(operation IN ('suspend', 'restore', 'reason_update', 'bulk_suspend', 'bulk_restore', 'schedule_suspend', 'schedule_restore')),
    reason TEXT,
    operator TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT, -- JSON with additional operation details
    session_id TEXT,
    retention_until TIMESTAMP DEFAULT (datetime('now', '+7 years')) -- 7-year retention policy
);

-- Configuration table for system settings
CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_accounts_email ON accounts(email);
CREATE INDEX IF NOT EXISTS idx_accounts_stage ON accounts(current_stage);
CREATE INDEX IF NOT EXISTS idx_accounts_updated ON accounts(updated_at);
CREATE INDEX IF NOT EXISTS idx_stage_history_account ON stage_history(account_id);
CREATE INDEX IF NOT EXISTS idx_stage_history_stage ON stage_history(to_stage);
CREATE INDEX IF NOT EXISTS idx_verification_account_stage ON verification_status(account_id, stage);
CREATE INDEX IF NOT EXISTS idx_operation_log_session ON operation_log(session_id);
CREATE INDEX IF NOT EXISTS idx_list_memberships ON account_list_memberships(list_id, account_id);
CREATE INDEX IF NOT EXISTS idx_account_operations_email ON account_operations(email);
CREATE INDEX IF NOT EXISTS idx_account_operations_operation ON account_operations(operation);
CREATE INDEX IF NOT EXISTS idx_account_operations_timestamp ON account_operations(timestamp);
CREATE INDEX IF NOT EXISTS idx_account_operations_retention ON account_operations(retention_until);

-- Views for common queries
CREATE VIEW IF NOT EXISTS account_summary AS
SELECT 
    a.id,
    a.email,
    a.display_name,
    a.current_stage,
    a.ou_path,
    a.updated_at,
    a.last_verified_at,
    GROUP_CONCAT(al.name, ', ') as list_names,
    COUNT(vs.id) as verification_count,
    COUNT(CASE WHEN vs.status = 'verified' THEN 1 END) as verified_count,
    COUNT(CASE WHEN vs.status = 'failed' THEN 1 END) as failed_count
FROM accounts a
LEFT JOIN account_list_memberships alm ON a.id = alm.account_id
LEFT JOIN account_lists al ON alm.list_id = al.id AND al.is_active = 1
LEFT JOIN verification_status vs ON a.id = vs.account_id AND vs.stage = a.current_stage
GROUP BY a.id, a.email, a.display_name, a.current_stage, a.ou_path, a.updated_at, a.last_verified_at;

-- View for list progress tracking
CREATE VIEW IF NOT EXISTS list_progress AS
SELECT 
    al.id as list_id,
    al.name as list_name,
    al.target_stage,
    COUNT(alm.account_id) as total_accounts,
    COUNT(CASE WHEN a.current_stage = al.target_stage THEN 1 END) as accounts_at_target,
    COUNT(CASE WHEN vs.status = 'verified' AND vs.stage = al.target_stage THEN 1 END) as verified_accounts,
    ROUND(
        (COUNT(CASE WHEN a.current_stage = al.target_stage THEN 1 END) * 100.0) / COUNT(alm.account_id), 
        2
    ) as completion_percentage
FROM account_lists al
LEFT JOIN account_list_memberships alm ON al.id = alm.list_id
LEFT JOIN accounts a ON alm.account_id = a.id
LEFT JOIN verification_status vs ON a.id = vs.account_id AND vs.stage = al.target_stage
WHERE al.is_active = 1
GROUP BY al.id, al.name, al.target_stage;

-- Insert default configuration
INSERT OR IGNORE INTO config (key, value) VALUES 
('db_version', '1.0'),
('auto_verify', 'true'),
('verification_timeout', '300'),
('default_session_timeout', '3600'),
('max_batch_size', '100'),
('account_operations_retention_years', '7'),
('stage_history_retention_years', '5'),
('operation_log_retention_years', '3'),
('retention_cleanup_enabled', 'true'),
('retention_cleanup_schedule', 'daily');