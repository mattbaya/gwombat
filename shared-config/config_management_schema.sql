-- Configuration Management Schema for GWOMBAT
-- Handles dashboard settings, scheduling configuration, and user preferences

-- Main configuration table for all GWOMBAT settings
CREATE TABLE IF NOT EXISTS gwombat_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_section TEXT NOT NULL, -- 'dashboard', 'security', 'backup', 'scheduling', 'system'
    config_key TEXT NOT NULL,
    config_value TEXT NOT NULL,
    config_type TEXT DEFAULT 'string', -- 'string', 'integer', 'boolean', 'json'
    description TEXT,
    is_user_configurable INTEGER DEFAULT 1, -- 1 if users can modify this setting
    is_sensitive INTEGER DEFAULT 0, -- 1 if this setting contains sensitive data
    default_value TEXT,
    validation_pattern TEXT, -- regex pattern for validation
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_by TEXT,
    UNIQUE(config_section, config_key)
);

-- Scheduled tasks configuration
CREATE TABLE IF NOT EXISTS scheduled_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_name TEXT UNIQUE NOT NULL,
    task_description TEXT,
    task_type TEXT NOT NULL, -- 'dashboard_refresh', 'security_scan', 'backup_operation', 'cleanup'
    task_command TEXT NOT NULL, -- The actual command/script to execute
    schedule_pattern TEXT NOT NULL, -- Cron-like pattern: "*/30 * * * *" (every 30 minutes)
    is_enabled INTEGER DEFAULT 0, -- 0 = disabled by default (opt-in)
    last_run TIMESTAMP,
    next_run TIMESTAMP,
    run_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_exit_code INTEGER,
    last_output TEXT,
    max_execution_time INTEGER DEFAULT 300, -- Maximum execution time in seconds
    retry_on_failure INTEGER DEFAULT 1, -- Number of retries on failure
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Task execution history
CREATE TABLE IF NOT EXISTS task_execution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    execution_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    execution_end TIMESTAMP,
    exit_code INTEGER,
    output TEXT,
    error_output TEXT,
    execution_time_seconds REAL,
    triggered_by TEXT DEFAULT 'scheduler', -- 'scheduler', 'manual', 'system'
    session_id TEXT,
    FOREIGN KEY (task_id) REFERENCES scheduled_tasks(id) ON DELETE CASCADE
);

-- User preferences for opt-out capabilities
CREATE TABLE IF NOT EXISTS user_preferences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    preference_category TEXT NOT NULL, -- 'scheduling', 'notifications', 'dashboard'
    preference_key TEXT NOT NULL,
    preference_value TEXT NOT NULL,
    user_email TEXT, -- NULL means global/system preference
    description TEXT,
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(preference_category, preference_key, user_email)
);

-- Configuration change audit log
CREATE TABLE IF NOT EXISTS config_audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_section TEXT,
    config_key TEXT,
    old_value TEXT,
    new_value TEXT,
    changed_by TEXT,
    change_reason TEXT,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_gwombat_config_section ON gwombat_config(config_section);
CREATE INDEX IF NOT EXISTS idx_gwombat_config_key ON gwombat_config(config_key);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_enabled ON scheduled_tasks(is_enabled);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_type ON scheduled_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_next_run ON scheduled_tasks(next_run);
CREATE INDEX IF NOT EXISTS idx_task_execution_log_task ON task_execution_log(task_id);
CREATE INDEX IF NOT EXISTS idx_task_execution_log_start ON task_execution_log(execution_start);
CREATE INDEX IF NOT EXISTS idx_user_preferences_category ON user_preferences(preference_category);
CREATE INDEX IF NOT EXISTS idx_config_audit_log_timestamp ON config_audit_log(change_timestamp);

-- Views for easy configuration management
CREATE VIEW IF NOT EXISTS active_scheduled_tasks AS
SELECT 
    t.*,
    CASE 
        WHEN t.next_run IS NULL THEN 'Never scheduled'
        WHEN t.next_run <= datetime('now') THEN 'Ready to run'
        WHEN t.next_run > datetime('now') THEN 'Scheduled for ' || t.next_run
        ELSE 'Unknown'
    END as status,
    CASE 
        WHEN t.run_count > 0 THEN ROUND((t.success_count * 100.0) / t.run_count, 1)
        ELSE 0 
    END as success_rate
