-- Enhanced Security Reports Schema for GWOMBAT
-- Leverages GAM7 advanced security capabilities for comprehensive monitoring

-- Login activity tracking
CREATE TABLE IF NOT EXISTS login_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    login_time TIMESTAMP,
    login_type TEXT, -- 'successful', 'failed', 'suspicious'
    ip_address TEXT,
    user_agent TEXT,
    device_id TEXT,
    device_type TEXT, -- 'desktop', 'mobile', 'unknown'
    location_country TEXT,
    location_city TEXT,
    is_suspicious INTEGER DEFAULT 0,
    risk_score INTEGER DEFAULT 0, -- 0-100 risk assessment
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Admin activity monitoring
CREATE TABLE IF NOT EXISTS admin_activities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    admin_email TEXT NOT NULL,
    activity_time TIMESTAMP,
    activity_type TEXT, -- 'user_create', 'user_suspend', 'settings_change', 'privilege_grant', etc.
    target_user TEXT,
    target_resource TEXT,
    action_details TEXT, -- JSON with detailed action info
    privilege_level TEXT, -- 'super_admin', 'admin', 'delegated_admin'
    ip_address TEXT,
    user_agent TEXT,
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Security compliance tracking
CREATE TABLE IF NOT EXISTS security_compliance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    compliance_type TEXT, -- '2fa', 'password_policy', 'account_security', 'oauth_apps'
    compliance_status TEXT, -- 'compliant', 'non_compliant', 'warning', 'unknown'
    compliance_score INTEGER DEFAULT 0, -- 0-100 compliance score
    issue_details TEXT, -- JSON with specific compliance issues
    last_password_change TIMESTAMP,
    two_factor_enabled INTEGER DEFAULT 0,
    recovery_info_set INTEGER DEFAULT 0,
    oauth_apps_count INTEGER DEFAULT 0,
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'current' CHECK(status IN ('current', 'historical'))
);

-- OAuth applications audit
CREATE TABLE IF NOT EXISTS oauth_applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id TEXT NOT NULL,
    app_name TEXT,
    app_type TEXT, -- 'web', 'installed', 'service_account'
    client_id TEXT,
    scopes TEXT, -- JSON array of granted scopes
    users_granted INTEGER DEFAULT 0,
    high_risk_scopes INTEGER DEFAULT 0, -- Count of high-risk scopes
    creation_date TIMESTAMP,
    last_used TIMESTAMP,
    risk_level TEXT DEFAULT 'low', -- 'low', 'medium', 'high', 'critical'
    is_internal INTEGER DEFAULT 0, -- 1 if developed internally
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- OAuth user grants
CREATE TABLE IF NOT EXISTS oauth_user_grants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    app_id TEXT NOT NULL,
    app_name TEXT,
    scopes_granted TEXT, -- JSON array of scopes
    grant_time TIMESTAMP,
    last_access TIMESTAMP,
    access_count INTEGER DEFAULT 0,
    is_high_risk INTEGER DEFAULT 0,
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (app_id) REFERENCES oauth_applications(app_id)
);

-- Security alerts and incidents
CREATE TABLE IF NOT EXISTS security_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_type TEXT NOT NULL, -- 'failed_login', 'suspicious_activity', 'compliance_violation', 'admin_action'
    severity TEXT NOT NULL CHECK(severity IN ('low', 'medium', 'high', 'critical')),
    user_email TEXT,
    admin_email TEXT,
    title TEXT NOT NULL,
    description TEXT,
    details TEXT, -- JSON with detailed alert information
    detection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged INTEGER DEFAULT 0,
    acknowledged_by TEXT,
    acknowledged_at TIMESTAMP,
    resolved INTEGER DEFAULT 0,
    resolved_by TEXT,
    resolved_at TIMESTAMP,
    false_positive INTEGER DEFAULT 0,
    session_id TEXT
);

