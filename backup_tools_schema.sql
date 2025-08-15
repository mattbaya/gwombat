-- Backup Tools Integration Schema
-- Extends GWOMBAT database with GYB and rclone support

-- GYB (Got Your Back) Gmail backup tracking
CREATE TABLE IF NOT EXISTS gyb_backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    backup_type TEXT NOT NULL CHECK(backup_type IN ('full', 'incremental', 'verify', 'restore')),
    backup_path TEXT,
    backup_size_bytes INTEGER DEFAULT 0,
    message_count INTEGER DEFAULT 0,
    label_count INTEGER DEFAULT 0,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status TEXT DEFAULT 'running' CHECK(status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    exit_code INTEGER,
    error_message TEXT,
    session_id TEXT,
    gyb_version TEXT,
    backup_flags TEXT, -- JSON with GYB command flags used
    compression_ratio REAL, -- Compression ratio achieved
    verification_status TEXT CHECK(verification_status IN ('pending', 'passed', 'failed', 'skipped'))
);

-- rclone cloud storage operations tracking
CREATE TABLE IF NOT EXISTS rclone_operations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL CHECK(operation_type IN ('copy', 'sync', 'move', 'check', 'cleanup', 'purge')),
    source_path TEXT NOT NULL,
    destination_path TEXT NOT NULL,
    cloud_provider TEXT, -- 'gdrive', 's3', 'azure', etc.
    remote_name TEXT, -- rclone remote name
    transferred_files INTEGER DEFAULT 0,
    transferred_bytes INTEGER DEFAULT 0,
    deleted_files INTEGER DEFAULT 0,
    failed_transfers INTEGER DEFAULT 0,
    transfer_rate_mbps REAL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status TEXT DEFAULT 'running' CHECK(status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    exit_code INTEGER,
    error_message TEXT,
    session_id TEXT,
    rclone_version TEXT,
    operation_flags TEXT, -- JSON with rclone command flags used
    bandwidth_limit TEXT,
    progress_percentage INTEGER DEFAULT 0
);

-- Backup policies and schedules
CREATE TABLE IF NOT EXISTS backup_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    policy_name TEXT UNIQUE NOT NULL,
    policy_type TEXT NOT NULL CHECK(policy_type IN ('gmail', 'drive', 'photos', 'full')),
    target_ou TEXT, -- OU to apply policy to
    trigger_event TEXT CHECK(trigger_event IN ('suspension', 'deletion', 'scheduled', 'manual')),
    schedule_cron TEXT, -- Cron expression for scheduled backups
    retention_days INTEGER DEFAULT 365,
    backup_destination TEXT, -- Local path or cloud remote
    gyb_flags TEXT, -- JSON with GYB flags
    rclone_flags TEXT, -- JSON with rclone flags
    compression_enabled INTEGER DEFAULT 1,
    verification_enabled INTEGER DEFAULT 1,
    notification_enabled INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Backup storage locations and cloud remotes
CREATE TABLE IF NOT EXISTS backup_storage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    storage_name TEXT UNIQUE NOT NULL,
    storage_type TEXT NOT NULL CHECK(storage_type IN ('local', 'gdrive', 's3', 'azure', 'dropbox', 'onedrive')),
    rclone_remote_name TEXT, -- Corresponding rclone remote
    base_path TEXT,
    total_capacity_gb INTEGER,
    used_space_gb INTEGER DEFAULT 0,
    available_space_gb INTEGER,
    last_checked TIMESTAMP,
    connection_status TEXT DEFAULT 'unknown' CHECK(connection_status IN ('connected', 'disconnected', 'error', 'unknown')),
    bandwidth_limit TEXT,
    cost_per_gb_month REAL, -- For cost tracking
    is_primary INTEGER DEFAULT 0, -- Primary backup destination
    is_active INTEGER DEFAULT 1,
    credentials_path TEXT, -- Path to credentials file
    encryption_enabled INTEGER DEFAULT 0
);

