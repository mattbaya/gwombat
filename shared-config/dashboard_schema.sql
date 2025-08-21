-- Dashboard Database Schema
-- Extends the main GWOMBAT database with dashboard and statistics tables

-- OU Statistics tracking
CREATE TABLE IF NOT EXISTS ou_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ou_path TEXT NOT NULL,
    account_count INTEGER DEFAULT 0,
    suspended_count INTEGER DEFAULT 0,
    active_count INTEGER DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scan_session_id TEXT,
    scan_duration_seconds REAL,
    status TEXT DEFAULT 'current' CHECK(status IN ('current', 'historical')),
    UNIQUE(ou_path, scan_session_id)
);

-- System metrics and health
CREATE TABLE IF NOT EXISTS system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value TEXT NOT NULL,
    metric_type TEXT DEFAULT 'counter' CHECK(metric_type IN ('counter', 'gauge', 'histogram', 'summary')),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    details TEXT -- JSON for additional context
);

-- Extended statistics tracking
CREATE TABLE IF NOT EXISTS extended_statistics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    statistic_name TEXT NOT NULL,
    statistic_value INTEGER NOT NULL,
    calculation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scan_session_id TEXT,
    scan_duration_seconds REAL,
    status TEXT DEFAULT 'current' CHECK(status IN ('current', 'historical')),
    details TEXT -- JSON for additional context
);

-- Dashboard cache for performance
CREATE TABLE IF NOT EXISTS dashboard_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cache_key TEXT UNIQUE NOT NULL,
    cache_value TEXT NOT NULL, -- JSON
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System logs (centralized logging)
CREATE TABLE IF NOT EXISTS system_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    log_level TEXT NOT NULL CHECK(log_level IN ('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    session_id TEXT,
    operation TEXT,
    user_email TEXT,
    message TEXT NOT NULL,
    details TEXT, -- JSON
    source_file TEXT,
    line_number INTEGER,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Operation progress tracking
CREATE TABLE IF NOT EXISTS operation_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_id TEXT UNIQUE NOT NULL,
    session_id TEXT,
    operation_type TEXT NOT NULL,
    operation_name TEXT,
    total_items INTEGER DEFAULT 0,
    completed_items INTEGER DEFAULT 0,
    failed_items INTEGER DEFAULT 0,
    current_item TEXT,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estimated_completion TIMESTAMP,
    completion_time TIMESTAMP,
    status TEXT DEFAULT 'running' CHECK(status IN ('pending', 'running', 'completed', 'failed', 'cancelled')),
    error_message TEXT
);

-- Recent activity summary
CREATE TABLE IF NOT EXISTS activity_summary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    activity_type TEXT NOT NULL,
    activity_description TEXT NOT NULL,
    affected_users INTEGER DEFAULT 0,
    session_id TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT -- JSON
);

-- Performance metrics
CREATE TABLE IF NOT EXISTS performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operation_type TEXT NOT NULL,
    operation_name TEXT,
    duration_seconds REAL NOT NULL,
    items_processed INTEGER DEFAULT 0,
    throughput_per_second REAL,
    memory_usage_mb REAL,
    session_id TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    success INTEGER DEFAULT 1 -- 1 for success, 0 for failure
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_ou_statistics_path ON ou_statistics(ou_path);
CREATE INDEX IF NOT EXISTS idx_ou_statistics_updated ON ou_statistics(last_updated);
CREATE INDEX IF NOT EXISTS idx_ou_statistics_status ON ou_statistics(status);
CREATE INDEX IF NOT EXISTS idx_system_metrics_name ON system_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_dashboard_cache_key ON dashboard_cache(cache_key);
CREATE INDEX IF NOT EXISTS idx_dashboard_cache_expires ON dashboard_cache(expires_at);
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON system_logs(log_level);
CREATE INDEX IF NOT EXISTS idx_system_logs_session ON system_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_system_logs_timestamp ON system_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_operation_progress_status ON operation_progress(status);
CREATE INDEX IF NOT EXISTS idx_operation_progress_session ON operation_progress(session_id);
CREATE INDEX IF NOT EXISTS idx_activity_summary_type ON activity_summary(activity_type);
CREATE INDEX IF NOT EXISTS idx_activity_summary_timestamp ON activity_summary(timestamp);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_operation ON performance_metrics(operation_type);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_timestamp ON performance_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_extended_statistics_name ON extended_statistics(statistic_name);
CREATE INDEX IF NOT EXISTS idx_extended_statistics_status ON extended_statistics(status);
CREATE INDEX IF NOT EXISTS idx_extended_statistics_time ON extended_statistics(calculation_time);