-- Failed login attempts tracking
CREATE TABLE IF NOT EXISTS failed_logins (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    attempt_time TIMESTAMP,
    ip_address TEXT,
    user_agent TEXT,
    failure_reason TEXT,
    location_country TEXT,
    location_city TEXT,
    consecutive_failures INTEGER DEFAULT 1,
    account_locked INTEGER DEFAULT 0,
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Device tracking for security analysis
CREATE TABLE IF NOT EXISTS user_devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_email TEXT NOT NULL,
    device_id TEXT,
    device_name TEXT,
    device_type TEXT, -- 'desktop', 'mobile', 'tablet', 'unknown'
    platform TEXT, -- 'Windows', 'Mac', 'iOS', 'Android', etc.
    browser TEXT,
    first_seen TIMESTAMP,
    last_seen TIMESTAMP,
    access_count INTEGER DEFAULT 1,
    is_trusted INTEGER DEFAULT 0,
    is_suspicious INTEGER DEFAULT 0,
    location_pattern TEXT, -- JSON with location access patterns
    session_id TEXT,
    scan_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Security health metrics
CREATE TABLE IF NOT EXISTS security_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value INTEGER NOT NULL,
    metric_percentage REAL,
    metric_category TEXT, -- 'authentication', 'compliance', 'access', 'admin'
    total_users INTEGER,
    calculation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    status TEXT DEFAULT 'current' CHECK(status IN ('current', 'historical'))
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_login_activities_user ON login_activities(user_email);
CREATE INDEX IF NOT EXISTS idx_login_activities_time ON login_activities(login_time);
CREATE INDEX IF NOT EXISTS idx_login_activities_type ON login_activities(login_type);
CREATE INDEX IF NOT EXISTS idx_login_activities_suspicious ON login_activities(is_suspicious);

CREATE INDEX IF NOT EXISTS idx_admin_activities_admin ON admin_activities(admin_email);
CREATE INDEX IF NOT EXISTS idx_admin_activities_time ON admin_activities(activity_time);
CREATE INDEX IF NOT EXISTS idx_admin_activities_type ON admin_activities(activity_type);

CREATE INDEX IF NOT EXISTS idx_security_compliance_user ON security_compliance(user_email);
CREATE INDEX IF NOT EXISTS idx_security_compliance_type ON security_compliance(compliance_type);
CREATE INDEX IF NOT EXISTS idx_security_compliance_status ON security_compliance(compliance_status);

CREATE INDEX IF NOT EXISTS idx_oauth_applications_risk ON oauth_applications(risk_level);
CREATE INDEX IF NOT EXISTS idx_oauth_applications_type ON oauth_applications(app_type);

CREATE INDEX IF NOT EXISTS idx_oauth_user_grants_user ON oauth_user_grants(user_email);
CREATE INDEX IF NOT EXISTS idx_oauth_user_grants_app ON oauth_user_grants(app_id);
CREATE INDEX IF NOT EXISTS idx_oauth_user_grants_risk ON oauth_user_grants(is_high_risk);

CREATE INDEX IF NOT EXISTS idx_security_alerts_type ON security_alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_security_alerts_severity ON security_alerts(severity);
CREATE INDEX IF NOT EXISTS idx_security_alerts_time ON security_alerts(detection_time);
CREATE INDEX IF NOT EXISTS idx_security_alerts_resolved ON security_alerts(resolved);

CREATE INDEX IF NOT EXISTS idx_failed_logins_user ON failed_logins(user_email);
CREATE INDEX IF NOT EXISTS idx_failed_logins_time ON failed_logins(attempt_time);
CREATE INDEX IF NOT EXISTS idx_failed_logins_ip ON failed_logins(ip_address);

CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_email);
CREATE INDEX IF NOT EXISTS idx_user_devices_suspicious ON user_devices(is_suspicious);

CREATE INDEX IF NOT EXISTS idx_security_metrics_name ON security_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_security_metrics_category ON security_metrics(metric_category);
CREATE INDEX IF NOT EXISTS idx_security_metrics_status ON security_metrics(status);

-- Views for security reporting
CREATE VIEW IF NOT EXISTS security_health_summary AS
SELECT 
    metric_category,
    COUNT(*) as metric_count,
    AVG(metric_percentage) as avg_percentage,
    MIN(metric_percentage) as min_percentage,
    MAX(metric_percentage) as max_percentage,
    MAX(calculation_time) as last_updated
FROM security_metrics 
WHERE status = 'current'
GROUP BY metric_category;

CREATE VIEW IF NOT EXISTS recent_security_alerts AS
SELECT 
    alert_type,
    severity,
    COUNT(*) as alert_count,
    MAX(detection_time) as latest_alert,
    SUM(CASE WHEN acknowledged = 0 THEN 1 ELSE 0 END) as unacknowledged_count,
    SUM(CASE WHEN resolved = 0 THEN 1 ELSE 0 END) as unresolved_count
FROM security_alerts 
WHERE detection_time > datetime('now', '-24 hours')
GROUP BY alert_type, severity
ORDER BY severity DESC, alert_count DESC;

CREATE VIEW IF NOT EXISTS compliance_summary AS
SELECT 
    compliance_type,
    compliance_status,
    COUNT(*) as user_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(DISTINCT user_email) FROM security_compliance WHERE status = 'current'), 2) as percentage,
    AVG(compliance_score) as avg_score