-- Backup verification and integrity checks
CREATE TABLE IF NOT EXISTS backup_verification (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    backup_id INTEGER, -- References gyb_backups.id
    rclone_operation_id INTEGER, -- References rclone_operations.id  
    verification_type TEXT NOT NULL CHECK(verification_type IN ('checksum', 'size', 'count', 'restore_test')),
    original_checksum TEXT,
    backup_checksum TEXT,
    original_size INTEGER,
    backup_size INTEGER,
    verification_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL CHECK(status IN ('passed', 'failed', 'warning')),
    details TEXT, -- JSON with detailed verification results
    session_id TEXT,
    FOREIGN KEY (backup_id) REFERENCES gyb_backups(id) ON DELETE CASCADE,
    FOREIGN KEY (rclone_operation_id) REFERENCES rclone_operations(id) ON DELETE CASCADE
);

-- Backup alerts and notifications
CREATE TABLE IF NOT EXISTS backup_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_type TEXT NOT NULL CHECK(alert_type IN ('backup_failed', 'verification_failed', 'storage_full', 'schedule_missed', 'quota_exceeded')),
    severity TEXT NOT NULL CHECK(severity IN ('info', 'warning', 'error', 'critical')),
    user_email TEXT,
    backup_id INTEGER,
    rclone_operation_id INTEGER,
    message TEXT NOT NULL,
    details TEXT, -- JSON with additional alert context
    acknowledged INTEGER DEFAULT 0,
    acknowledged_by TEXT,
    acknowledged_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notification_sent INTEGER DEFAULT 0,
    FOREIGN KEY (backup_id) REFERENCES gyb_backups(id) ON DELETE SET NULL,
    FOREIGN KEY (rclone_operation_id) REFERENCES rclone_operations(id) ON DELETE SET NULL
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_gyb_backups_user ON gyb_backups(user_email);
CREATE INDEX IF NOT EXISTS idx_gyb_backups_status ON gyb_backups(status);
CREATE INDEX IF NOT EXISTS idx_gyb_backups_start_time ON gyb_backups(start_time);
CREATE INDEX IF NOT EXISTS idx_rclone_operations_type ON rclone_operations(operation_type);
CREATE INDEX IF NOT EXISTS idx_rclone_operations_status ON rclone_operations(status);
CREATE INDEX IF NOT EXISTS idx_rclone_operations_start_time ON rclone_operations(start_time);
CREATE INDEX IF NOT EXISTS idx_backup_policies_type ON backup_policies(policy_type);
CREATE INDEX IF NOT EXISTS idx_backup_policies_active ON backup_policies(is_active);
CREATE INDEX IF NOT EXISTS idx_backup_storage_type ON backup_storage(storage_type);
CREATE INDEX IF NOT EXISTS idx_backup_storage_active ON backup_storage(is_active);
CREATE INDEX IF NOT EXISTS idx_backup_verification_status ON backup_verification(status);
CREATE INDEX IF NOT EXISTS idx_backup_alerts_type ON backup_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_backup_alerts_severity ON backup_alerts(severity);

-- Views for backup dashboard and reporting
CREATE VIEW IF NOT EXISTS backup_summary AS
SELECT 
    'Total Gmail Backups' as metric,
    COUNT(*) as value,
    'backups' as unit,
    MAX(start_time) as last_updated
FROM gyb_backups 
WHERE status = 'completed'
UNION ALL
SELECT 
    'Failed Backups (24h)' as metric,
    COUNT(*) as value,
    'failures' as unit,
    MAX(start_time) as last_updated
FROM gyb_backups 
WHERE status = 'failed' AND start_time > datetime('now', '-24 hours')
UNION ALL
SELECT 
    'Cloud Operations (24h)' as metric,
    COUNT(*) as value,
    'operations' as unit,
    MAX(start_time) as last_updated
FROM rclone_operations 
WHERE start_time > datetime('now', '-24 hours')
UNION ALL
SELECT 
    'Total Backup Storage' as metric,
    COALESCE(SUM(backup_size_bytes) / (1024*1024*1024), 0) as value,
    'GB' as unit,
    MAX(end_time) as last_updated
FROM gyb_backups 
WHERE status = 'completed';

