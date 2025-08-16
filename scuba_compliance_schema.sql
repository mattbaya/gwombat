-- SCuBA Compliance Module Schema for GWOMBAT
-- Based on CISA's Secure Cloud Business Applications (SCuBA) Security Baselines
-- Supports 9 Google Workspace services with configurable enable/disable controls

-- Main compliance baselines definition
CREATE TABLE IF NOT EXISTS scuba_baselines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_name TEXT NOT NULL, -- 'gmail', 'calendar', 'drive', 'meet', 'chat', 'groups', 'classroom', 'sites', 'common_controls'
    baseline_id TEXT NOT NULL, -- e.g., 'GWS.GMAIL.1.1v1', 'GWS.CALENDAR.2.1v1'
    baseline_title TEXT NOT NULL,
    baseline_description TEXT NOT NULL,
    requirement_text TEXT NOT NULL, -- The actual CISA requirement
    criticality_level TEXT DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    compliance_check_type TEXT NOT NULL, -- 'configuration', 'audit_log', 'api_check', 'manual'
    gam_command TEXT, -- GAM command to check this baseline (if applicable)
    api_endpoint TEXT, -- Google API endpoint to check (if applicable)
    expected_value TEXT, -- Expected configuration value for compliance
    check_logic TEXT, -- Logic for determining compliance (JSON)
    remediation_steps TEXT, -- Step-by-step remediation guidance
    reference_links TEXT, -- JSON array of relevant documentation links
    is_enabled INTEGER DEFAULT 0, -- 0 = disabled by default (opt-in), 1 = enabled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Compliance assessment results
CREATE TABLE IF NOT EXISTS scuba_compliance_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    baseline_id TEXT NOT NULL,
    assessment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    compliance_status TEXT NOT NULL, -- 'compliant', 'non_compliant', 'not_applicable', 'unable_to_check', 'manual_review'
    confidence_level TEXT DEFAULT 'medium', -- 'low', 'medium', 'high' - confidence in the assessment
    current_value TEXT, -- Current configuration value found
    expected_value TEXT, -- Expected value for compliance
    gap_description TEXT, -- Description of the compliance gap
    risk_level TEXT DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    evidence_data TEXT, -- JSON with detailed evidence (logs, API responses, etc.)
    check_method TEXT, -- How this was checked ('gam_command', 'api_call', 'log_analysis', 'manual')
    session_id TEXT,
    FOREIGN KEY (baseline_id) REFERENCES scuba_baselines(baseline_id)
);

-- Service-specific compliance summaries
CREATE TABLE IF NOT EXISTS scuba_service_compliance (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    service_name TEXT NOT NULL,
    assessment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_baselines INTEGER DEFAULT 0,
    compliant_count INTEGER DEFAULT 0,
    non_compliant_count INTEGER DEFAULT 0,
    not_applicable_count INTEGER DEFAULT 0,
    unable_to_check_count INTEGER DEFAULT 0,
    manual_review_count INTEGER DEFAULT 0,
    compliance_percentage REAL DEFAULT 0.0,
    risk_score INTEGER DEFAULT 0, -- 0-100 overall risk score for this service
    session_id TEXT
);

-- Overall compliance dashboard metrics
CREATE TABLE IF NOT EXISTS scuba_dashboard_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metric_name TEXT NOT NULL,
    metric_value TEXT NOT NULL,
    metric_type TEXT DEFAULT 'percentage', -- 'percentage', 'count', 'score', 'status'
    service_name TEXT, -- NULL for overall metrics
    calculation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT
);

-- Compliance gaps and remediation tracking
CREATE TABLE IF NOT EXISTS scuba_remediation_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    baseline_id TEXT NOT NULL,
    gap_title TEXT NOT NULL,
    gap_description TEXT,
    remediation_priority TEXT DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    remediation_effort TEXT DEFAULT 'medium', -- 'low', 'medium', 'high' - effort required
    remediation_steps TEXT, -- JSON array of step-by-step instructions
    business_impact TEXT, -- Description of business impact if not remediated
    technical_details TEXT, -- Technical implementation details
    assigned_to TEXT, -- Who should handle this remediation
    status TEXT DEFAULT 'open', -- 'open', 'in_progress', 'completed', 'risk_accepted', 'not_applicable'
    target_date DATE,
    completed_date DATE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (baseline_id) REFERENCES scuba_baselines(baseline_id)
);