FROM scheduled_tasks t
WHERE t.is_enabled = 1
ORDER BY t.next_run ASC;

CREATE VIEW IF NOT EXISTS configuration_summary AS
SELECT 
    config_section,
    COUNT(*) as setting_count,
    SUM(CASE WHEN is_user_configurable = 1 THEN 1 ELSE 0 END) as user_configurable_count,
    SUM(CASE WHEN is_sensitive = 1 THEN 1 ELSE 0 END) as sensitive_count,
    MAX(last_modified) as last_updated
FROM gwombat_config
GROUP BY config_section
ORDER BY config_section;

-- Insert default configuration values
INSERT OR IGNORE INTO gwombat_config (config_section, config_key, config_value, config_type, description, default_value) VALUES
-- Dashboard Settings
('dashboard', 'ou_scan_interval_minutes', '30', 'integer', 'How often to refresh OU statistics (minutes)', '30'),
('dashboard', 'extended_stats_interval_minutes', '60', 'integer', 'How often to refresh extended statistics (minutes)', '60'),
('dashboard', 'cache_enabled', 'true', 'boolean', 'Enable caching for dashboard statistics', 'true'),
('dashboard', 'auto_refresh_enabled', 'false', 'boolean', 'Enable automatic dashboard refresh', 'false'),
('dashboard', 'show_quick_stats', 'true', 'boolean', 'Show quick statistics in dashboard menu', 'true'),

-- Security Settings
('security', 'scan_login_days', '7', 'integer', 'Days of login history to analyze', '7'),
('security', 'scan_admin_days', '1', 'integer', 'Days of admin activity to analyze', '1'),
('security', 'failed_login_threshold', '5', 'integer', 'Failed login attempts before alert', '5'),
('security', 'compliance_scan_enabled', 'true', 'boolean', 'Enable security compliance scanning', 'true'),
('security', 'oauth_risk_monitoring', 'true', 'boolean', 'Enable OAuth application risk monitoring', 'true'),
('security', 'auto_security_alerts', 'true', 'boolean', 'Enable automatic security alerting', 'true'),

-- Backup Settings
('backup', 'auto_backup_enabled', 'false', 'boolean', 'Enable automatic user backups on suspension', 'false'),
('backup', 'backup_retention_days', '365', 'integer', 'Days to retain backup files', '365'),
('backup', 'gmail_backup_enabled', 'true', 'boolean', 'Include Gmail in automatic backups', 'true'),
('backup', 'drive_backup_enabled', 'true', 'boolean', 'Include Drive files in automatic backups', 'true'),
('backup', 'cloud_upload_enabled', 'false', 'boolean', 'Upload backups to cloud storage', 'false'),

-- Scheduling Settings
('scheduling', 'scheduler_enabled', 'false', 'boolean', 'Enable background task scheduler (MASTER SWITCH)', 'false'),
('scheduling', 'max_concurrent_tasks', '3', 'integer', 'Maximum concurrent scheduled tasks', '3'),
('scheduling', 'task_timeout_minutes', '30', 'integer', 'Default task timeout in minutes', '30'),
('scheduling', 'log_retention_days', '30', 'integer', 'Days to retain task execution logs', '30'),
('scheduling', 'failure_notification_enabled', 'true', 'boolean', 'Send notifications on task failures', 'true'),

-- System Settings
('system', 'log_level', 'INFO', 'string', 'System logging level (DEBUG, INFO, WARNING, ERROR)', 'INFO'),
('system', 'session_timeout_hours', '8', 'integer', 'Session timeout in hours', '8'),
('system', 'cleanup_enabled', 'true', 'boolean', 'Enable automatic cleanup of old logs and temp files', 'true'),
('system', 'performance_monitoring', 'true', 'boolean', 'Enable performance metrics collection', 'true');

