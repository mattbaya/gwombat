-- GWOMBAT Hierarchical Menu System Schema
-- This replaces the flat menu structure with a true parent-child hierarchy

-- Drop existing tables (we'll migrate data first)
-- DROP TABLE IF EXISTS menu_search_cache;
-- DROP TABLE IF EXISTS menu_hierarchy;
-- DROP TABLE IF EXISTS menu_navigation;
-- DROP TABLE IF EXISTS menu_items;
-- DROP TABLE IF EXISTS menu_sections;

-- Core menu items table - each item can be a menu or an action
CREATE TABLE IF NOT EXISTS menu_items_v2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER DEFAULT NULL,  -- NULL for root/main menu items
    name TEXT UNIQUE NOT NULL,       -- Internal identifier (e.g., 'user_management')
    display_name TEXT NOT NULL,      -- User-visible name
    description TEXT,
    icon TEXT,                       -- Emoji or symbol
    color_code TEXT,                 -- ANSI color name (GREEN, BLUE, etc.)
    
    -- Menu behavior
    item_type TEXT NOT NULL CHECK(item_type IN ('menu', 'action', 'separator')),
    function_name TEXT,              -- For 'action' types: function to call
    
    -- Ordering and display
    sort_order INTEGER DEFAULT 999,  -- Lower numbers appear first
    is_visible INTEGER DEFAULT 1,    -- Show/hide items
    is_active INTEGER DEFAULT 1,     -- Enable/disable items
    
    -- Access control
    access_level TEXT DEFAULT 'user' CHECK(access_level IN ('user', 'admin', 'system')),
    
    -- Search optimization
    keywords TEXT,                   -- Space-separated search terms
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Self-referential foreign key for hierarchy
    FOREIGN KEY (parent_id) REFERENCES menu_items_v2(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_menu_parent ON menu_items_v2(parent_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_menu_type ON menu_items_v2(item_type);
CREATE INDEX IF NOT EXISTS idx_menu_active ON menu_items_v2(is_active, is_visible);
CREATE INDEX IF NOT EXISTS idx_menu_keywords ON menu_items_v2(keywords);
CREATE INDEX IF NOT EXISTS idx_menu_name ON menu_items_v2(name);

-- Navigation shortcuts (global keys like 's' for search)
CREATE TABLE IF NOT EXISTS menu_shortcuts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_char TEXT UNIQUE NOT NULL,   -- Single character shortcut
    display_name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    function_name TEXT NOT NULL,     -- Function to call
    is_global INTEGER DEFAULT 0,     -- Available everywhere?
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 999,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Menu display preferences
CREATE TABLE IF NOT EXISTS menu_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default configuration
INSERT OR IGNORE INTO menu_config (key, value, description) VALUES
    ('default_sort', 'sort_order', 'Default sort field: sort_order or display_name'),
    ('show_descriptions', '1', 'Show item descriptions in menus'),
    ('show_icons', '1', 'Show icons in menus'),
    ('enable_colors', '1', 'Use ANSI colors in menus'),
    ('items_per_page', '20', 'Maximum items before pagination'),
    ('enable_shortcuts', '1', 'Enable keyboard shortcuts'),
    ('breadcrumb_separator', ' / ', 'Separator for breadcrumb navigation');

-- Audit trail for menu changes
CREATE TABLE IF NOT EXISTS menu_audit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    menu_item_id INTEGER,
    action TEXT NOT NULL CHECK(action IN ('create', 'update', 'delete', 'move')),
    old_values TEXT,  -- JSON of previous values
    new_values TEXT,  -- JSON of new values
    user_name TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (menu_item_id) REFERENCES menu_items_v2(id) ON DELETE SET NULL
);

-- Views for easier querying

-- View: Full menu hierarchy with paths
CREATE VIEW IF NOT EXISTS v_menu_hierarchy AS
WITH RECURSIVE menu_path AS (
    -- Base case: root items
    SELECT 
        id,
        parent_id,
        name,
        display_name,
        description,
        icon,
        color_code,
        item_type,
        function_name,
        sort_order,
        is_visible,
        is_active,
        access_level,
        keywords,
        display_name as path,
        '/' || name as name_path,
        0 as depth
    FROM menu_items_v2
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case: child items
    SELECT 
        m.id,
        m.parent_id,
        m.name,
        m.display_name,
        m.description,
        m.icon,
        m.color_code,
        m.item_type,
        m.function_name,
        m.sort_order,
        m.is_visible,
        m.is_active,
        m.access_level,
        m.keywords,
        p.path || ' > ' || m.display_name as path,
        p.name_path || '/' || m.name as name_path,
        p.depth + 1 as depth
    FROM menu_items_v2 m
    JOIN menu_path p ON m.parent_id = p.id
)
SELECT * FROM menu_path;

-- View: Active menu items only
CREATE VIEW IF NOT EXISTS v_active_menus AS
SELECT * FROM menu_items_v2
WHERE is_active = 1 AND is_visible = 1
ORDER BY parent_id, sort_order, display_name;

-- View: Menu statistics
CREATE VIEW IF NOT EXISTS v_menu_stats AS
SELECT 
    (SELECT COUNT(*) FROM menu_items_v2) as total_items,
    (SELECT COUNT(*) FROM menu_items_v2 WHERE item_type = 'menu') as total_menus,
    (SELECT COUNT(*) FROM menu_items_v2 WHERE item_type = 'action') as total_actions,
    (SELECT COUNT(*) FROM menu_items_v2 WHERE parent_id IS NULL) as root_items,
    (SELECT MAX(depth) FROM v_menu_hierarchy) as max_depth,
    (SELECT COUNT(*) FROM menu_items_v2 WHERE is_active = 0 OR is_visible = 0) as hidden_items;

-- Workflow Automation menu entries
INSERT OR IGNORE INTO menu_items_v2 (name, display_name, description, icon, item_type, sort_order, keywords) VALUES
    ('workflow_automation', 'Workflow Automation', 'Automated task scheduling and management', '🤖', 'menu', 110, 'workflow automation schedule cron batch');

-- Workflow automation submenu items
INSERT OR IGNORE INTO menu_items_v2 (parent_id, name, display_name, description, icon, item_type, function_name, sort_order, keywords) VALUES
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'workflow_status', 'Workflow Status', 'View running workflows and execution history', '📊', 'action', 'show_workflow_status', 1, 'status running executions history'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'list_workflows', 'List Workflows', 'Show all configured workflows', '📋', 'action', 'list_workflows', 2, 'list workflows configured available'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'workflow_templates', 'Workflow Templates', 'Manage workflow templates and create new workflows', '📝', 'action', 'manage_workflow_templates', 3, 'templates create manage new'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'enable_disable_workflows', 'Enable/Disable Workflows', 'Enable or disable specific workflows', '🔧', 'action', 'toggle_workflow_status', 4, 'enable disable toggle workflows'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'manual_execution', 'Manual Execution', 'Run workflows manually outside of schedule', '▶️', 'action', 'manual_workflow_execution', 5, 'manual run execute now trigger'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'scheduler_control', 'Scheduler Control', 'Start/stop workflow scheduler daemon', '⚙️', 'action', 'workflow_scheduler_control', 6, 'scheduler daemon start stop control'),
    ((SELECT id FROM menu_items_v2 WHERE name = 'workflow_automation'), 'workflow_logs', 'Workflow Logs', 'View detailed workflow execution logs', '📄', 'action', 'view_workflow_logs', 7, 'logs execution history details output');