-- Compliance assessment history
CREATE TABLE IF NOT EXISTS scuba_assessment_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    assessment_id TEXT UNIQUE NOT NULL,
    assessment_name TEXT,
    assessment_type TEXT DEFAULT 'full', -- 'full', 'partial', 'service_specific', 'baseline_specific'
    services_assessed TEXT, -- JSON array of services included
    baselines_assessed INTEGER DEFAULT 0,
    overall_compliance_percentage REAL DEFAULT 0.0,
    critical_findings INTEGER DEFAULT 0,
    high_findings INTEGER DEFAULT 0,
    medium_findings INTEGER DEFAULT 0,
    low_findings INTEGER DEFAULT 0,
    assessment_duration_seconds INTEGER,
    started_by TEXT,
    assessment_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assessment_end TIMESTAMP,
    session_id TEXT
);

-- Configuration for enabling/disabling compliance features
CREATE TABLE IF NOT EXISTS scuba_feature_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feature_category TEXT NOT NULL, -- 'service', 'baseline_type', 'assessment_type'
    feature_name TEXT NOT NULL,
    is_enabled INTEGER DEFAULT 0, -- 0 = disabled by default
    description TEXT,
    requires_gam7 INTEGER DEFAULT 0, -- 1 if this feature requires GAM7
    requires_api_access INTEGER DEFAULT 0, -- 1 if this feature requires specific API access
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_by TEXT,
    UNIQUE(feature_category, feature_name)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scuba_baselines_service ON scuba_baselines(service_name);
CREATE INDEX IF NOT EXISTS idx_scuba_baselines_enabled ON scuba_baselines(is_enabled);
CREATE INDEX IF NOT EXISTS idx_scuba_baselines_criticality ON scuba_baselines(criticality_level);
CREATE INDEX IF NOT EXISTS idx_scuba_compliance_results_baseline ON scuba_compliance_results(baseline_id);
CREATE INDEX IF NOT EXISTS idx_scuba_compliance_results_status ON scuba_compliance_results(compliance_status);
CREATE INDEX IF NOT EXISTS idx_scuba_compliance_results_date ON scuba_compliance_results(assessment_date);
CREATE INDEX IF NOT EXISTS idx_scuba_service_compliance_service ON scuba_service_compliance(service_name);
CREATE INDEX IF NOT EXISTS idx_scuba_service_compliance_date ON scuba_service_compliance(assessment_date);
CREATE INDEX IF NOT EXISTS idx_scuba_remediation_status ON scuba_remediation_items(status);
CREATE INDEX IF NOT EXISTS idx_scuba_remediation_priority ON scuba_remediation_items(remediation_priority);
CREATE INDEX IF NOT EXISTS idx_scuba_assessment_history_date ON scuba_assessment_history(assessment_start);
CREATE INDEX IF NOT EXISTS idx_scuba_feature_config_enabled ON scuba_feature_config(is_enabled);

-- Views for compliance reporting
CREATE VIEW IF NOT EXISTS scuba_compliance_overview AS
SELECT 
    service_name,
    COUNT(*) as total_baselines,
    SUM(CASE WHEN is_enabled = 1 THEN 1 ELSE 0 END) as enabled_baselines,
    SUM(CASE WHEN is_enabled = 1 AND criticality_level = 'critical' THEN 1 ELSE 0 END) as critical_enabled,
    SUM(CASE WHEN is_enabled = 1 AND criticality_level = 'high' THEN 1 ELSE 0 END) as high_enabled,
    SUM(CASE WHEN is_enabled = 1 AND criticality_level = 'medium' THEN 1 ELSE 0 END) as medium_enabled,
    SUM(CASE WHEN is_enabled = 1 AND criticality_level = 'low' THEN 1 ELSE 0 END) as low_enabled
FROM scuba_baselines 
GROUP BY service_name
ORDER BY service_name;