CREATE VIEW IF NOT EXISTS backup_health AS
SELECT 
    user_email,
    MAX(start_time) as last_backup,
    COUNT(*) as backup_count,
    SUM(backup_size_bytes) as total_backup_size,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as successful_backups,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_backups,
    AVG(CASE WHEN end_time IS NOT NULL THEN 
        (strftime('%s', end_time) - strftime('%s', start_time)) 
        ELSE NULL END) as avg_backup_duration_seconds
FROM gyb_backups 
GROUP BY user_email
ORDER BY last_backup DESC;

CREATE VIEW IF NOT EXISTS cloud_storage_usage AS
SELECT 
    bs.storage_name,
    bs.storage_type,
    bs.used_space_gb,
    bs.total_capacity_gb,
    ROUND((bs.used_space_gb * 100.0) / bs.total_capacity_gb, 2) as usage_percentage,
    bs.connection_status,
    COUNT(ro.id) as recent_operations
FROM backup_storage bs
LEFT JOIN rclone_operations ro ON bs.rclone_remote_name = ro.remote_name 
    AND ro.start_time > datetime('now', '-24 hours')
WHERE bs.is_active = 1
GROUP BY bs.id, bs.storage_name, bs.storage_type, bs.used_space_gb, bs.total_capacity_gb, bs.connection_status
ORDER BY usage_percentage DESC;

CREATE VIEW IF NOT EXISTS recent_backup_activity AS
SELECT 
    'gyb' as tool,
    user_email as target,
    backup_type as operation,
    status,
    start_time,
    CASE WHEN end_time IS NOT NULL THEN 
        (strftime('%s', end_time) - strftime('%s', start_time)) 
        ELSE NULL END as duration_seconds,
    backup_size_bytes as size_bytes
FROM gyb_backups 
WHERE start_time > datetime('now', '-24 hours')
UNION ALL
SELECT 
    'rclone' as tool,
    destination_path as target,
    operation_type as operation,
    status,
    start_time,
    CASE WHEN end_time IS NOT NULL THEN 
        (strftime('%s', end_time) - strftime('%s', start_time)) 
        ELSE NULL END as duration_seconds,
    transferred_bytes as size_bytes
FROM rclone_operations 
WHERE start_time > datetime('now', '-24 hours')
ORDER BY start_time DESC;

-- Insert default backup policies
INSERT OR IGNORE INTO backup_policies (policy_name, policy_type, trigger_event, retention_days, backup_destination, is_active) VALUES 
('Suspended Users Gmail Backup', 'gmail', 'suspension', 1095, '/backups/gmail', 1),
('Pending Deletion Full Backup', 'full', 'deletion', 2555, '/backups/full', 1),
('Weekly Admin Backup', 'gmail', 'scheduled', 365, '/backups/weekly', 1);

-- Insert default storage locations
INSERT OR IGNORE INTO backup_storage (storage_name, storage_type, base_path, is_primary, is_active) VALUES 
('Local Primary', 'local', '/opt/gwombat/backups', 1, 1),
('Google Drive Archive', 'gdrive', '/GWOMBAT_Backups', 0, 0),
('AWS S3 Archive', 's3', 'gwombat-backups', 0, 0);

-- Triggers for automatic alerts
CREATE TRIGGER IF NOT EXISTS backup_failure_alert
AFTER UPDATE OF status ON gyb_backups
WHEN NEW.status = 'failed'
BEGIN
    INSERT INTO backup_alerts (alert_type, severity, user_email, backup_id, message)
    VALUES ('backup_failed', 'error', NEW.user_email, NEW.id, 
            'Gmail backup failed for ' || NEW.user_email || ': ' || COALESCE(NEW.error_message, 'Unknown error'));
END;

CREATE TRIGGER IF NOT EXISTS rclone_failure_alert
AFTER UPDATE OF status ON rclone_operations
WHEN NEW.status = 'failed'
BEGIN
    INSERT INTO backup_alerts (alert_type, severity, rclone_operation_id, message)
    VALUES ('backup_failed', 'error', NEW.id, 
            'Cloud operation failed: ' || NEW.operation_type || ' from ' || NEW.source_path || ' to ' || NEW.destination_path);
END;