-- Menu Management Database Schema Extension
-- Dynamic menu system for GWOMBAT

-- Menu sections (main categories)
CREATE TABLE IF NOT EXISTS menu_sections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    section_order INTEGER NOT NULL,
    icon TEXT,
    color_code TEXT, -- ANSI color codes (GREEN, BLUE, etc.)
    is_active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Menu items (individual options within sections)
CREATE TABLE IF NOT EXISTS menu_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    section_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    description TEXT,
    function_name TEXT NOT NULL, -- Function to call when selected
    item_order INTEGER NOT NULL,
    icon TEXT,
    is_active INTEGER DEFAULT 1,
    access_level TEXT DEFAULT 'user', -- 'user', 'admin', 'system'
    keywords TEXT, -- Space-separated keywords for search
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (section_id) REFERENCES menu_sections(id) ON DELETE CASCADE,
    UNIQUE(section_id, item_order)
);

-- Menu navigation options (special options like 'c', 's', 'i', 'x')
CREATE TABLE IF NOT EXISTS menu_navigation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_char TEXT UNIQUE NOT NULL, -- 'c', 's', 'i', 'x', 'm', 'p'
    display_name TEXT NOT NULL,
    description TEXT,
    function_name TEXT NOT NULL,
    icon TEXT,
    is_global INTEGER DEFAULT 1, -- Available in all menus if 1
    nav_order INTEGER NOT NULL,
    is_active INTEGER DEFAULT 1
);

-- Menu hierarchy for submenus
CREATE TABLE IF NOT EXISTS menu_hierarchy (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_item_id INTEGER NOT NULL,
    child_section_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_item_id) REFERENCES menu_items(id) ON DELETE CASCADE,
    FOREIGN KEY (child_section_id) REFERENCES menu_sections(id) ON DELETE CASCADE,
    UNIQUE(parent_item_id, child_section_id)
);

-- Search cache for performance
CREATE TABLE IF NOT EXISTS menu_search_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    search_term TEXT NOT NULL,
    result_type TEXT NOT NULL, -- 'section', 'item'
    result_id INTEGER NOT NULL,
    relevance_score INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for menu performance
CREATE INDEX IF NOT EXISTS idx_menu_sections_order ON menu_sections(section_order);
CREATE INDEX IF NOT EXISTS idx_menu_items_section ON menu_items(section_id, item_order);
CREATE INDEX IF NOT EXISTS idx_menu_items_active ON menu_items(is_active);
CREATE INDEX IF NOT EXISTS idx_menu_keywords ON menu_items(keywords);
CREATE INDEX IF NOT EXISTS idx_menu_navigation_key ON menu_navigation(key_char);
CREATE INDEX IF NOT EXISTS idx_menu_hierarchy_parent ON menu_hierarchy(parent_item_id);

-- Views for menu display
CREATE VIEW IF NOT EXISTS menu_display AS
SELECT 
    ms.id as section_id,
    ms.name as section_name,
    ms.display_name as section_display,
    ms.description as section_description,
    ms.section_order,
    ms.icon as section_icon,
    ms.color_code,
    mi.id as item_id,
    mi.name as item_name,
    mi.display_name as item_display,
    mi.description as item_description,
    mi.function_name,
    mi.item_order,
    mi.icon as item_icon,
    mi.keywords,
    mi.access_level
FROM menu_sections ms
LEFT JOIN menu_items mi ON ms.id = mi.section_id AND mi.is_active = 1
WHERE ms.is_active = 1
ORDER BY ms.section_order, mi.item_order;

-- View for search functionality
CREATE VIEW IF NOT EXISTS menu_search AS
SELECT 
    'section' as result_type,
    ms.id as result_id,
    ms.display_name as title,
    ms.description,
    ms.section_order as sort_order,
    ms.icon,
    ms.color_code,
    NULL as function_name,
    NULL as keywords,
    ms.name || ' ' || ms.display_name || ' ' || COALESCE(ms.description, '') as searchable_text
FROM menu_sections ms
WHERE ms.is_active = 1

UNION ALL

SELECT 
    'item' as result_type,
    mi.id as result_id,
    mi.display_name as title,
    mi.description,
    (ms.section_order * 100 + mi.item_order) as sort_order,
    mi.icon,
    ms.color_code,
    mi.function_name,
    mi.keywords,
    mi.name || ' ' || mi.display_name || ' ' || COALESCE(mi.description, '') || ' ' || COALESCE(mi.keywords, '') as searchable_text
FROM menu_items mi
JOIN menu_sections ms ON mi.section_id = ms.id
WHERE mi.is_active = 1 AND ms.is_active = 1;