CREATE VIEW IF NOT EXISTS scuba_latest_compliance AS
SELECT 
    b.service_name,
    b.baseline_id,
    b.baseline_title,
    b.criticality_level,
    r.compliance_status,
    r.confidence_level,
    r.risk_level,
    r.gap_description,
    r.assessment_date
FROM scuba_baselines b
LEFT JOIN scuba_compliance_results r ON b.baseline_id = r.baseline_id
LEFT JOIN (
    SELECT baseline_id, MAX(assessment_date) as latest_date
    FROM scuba_compliance_results 
    GROUP BY baseline_id
) latest ON r.baseline_id = latest.baseline_id AND r.assessment_date = latest.latest_date
WHERE b.is_enabled = 1
ORDER BY b.service_name, b.criticality_level DESC, b.baseline_id;

CREATE VIEW IF NOT EXISTS scuba_compliance_summary AS
SELECT 
    'Overall Compliance' as category,
    ROUND(
        (SUM(CASE WHEN compliance_status = 'compliant' THEN 1.0 ELSE 0.0 END) / 
         COUNT(*)) * 100.0, 1
    ) as percentage,
    COUNT(*) as total_assessed,
    SUM(CASE WHEN compliance_status = 'compliant' THEN 1 ELSE 0 END) as compliant,
    SUM(CASE WHEN compliance_status = 'non_compliant' THEN 1 ELSE 0 END) as non_compliant,
    MAX(assessment_date) as last_updated
FROM scuba_latest_compliance
WHERE compliance_status IS NOT NULL
UNION ALL
SELECT 
    'Critical Baselines' as category,
    ROUND(
        (SUM(CASE WHEN compliance_status = 'compliant' AND criticality_level = 'critical' THEN 1.0 ELSE 0.0 END) / 
         NULLIF(SUM(CASE WHEN criticality_level = 'critical' THEN 1 ELSE 0 END), 0)) * 100.0, 1
    ) as percentage,
    SUM(CASE WHEN criticality_level = 'critical' THEN 1 ELSE 0 END) as total_assessed,
    SUM(CASE WHEN compliance_status = 'compliant' AND criticality_level = 'critical' THEN 1 ELSE 0 END) as compliant,
    SUM(CASE WHEN compliance_status = 'non_compliant' AND criticality_level = 'critical' THEN 1 ELSE 0 END) as non_compliant,
    MAX(assessment_date) as last_updated
FROM scuba_latest_compliance
WHERE compliance_status IS NOT NULL
UNION ALL
SELECT 
    'High Priority Baselines' as category,
    ROUND(
        (SUM(CASE WHEN compliance_status = 'compliant' AND criticality_level = 'high' THEN 1.0 ELSE 0.0 END) / 
         NULLIF(SUM(CASE WHEN criticality_level = 'high' THEN 1 ELSE 0 END), 0)) * 100.0, 1
    ) as percentage,
    SUM(CASE WHEN criticality_level = 'high' THEN 1 ELSE 0 END) as total_assessed,
    SUM(CASE WHEN compliance_status = 'compliant' AND criticality_level = 'high' THEN 1 ELSE 0 END) as compliant,
    SUM(CASE WHEN compliance_status = 'non_compliant' AND criticality_level = 'high' THEN 1 ELSE 0 END) as non_compliant,
    MAX(assessment_date) as last_updated
FROM scuba_latest_compliance
WHERE compliance_status IS NOT NULL;

CREATE VIEW IF NOT EXISTS scuba_remediation_dashboard AS
SELECT 
    remediation_priority,
    status,
    COUNT(*) as item_count,
    COUNT(CASE WHEN target_date < date('now') AND status NOT IN ('completed', 'risk_accepted') THEN 1 END) as overdue_count,
    COUNT(CASE WHEN target_date BETWEEN date('now') AND date('now', '+7 days') AND status NOT IN ('completed', 'risk_accepted') THEN 1 END) as due_soon_count
FROM scuba_remediation_items
GROUP BY remediation_priority, status
ORDER BY 
    CASE remediation_priority 
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    CASE status
        WHEN 'open' THEN 1
        WHEN 'in_progress' THEN 2
        WHEN 'completed' THEN 3
        WHEN 'risk_accepted' THEN 4
        WHEN 'not_applicable' THEN 5
    END;

