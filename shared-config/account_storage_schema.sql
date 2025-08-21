-- Account Storage Size Tracking Schema
-- Tracks account storage sizes with historical data and retention policies

-- Main storage measurements table
CREATE TABLE IF NOT EXISTS account_storage_sizes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    display_name TEXT,
    storage_used_bytes INTEGER NOT NULL,
    storage_used_gb REAL NOT NULL,
    storage_quota_bytes INTEGER,
    storage_quota_gb REAL,
    usage_percentage REAL,
    measurement_date DATE NOT NULL,
    measurement_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    scan_session_id TEXT,
    notes TEXT,
    UNIQUE(email, measurement_date)
);

-- Storage size history with aggregation types
CREATE TABLE IF NOT EXISTS storage_size_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    display_name TEXT,
    storage_used_bytes INTEGER NOT NULL,
    storage_used_gb REAL NOT NULL,
    storage_quota_bytes INTEGER,
    storage_quota_gb REAL,
    usage_percentage REAL,
    measurement_date DATE NOT NULL,
    measurement_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aggregation_type TEXT NOT NULL CHECK(aggregation_type IN ('daily', 'weekly', 'monthly')),
    scan_session_id TEXT,
    retained_until DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Storage change analysis table
CREATE TABLE IF NOT EXISTS storage_change_analysis (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    display_name TEXT,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    start_size_gb REAL NOT NULL,
    end_size_gb REAL NOT NULL,
    size_change_gb REAL NOT NULL,
    percentage_change REAL,
    change_type TEXT CHECK(change_type IN ('increase', 'decrease', 'stable')),
    analysis_period TEXT CHECK(analysis_period IN ('daily', 'weekly', 'monthly')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(email, period_start, period_end, analysis_period)
);

-- Storage alerts and thresholds
CREATE TABLE IF NOT EXISTS storage_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    alert_type TEXT NOT NULL CHECK(alert_type IN ('quota_exceeded', 'rapid_growth', 'large_account', 'custom')),
    threshold_value REAL,
    current_value REAL,
    alert_message TEXT,
    severity TEXT CHECK(severity IN ('low', 'medium', 'high', 'critical')),
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMP,
    acknowledged_by TEXT
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_storage_sizes_email ON account_storage_sizes(email);
CREATE INDEX IF NOT EXISTS idx_storage_sizes_date ON account_storage_sizes(measurement_date);
CREATE INDEX IF NOT EXISTS idx_storage_sizes_size ON account_storage_sizes(storage_used_gb);
CREATE INDEX IF NOT EXISTS idx_storage_history_email_date ON storage_size_history(email, measurement_date);
CREATE INDEX IF NOT EXISTS idx_storage_history_aggregation ON storage_size_history(aggregation_type, measurement_date);
CREATE INDEX IF NOT EXISTS idx_storage_change_email ON storage_change_analysis(email);
CREATE INDEX IF NOT EXISTS idx_storage_change_period ON storage_change_analysis(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_storage_alerts_email ON storage_alerts(email);
CREATE INDEX IF NOT EXISTS idx_storage_alerts_triggered ON storage_alerts(triggered_at);

-- Views for common queries
CREATE VIEW IF NOT EXISTS latest_account_sizes AS
SELECT 
    email,
    display_name,
    storage_used_gb,
    storage_quota_gb,
    usage_percentage,
    measurement_date,
    measurement_timestamp,
    CASE 
        WHEN usage_percentage >= 95 THEN 'Critical'
        WHEN usage_percentage >= 85 THEN 'High'
        WHEN usage_percentage >= 70 THEN 'Medium'
        ELSE 'Normal'
    END as usage_status
FROM account_storage_sizes ass1
WHERE measurement_date = (
    SELECT MAX(measurement_date) 
    FROM account_storage_sizes ass2 
    WHERE ass2.email = ass1.email
)
ORDER BY storage_used_gb DESC;

-- View for size change trends
CREATE VIEW IF NOT EXISTS storage_size_trends AS
SELECT 
    sca.email,
    sca.display_name,
    sca.analysis_period,
    AVG(sca.size_change_gb) as avg_change_gb,
    MAX(sca.size_change_gb) as max_change_gb,
    MIN(sca.size_change_gb) as min_change_gb,
    COUNT(*) as measurement_count,
    MAX(sca.period_end) as latest_measurement
FROM storage_change_analysis sca
GROUP BY sca.email, sca.analysis_period
ORDER BY avg_change_gb DESC;

-- View for top storage users
CREATE VIEW IF NOT EXISTS top_storage_users AS
SELECT 
    las.email,
    las.display_name,
    las.storage_used_gb,
    las.storage_quota_gb,
    las.usage_percentage,
    las.usage_status,
    las.measurement_date,
    RANK() OVER (ORDER BY las.storage_used_gb DESC) as size_rank,
    RANK() OVER (ORDER BY las.usage_percentage DESC) as usage_rank
FROM latest_account_sizes las
ORDER BY las.storage_used_gb DESC;

-- View for accounts with rapid growth
CREATE VIEW IF NOT EXISTS rapid_growth_accounts AS
SELECT 
    sca.email,
    sca.display_name,
    sca.size_change_gb,
    sca.percentage_change,
    sca.period_start,
    sca.period_end,
    sca.analysis_period,
    las.storage_used_gb as current_size_gb,
    las.usage_percentage as current_usage_pct
FROM storage_change_analysis sca
JOIN latest_account_sizes las ON sca.email = las.email
WHERE sca.size_change_gb > 1.0  -- More than 1GB growth
   OR sca.percentage_change > 25  -- More than 25% growth
ORDER BY sca.size_change_gb DESC;

-- View for storage alerts summary
CREATE VIEW IF NOT EXISTS storage_alerts_summary AS
SELECT 
    alert_type,
    severity,
    COUNT(*) as alert_count,
    COUNT(CASE WHEN acknowledged = FALSE THEN 1 END) as unacknowledged_count,
    MAX(triggered_at) as latest_alert
FROM storage_alerts
GROUP BY alert_type, severity
ORDER BY 
    CASE severity 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    alert_count DESC;

-- Trigger to automatically create change analysis when new measurements are added
CREATE TRIGGER IF NOT EXISTS calculate_storage_changes
AFTER INSERT ON account_storage_sizes
BEGIN
    -- Calculate daily change if there's a previous measurement
    INSERT OR REPLACE INTO storage_change_analysis (
        email, display_name, period_start, period_end, 
        start_size_gb, end_size_gb, size_change_gb, percentage_change, 
        change_type, analysis_period
    )
    SELECT 
        NEW.email,
        NEW.display_name,
        prev.measurement_date as period_start,
        NEW.measurement_date as period_end,
        prev.storage_used_gb as start_size_gb,
        NEW.storage_used_gb as end_size_gb,
        (NEW.storage_used_gb - prev.storage_used_gb) as size_change_gb,
        CASE 
            WHEN prev.storage_used_gb > 0 THEN 
                ((NEW.storage_used_gb - prev.storage_used_gb) / prev.storage_used_gb) * 100
            ELSE 0
        END as percentage_change,
        CASE 
            WHEN NEW.storage_used_gb > prev.storage_used_gb THEN 'increase'
            WHEN NEW.storage_used_gb < prev.storage_used_gb THEN 'decrease'
            ELSE 'stable'
        END as change_type,
        'daily' as analysis_period
    FROM account_storage_sizes prev
    WHERE prev.email = NEW.email
      AND prev.measurement_date = (
          SELECT MAX(measurement_date) 
          FROM account_storage_sizes 
          WHERE email = NEW.email 
            AND measurement_date < NEW.measurement_date
      );
END;

-- Configuration for retention policies
INSERT OR IGNORE INTO config (key, value) VALUES 
('storage_retention_daily_days', '7'),
('storage_retention_weekly_weeks', '4'), 
('storage_retention_monthly_months', '12'),
('storage_alert_quota_threshold', '85'),
('storage_alert_growth_threshold_gb', '2.0'),
('storage_alert_growth_threshold_pct', '50');