-- Views for dashboard queries
CREATE VIEW IF NOT EXISTS dashboard_summary AS
SELECT 
    'Total Suspended Users' as metric,
    COALESCE(SUM(suspended_count), 0) as value,
    MAX(last_updated) as last_updated
FROM ou_statistics 
WHERE status = 'current' AND ou_path LIKE '%Suspended%'
UNION ALL
SELECT 
    'Pending Deletion' as metric,
    COALESCE(SUM(account_count), 0) as value,
    MAX(last_updated) as last_updated
FROM ou_statistics 
WHERE status = 'current' AND ou_path LIKE '%Pending Deletion%'
UNION ALL
SELECT 
    'Temporary Hold' as metric,
    COALESCE(SUM(account_count), 0) as value,
    MAX(last_updated) as last_updated
FROM ou_statistics 
WHERE status = 'current' AND ou_path LIKE '%Temporary Hold%'
UNION ALL
SELECT 
    'Exit Row' as metric,
    COALESCE(SUM(account_count), 0) as value,
    MAX(last_updated) as last_updated
FROM ou_statistics 
WHERE status = 'current' AND ou_path LIKE '%Exit Row%'
UNION ALL
SELECT 
    'Inactive Users (30+ days)' as metric,
    COALESCE(statistic_value, 0) as value,
    calculation_time as last_updated
FROM extended_statistics 
WHERE statistic_name = 'inactive_users_30d' AND status = 'current'
UNION ALL
SELECT 
    'Shared Drives' as metric,
    COALESCE(statistic_value, 0) as value,
    calculation_time as last_updated
FROM extended_statistics 
WHERE statistic_name = 'shared_drives_count' AND status = 'current';

CREATE VIEW IF NOT EXISTS recent_activity AS
SELECT 
    activity_type,
    activity_description,
    affected_users,
    timestamp,
    session_id
FROM activity_summary
WHERE timestamp > datetime('now', '-24 hours')
ORDER BY timestamp DESC
LIMIT 10;

CREATE VIEW IF NOT EXISTS system_health AS
SELECT 
    'Database Records' as component,
    (SELECT COUNT(*) FROM accounts) as value,
    'records' as unit,
    'healthy' as status
UNION ALL
SELECT 
    'Recent Operations' as component,
    (SELECT COUNT(*) FROM operation_log WHERE created_at > datetime('now', '-1 hour')) as value,
    'operations' as unit,
    CASE 
        WHEN (SELECT COUNT(*) FROM operation_log WHERE created_at > datetime('now', '-1 hour') AND status = 'error') > 5 
        THEN 'warning' 
        ELSE 'healthy' 
    END as status
UNION ALL
SELECT 
    'Active Lists' as component,
    (SELECT COUNT(*) FROM account_lists WHERE is_active = 1) as value,
    'lists' as unit,
    'healthy' as status
UNION ALL
SELECT 
    'Pending Restorations' as component,
    (SELECT COUNT(*) FROM temp_user_states WHERE restore_needed = 1) as value,
    'users' as unit,
    CASE 
        WHEN (SELECT COUNT(*) FROM temp_user_states WHERE restore_needed = 1) > 10 
        THEN 'warning' 
        ELSE 'healthy' 
    END as status;

-- Insert initial dashboard cache entries
INSERT OR IGNORE INTO dashboard_cache (cache_key, cache_value, expires_at) VALUES 
('dashboard_refresh_interval', '300', datetime('now', '+1 year')),
('ou_scan_interval', '1800', datetime('now', '+1 year')),
('log_retention_days', '30', datetime('now', '+1 year')),
('performance_tracking', 'true', datetime('now', '+1 year'));

-- Insert default system metrics
INSERT OR IGNORE INTO system_metrics (metric_name, metric_value, metric_type) VALUES 
('database_initialized', '1', 'gauge'),
('dashboard_enabled', '1', 'gauge'),
('last_startup', strftime('%s', 'now'), 'counter');

-- Cleanup trigger for old data
CREATE TRIGGER IF NOT EXISTS cleanup_old_logs
AFTER INSERT ON system_logs
WHEN (SELECT COUNT(*) FROM system_logs) > 10000
BEGIN
    DELETE FROM system_logs 
    WHERE timestamp < datetime('now', '-30 days')
    AND id NOT IN (
        SELECT id FROM system_logs 
        ORDER BY timestamp DESC 
        LIMIT 10000
    );
END;

-- Trigger to update dashboard cache timestamps
CREATE TRIGGER IF NOT EXISTS update_cache_timestamp
AFTER UPDATE ON dashboard_cache
FOR EACH ROW
BEGIN
    UPDATE dashboard_cache 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.id;
END;