-- Insert default SCuBA baseline feature configurations (all disabled by default)
INSERT OR IGNORE INTO scuba_feature_config (feature_category, feature_name, is_enabled, description, requires_gam7) VALUES 
-- Service-level enablement
('service', 'gmail', 0, 'Enable Gmail security baseline assessments', 1),
('service', 'calendar', 0, 'Enable Calendar security baseline assessments', 1),
('service', 'drive', 0, 'Enable Drive & Docs security baseline assessments', 1),
('service', 'meet', 0, 'Enable Google Meet security baseline assessments', 1),
('service', 'chat', 0, 'Enable Google Chat security baseline assessments', 1),
('service', 'groups', 0, 'Enable Groups for Business security baseline assessments', 1),
('service', 'classroom', 0, 'Enable Google Classroom security baseline assessments', 1),
('service', 'sites', 0, 'Enable Google Sites security baseline assessments', 1),
('service', 'common_controls', 0, 'Enable Common Controls security baseline assessments', 1),

-- Assessment type enablement
('assessment_type', 'automated_checks', 0, 'Enable automated compliance checking', 1),
('assessment_type', 'manual_review_items', 0, 'Include manual review items in assessments', 0),
('assessment_type', 'audit_log_analysis', 0, 'Enable audit log-based compliance checks', 1),
('assessment_type', 'api_configuration_checks', 0, 'Enable API-based configuration assessments', 1),

-- Baseline criticality level enablement
('baseline_type', 'critical_only', 0, 'Assess only critical severity baselines', 1),
('baseline_type', 'high_and_critical', 0, 'Assess high and critical severity baselines', 1),
('baseline_type', 'all_severities', 0, 'Assess all baseline severities', 1),

-- Reporting and remediation features
('feature', 'compliance_dashboard', 0, 'Enable SCuBA compliance dashboard', 0),
('feature', 'gap_analysis_reports', 0, 'Enable detailed gap analysis reporting', 0),
('feature', 'remediation_tracking', 0, 'Enable remediation item tracking and management', 0),
('feature', 'executive_reporting', 0, 'Enable executive-level compliance summaries', 0),
('feature', 'scheduled_assessments', 0, 'Enable scheduled automated compliance assessments', 1),
('feature', 'compliance_alerts', 0, 'Enable compliance status change alerts', 0);

-- Insert sample SCuBA baselines (subset of actual CISA baselines for demonstration)
-- Note: In production, these would be populated from the official CISA SCuBA baselines

-- Gmail Baselines
INSERT OR IGNORE INTO scuba_baselines (service_name, baseline_id, baseline_title, baseline_description, requirement_text, criticality_level, compliance_check_type, gam_command, expected_value, remediation_steps) VALUES 
('gmail', 'GWS.GMAIL.1.1v1', 'External Recipient Warning', 'Users SHALL be warned when sending emails to external recipients', 'The organization SHALL configure Gmail to warn users when sending emails to recipients outside the organization domain', 'high', 'configuration', 'gam print domains fields primaryDomainName:json | jq -r .[]', 'true', 'Configure external recipient warning in Gmail settings'),
('gmail', 'GWS.GMAIL.2.1v1', 'Email Forwarding Restrictions', 'Email forwarding to external addresses SHALL be restricted', 'Organizations SHALL restrict users from automatically forwarding emails to external addresses', 'critical', 'configuration', 'gam info domain | grep -i forwarding', 'restricted', 'Disable or restrict email forwarding in Gmail settings'),
('gmail', 'GWS.GMAIL.3.1v1', 'Attachment Scanning', 'Email attachments SHALL be scanned for malware', 'All email attachments SHALL be automatically scanned for malware and malicious content', 'high', 'configuration', 'gam info domain | grep -i "attachment.*scan"', 'enabled', 'Enable attachment scanning in Gmail security settings'),