FROM security_compliance 
WHERE status = 'current'
GROUP BY compliance_type, compliance_status
ORDER BY compliance_type, compliance_status;

CREATE VIEW IF NOT EXISTS suspicious_activity_summary AS
SELECT 
    'Failed Logins' as activity_type,
    COUNT(*) as incident_count,
    COUNT(DISTINCT user_email) as affected_users,
    MAX(attempt_time) as latest_incident
FROM failed_logins 
WHERE attempt_time > datetime('now', '-24 hours')
UNION ALL
SELECT 
    'Suspicious Logins' as activity_type,
    COUNT(*) as incident_count,
    COUNT(DISTINCT user_email) as affected_users,
    MAX(login_time) as latest_incident
FROM login_activities 
WHERE is_suspicious = 1 AND login_time > datetime('now', '-24 hours')
UNION ALL
SELECT 
    'High Risk OAuth Apps' as activity_type,
    COUNT(*) as incident_count,
    COUNT(DISTINCT user_email) as affected_users,
    MAX(grant_time) as latest_incident
FROM oauth_user_grants 
WHERE is_high_risk = 1 AND grant_time > datetime('now', '-24 hours');

CREATE VIEW IF NOT EXISTS admin_activity_summary AS
SELECT 
    admin_email,
    activity_type,
    COUNT(*) as action_count,
    MAX(activity_time) as latest_action,
    COUNT(DISTINCT target_user) as users_affected
FROM admin_activities 
WHERE activity_time > datetime('now', '-24 hours')
GROUP BY admin_email, activity_type
ORDER BY action_count DESC;

-- Triggers for automatic security alerting
CREATE TRIGGER IF NOT EXISTS failed_login_alert
AFTER INSERT ON failed_logins
WHEN NEW.consecutive_failures >= 5
BEGIN
    INSERT INTO security_alerts (alert_type, severity, user_email, title, description, details)
    VALUES (
        'failed_login', 
        'medium', 
        NEW.user_email, 
        'Multiple Failed Login Attempts',
        'User has ' || NEW.consecutive_failures || ' consecutive failed login attempts',
        json_object(
            'consecutive_failures', NEW.consecutive_failures,
            'ip_address', NEW.ip_address,
            'location', NEW.location_city || ', ' || NEW.location_country,
            'latest_attempt', NEW.attempt_time
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS suspicious_login_alert
AFTER INSERT ON login_activities
WHEN NEW.is_suspicious = 1
BEGIN
    INSERT INTO security_alerts (alert_type, severity, user_email, title, description, details)
    VALUES (
        'suspicious_activity', 
        CASE WHEN NEW.risk_score > 80 THEN 'high' 
             WHEN NEW.risk_score > 60 THEN 'medium' 
             ELSE 'low' END, 
        NEW.user_email, 
        'Suspicious Login Activity',
        'Suspicious login detected with risk score: ' || NEW.risk_score,
        json_object(
            'risk_score', NEW.risk_score,
            'ip_address', NEW.ip_address,
            'location', NEW.location_city || ', ' || NEW.location_country,
            'device_type', NEW.device_type,
            'login_time', NEW.login_time
        )
    );
END;

CREATE TRIGGER IF NOT EXISTS high_risk_oauth_alert
AFTER INSERT ON oauth_user_grants
WHEN NEW.is_high_risk = 1
BEGIN
    INSERT INTO security_alerts (alert_type, severity, user_email, title, description, details)
    VALUES (
        'compliance_violation', 
        'medium', 
        NEW.user_email, 
        'High-Risk OAuth Application Access',
        'User granted access to high-risk OAuth application: ' || NEW.app_name,
        json_object(
            'app_name', NEW.app_name,
            'app_id', NEW.app_id,
            'scopes_granted', NEW.scopes_granted,
            'grant_time', NEW.grant_time
        )
    );
END;

-- Insert default security metrics categories
INSERT OR IGNORE INTO security_metrics (metric_name, metric_value, metric_category, status) VALUES 
('Total Users Scanned', 0, 'overview', 'current'),
('2FA Enabled Users', 0, 'authentication', 'current'),
('Password Policy Compliant', 0, 'authentication', 'current'),
('OAuth Apps Granted', 0, 'access', 'current'),
('Failed Logins (24h)', 0, 'authentication', 'current'),
('Suspicious Activities (24h)', 0, 'access', 'current'),
('Admin Actions (24h)', 0, 'admin', 'current'),
('Security Alerts (24h)', 0, 'overview', 'current');