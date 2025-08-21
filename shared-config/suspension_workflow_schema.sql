-- Configurable Suspension Workflow Schema
-- Allows users to define and customize their organization's suspension lifecycle stages

-- Suspension workflow stages configuration
CREATE TABLE IF NOT EXISTS suspension_stages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stage_name VARCHAR(100) NOT NULL UNIQUE,
    stage_description TEXT,
    stage_order INTEGER NOT NULL UNIQUE,
    days_in_stage INTEGER DEFAULT NULL, -- NULL = indefinite, number = auto-advance after X days
    requires_approval BOOLEAN DEFAULT 0, -- 1 = requires manual approval to advance
    auto_advance_to INTEGER REFERENCES suspension_stages(id), -- Next stage for auto-advancement
    ou_path VARCHAR(500), -- Google Workspace OU path for this stage
    is_active BOOLEAN DEFAULT 1,
    color_code VARCHAR(20) DEFAULT '#808080', -- Color for UI display
    icon VARCHAR(10) DEFAULT '📋', -- Emoji icon for display
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Stage actions/operations that can be performed at each stage
CREATE TABLE IF NOT EXISTS stage_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stage_id INTEGER NOT NULL REFERENCES suspension_stages(id),
    action_name VARCHAR(100) NOT NULL,
    action_description TEXT,
    action_type VARCHAR(50) NOT NULL, -- 'gam_command', 'backup', 'notification', 'custom_script'
    action_command TEXT, -- The actual command or script to run
    is_automatic BOOLEAN DEFAULT 0, -- 1 = runs automatically when user enters stage
    is_required BOOLEAN DEFAULT 0, -- 1 = must be completed before advancing
    action_order INTEGER DEFAULT 1, -- Order of execution within stage
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Stage transitions - defines which stages can transition to which other stages
CREATE TABLE IF NOT EXISTS stage_transitions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    from_stage_id INTEGER NOT NULL REFERENCES suspension_stages(id),
    to_stage_id INTEGER NOT NULL REFERENCES suspension_stages(id),
    transition_name VARCHAR(100), -- e.g., "Advance", "Escalate", "Revert"
    transition_description TEXT,
    requires_reason BOOLEAN DEFAULT 0, -- 1 = requires reason for transition
    notification_required BOOLEAN DEFAULT 0, -- 1 = sends notification on transition
    is_active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(from_stage_id, to_stage_id)
);

-- Account stage history - tracks user progression through stages
CREATE TABLE IF NOT EXISTS account_stage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR(255) NOT NULL,
    stage_id INTEGER NOT NULL REFERENCES suspension_stages(id),
    entered_stage_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    exited_stage_at DATETIME DEFAULT NULL,
    transition_reason TEXT,
    transitioned_by VARCHAR(255), -- Admin who performed the transition
    auto_transitioned BOOLEAN DEFAULT 0, -- 1 = automatic transition, 0 = manual
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Current stage for each account (denormalized for performance)
CREATE TABLE IF NOT EXISTS account_current_stage (
    email VARCHAR(255) PRIMARY KEY,
    stage_id INTEGER NOT NULL REFERENCES suspension_stages(id),
    entered_stage_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    days_in_stage INTEGER GENERATED ALWAYS AS (
        CAST((julianday('now') - julianday(entered_stage_at)) AS INTEGER)
    ) STORED,
    next_review_date DATE, -- Calculated based on stage settings
    is_overdue BOOLEAN GENERATED ALWAYS AS (
        next_review_date IS NOT NULL AND date('now') > next_review_date
    ) STORED,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Stage workflow templates for different organization types
CREATE TABLE IF NOT EXISTS workflow_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_name VARCHAR(100) NOT NULL UNIQUE,
    template_description TEXT,
    organization_type VARCHAR(100), -- 'university', 'k12', 'corporate', 'government'
    is_default BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Link templates to their stages
CREATE TABLE IF NOT EXISTS template_stages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL REFERENCES workflow_templates(id),
    stage_name VARCHAR(100) NOT NULL,
    stage_description TEXT,
    stage_order INTEGER NOT NULL,
    days_in_stage INTEGER DEFAULT NULL,
    ou_path VARCHAR(500),
    requires_approval BOOLEAN DEFAULT 0,
    color_code VARCHAR(20) DEFAULT '#808080',
    icon VARCHAR(10) DEFAULT '📋'
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_account_stage_history_email ON account_stage_history(email);
CREATE INDEX IF NOT EXISTS idx_account_stage_history_stage ON account_stage_history(stage_id);
CREATE INDEX IF NOT EXISTS idx_account_current_stage_stage ON account_current_stage(stage_id);
CREATE INDEX IF NOT EXISTS idx_account_current_stage_overdue ON account_current_stage(is_overdue);
CREATE INDEX IF NOT EXISTS idx_suspension_stages_order ON suspension_stages(stage_order);
CREATE INDEX IF NOT EXISTS idx_stage_actions_stage ON stage_actions(stage_id);

-- Insert default 8-stage workflow as a starting template
INSERT OR IGNORE INTO workflow_templates (id, template_name, template_description, organization_type, is_default)
VALUES (1, 'Standard 8-Stage University Workflow', 'Traditional university suspension lifecycle with 8 defined stages', 'university', 1);

-- Default 8-stage template stages
INSERT OR IGNORE INTO template_stages (template_id, stage_name, stage_description, stage_order, days_in_stage, ou_path, requires_approval, color_code, icon) VALUES
(1, 'Recently Suspended', 'Newly suspended accounts requiring initial processing', 1, 30, '/Suspended Users', 0, '#FFA500', '🔒'),
(1, 'Stage 1 - Initial Review', 'First stage review for recently suspended accounts', 2, 30, '/Suspended Users/Stage 1', 1, '#FF6B6B', '📋'),
(1, 'Stage 2 - Department Contact', 'Contact department for account disposition', 3, 45, '/Suspended Users/Stage 2', 1, '#4ECDC4', '📞'),
(1, 'Stage 3 - Extended Review', 'Extended review period for complex cases', 4, 60, '/Suspended Users/Stage 3', 1, '#45B7D1', '🔍'),
(1, 'Stage 4 - Final Notice', 'Final notice before deletion proceedings', 5, 30, '/Suspended Users/Stage 4', 1, '#96CEB4', '⚠️'),
(1, 'Pending Deletion', 'Accounts approved for deletion', 6, 30, '/Suspended Users/Pending Deletion', 1, '#FECA57', '🗑️'),
(1, 'Temporary Hold', 'Accounts on temporary hold (litigation, etc.)', 7, NULL, '/Suspended Users/Hold', 1, '#FF9FF3', '⏸️'),
(1, 'Exit Row', 'Final processing before permanent deletion', 8, 7, '/Suspended Users/Exit Row', 1, '#FF6B6B', '🚪');

-- Triggers to maintain data consistency
CREATE TRIGGER IF NOT EXISTS update_account_stage_timestamp 
    AFTER UPDATE ON account_current_stage
    BEGIN
        UPDATE account_current_stage 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE email = NEW.email;
    END;

CREATE TRIGGER IF NOT EXISTS update_suspension_stages_timestamp 
    AFTER UPDATE ON suspension_stages
    BEGIN
        UPDATE suspension_stages 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE id = NEW.id;
    END;