-- Calendar Baselines  
('calendar', 'GWS.CALENDAR.1.1v1', 'External Sharing Controls', 'Calendar sharing with external users SHALL be controlled', 'The organization SHALL control and restrict calendar sharing with users outside the organization', 'medium', 'configuration', 'gam info domain | grep -i "calendar.*sharing"', 'restricted', 'Configure external calendar sharing restrictions'),
('calendar', 'GWS.CALENDAR.2.1v1', 'Resource Booking Controls', 'Resource booking SHALL require approval', 'Calendar resource booking SHALL require appropriate approval mechanisms', 'low', 'configuration', 'gam print resources | grep -i approval', 'required', 'Enable approval requirements for resource booking'),

-- Drive Baselines
('drive', 'GWS.DRIVE.1.1v1', 'External Link Sharing', 'Link sharing with external users SHALL be restricted', 'The organization SHALL restrict the ability to share Drive files via public links', 'critical', 'configuration', 'gam info domain | grep -i "drive.*sharing"', 'restricted', 'Restrict external link sharing in Drive settings'),
('drive', 'GWS.DRIVE.2.1v1', 'File Access Audit', 'File access SHALL be audited and logged', 'All file access activities SHALL be logged for security monitoring and audit purposes', 'high', 'audit_log', 'gam report drive | head -10', 'enabled', 'Enable Drive audit logging'),

-- Common Controls Baselines
('common_controls', 'GWS.COMMON.1.1v1', '2-Step Verification', '2-Step Verification SHALL be enforced', 'All users SHALL have 2-Step Verification (2SV) enforced on their accounts', 'critical', 'configuration', 'gam print users fields isEnforcedIn2Sv | grep -c True', '>90%', 'Enforce 2-Step Verification for all users'),
('common_controls', 'GWS.COMMON.2.1v1', 'Admin Account Security', 'Admin accounts SHALL have enhanced security', 'Administrator accounts SHALL have additional security controls and monitoring', 'critical', 'configuration', 'gam print admins | wc -l', 'monitored', 'Implement enhanced security for admin accounts'),

-- Groups Baselines
('groups', 'GWS.GROUPS.1.1v1', 'External Group Membership', 'External users SHALL NOT be added to internal groups', 'Groups containing internal organizational data SHALL NOT include external members', 'high', 'configuration', 'gam print groups | grep -i external', 'none', 'Remove external members from internal groups'),

-- Meet Baselines
('meet', 'GWS.MEET.1.1v1', 'Recording Controls', 'Meeting recordings SHALL be controlled', 'The ability to record meetings SHALL be controlled and restricted as appropriate', 'medium', 'configuration', 'gam info domain | grep -i "meet.*record"', 'restricted', 'Configure meeting recording restrictions'),

-- Chat Baselines  
('chat', 'GWS.CHAT.1.1v1', 'External Chat Restrictions', 'External chat SHALL be restricted', 'Chat with external users SHALL be appropriately restricted', 'medium', 'configuration', 'gam info domain | grep -i "chat.*external"', 'restricted', 'Configure external chat restrictions');

-- Google Workspace API data storage (for Python module integration)
CREATE TABLE IF NOT EXISTS gws_api_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_type TEXT NOT NULL, -- 'domain_info', 'org_structure', '2sv_enforcement', 'security_snapshot', etc.
    data_content TEXT NOT NULL, -- JSON data from API calls
    retrieved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id TEXT,
    expires_at TIMESTAMP, -- For caching purposes
    data_version INTEGER DEFAULT 1
);

-- Index for API data
CREATE INDEX IF NOT EXISTS idx_gws_api_data_type ON gws_api_data(data_type);
CREATE INDEX IF NOT EXISTS idx_gws_api_data_retrieved ON gws_api_data(retrieved_at);
CREATE INDEX IF NOT EXISTS idx_gws_api_data_expires ON gws_api_data(expires_at);

-- Triggers for maintaining data consistency
CREATE TRIGGER IF NOT EXISTS update_baseline_timestamp
AFTER UPDATE ON scuba_baselines
FOR EACH ROW
BEGIN
    UPDATE scuba_baselines 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS update_remediation_timestamp
AFTER UPDATE ON scuba_remediation_items
FOR EACH ROW
BEGIN
    UPDATE scuba_remediation_items 
    SET updated_at = CURRENT_TIMESTAMP 
    WHERE id = NEW.id;
END;