-- Insert default scheduled tasks (all disabled by default)
INSERT OR IGNORE INTO scheduled_tasks (task_name, task_description, task_type, task_command, schedule_pattern, is_enabled) VALUES
('dashboard_ou_refresh', 'Refresh OU statistics for dashboard', 'dashboard_refresh', 'shared-utilities/dashboard_functions.sh scan', '*/30 * * * *', 0),
('dashboard_extended_refresh', 'Refresh extended statistics (inactive users, shared drives)', 'dashboard_refresh', 'shared-utilities/dashboard_functions.sh scan-extended', '0 */1 * * *', 0),
('security_login_scan', 'Daily login activity security scan', 'security_scan', 'shared-utilities/security_reports.sh scan-logins 1', '0 6 * * *', 0),
('security_compliance_scan', 'Weekly security compliance check', 'security_scan', 'shared-utilities/security_reports.sh scan-compliance', '0 7 * * 1', 0),
('security_oauth_scan', 'Daily OAuth applications risk assessment', 'security_scan', 'shared-utilities/security_reports.sh scan-oauth', '0 8 * * *', 0),
('cleanup_old_logs', 'Clean up old log files and temporary data', 'cleanup', 'find ./logs -name "*.log" -mtime +30 -delete', '0 2 * * *', 0),
('cleanup_temp_files', 'Clean up temporary files older than 7 days', 'cleanup', 'find ./tmp -type f -mtime +7 -delete', '0 3 * * *', 0),
('backup_database', 'Create daily database backup', 'backup_operation', 'sqlite3 ./config/gwombat.db ".backup ./backups/gwombat_$(date +%Y%m%d).db"', '0 1 * * *', 0);

-- Insert default user preferences (global settings)
INSERT OR IGNORE INTO user_preferences (preference_category, preference_key, preference_value, user_email, description) VALUES
('scheduling', 'opt_out_all_tasks', 'false', NULL, 'Global opt-out from all scheduled tasks'),
('scheduling', 'opt_out_dashboard_refresh', 'false', NULL, 'Opt-out from automatic dashboard refreshes'),
('scheduling', 'opt_out_security_scans', 'false', NULL, 'Opt-out from automatic security scans'),
('scheduling', 'opt_out_backup_operations', 'false', NULL, 'Opt-out from automatic backup operations'),
('scheduling', 'opt_out_cleanup_tasks', 'false', NULL, 'Opt-out from automatic cleanup tasks'),
('notifications', 'email_alerts_enabled', 'false', NULL, 'Enable email notifications for alerts'),
('notifications', 'console_alerts_enabled', 'true', NULL, 'Show alerts in console output'),
('dashboard', 'auto_refresh_consent', 'false', NULL, 'User has consented to automatic dashboard refresh');

-- Triggers for audit logging
CREATE TRIGGER IF NOT EXISTS config_change_audit
AFTER UPDATE ON gwombat_config
FOR EACH ROW
BEGIN
    INSERT INTO config_audit_log (config_section, config_key, old_value, new_value, change_timestamp)
    VALUES (NEW.config_section, NEW.config_key, OLD.config_value, NEW.config_value, CURRENT_TIMESTAMP);
END;

-- Trigger to update task next_run time based on schedule_pattern
CREATE TRIGGER IF NOT EXISTS update_task_schedule
AFTER UPDATE OF schedule_pattern ON scheduled_tasks
FOR EACH ROW
WHEN NEW.is_enabled = 1
BEGIN
    -- This is a simplified trigger. In practice, you'd want a more sophisticated cron parser
    UPDATE scheduled_tasks 
    SET next_run = datetime('now', '+' || 
        CASE 
            WHEN NEW.schedule_pattern LIKE '*/5 * * * *' THEN '5 minutes'
            WHEN NEW.schedule_pattern LIKE '*/15 * * * *' THEN '15 minutes'
            WHEN NEW.schedule_pattern LIKE '*/30 * * * *' THEN '30 minutes'
            WHEN NEW.schedule_pattern LIKE '0 */1 * * *' THEN '1 hour'
            WHEN NEW.schedule_pattern LIKE '0 */6 * * *' THEN '6 hours'
            WHEN NEW.schedule_pattern LIKE '0 */12 * * *' THEN '12 hours'
            WHEN NEW.schedule_pattern LIKE '0 6 * * *' THEN '1 day'
            WHEN NEW.schedule_pattern LIKE '0 7 * * 1' THEN '7 days'
            ELSE '1 hour'
        END
    )
    WHERE id = NEW.id;
END;