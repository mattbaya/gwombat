# GWOMBAT Hierarchical Menu System

## Overview
GWOMBAT now features a revolutionary hierarchical menu system that replaces 50+ hardcoded menu functions with a single, data-driven universal renderer. This system provides true parent-child navigation with enhanced UX features.

## Architecture Benefits

### Before (Flat System) ❌
- 50+ individual hardcoded menu functions
- Manual function dispatchers for each menu
- Arbitrary ordering (section_order: 99, 100, 101, 120)
- Unused `menu_hierarchy` table
- Maintenance nightmare for adding new menus

### After (Hierarchical System) ✅
- **1 universal menu renderer** handles all menus
- **True parent-child relationships** in database
- **Automatic back navigation** (knows parent automatically)
- **Data-driven routing** - no hardcoded dispatchers
- **Zero maintenance** - add menus via database inserts

## Database Schema

### Core Table: `menu_items_v2`
```sql
CREATE TABLE menu_items_v2 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER DEFAULT NULL,     -- NULL for root/main menu items
    name TEXT UNIQUE NOT NULL,          -- Internal identifier
    display_name TEXT NOT NULL,         -- User-visible name
    description TEXT,
    icon TEXT,                          -- Emoji or symbol
    color_code TEXT,                    -- ANSI color name
    
    item_type TEXT NOT NULL CHECK(item_type IN ('menu', 'action', 'separator')),
    function_name TEXT,                 -- For 'action' types
    
    sort_order INTEGER DEFAULT 999,
    is_visible INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    access_level TEXT DEFAULT 'user',
    keywords TEXT,                      -- Search terms
    
    FOREIGN KEY (parent_id) REFERENCES menu_items_v2(id) ON DELETE CASCADE
);
```

### Menu Hierarchy Example
```
Main Menu (parent_id = NULL)
├── User & Group Management (menu)
│   ├── Re-scan all domain accounts (action)
│   ├── List all accounts (action)
│   └── Account search and diagnostics (action)
├── File & Drive Operations (menu)
│   ├── File Operations (action)
│   └── Shared Drive Management (action)
└── Dashboard & Statistics (menu)
    ├── System Overview (menu)
    │   ├── System Dashboard (action)
    │   └── System Health Check (action)
    └── Statistics & Metrics (menu)
        ├── Domain Overview Statistics (action)
        └── User Account Statistics (action)
```

## Enhanced Navigation Features

### Arrow Key Navigation
- **↑ ↓** - Move selection up/down through menu items
- **→ Enter** - Select highlighted item (enter submenu or execute action)
- **←** - Go back to previous menu (follows parent relationship)

### Visual Enhancements
- **Highlighted Selection**: Current item shown with blue background
- **Breadcrumb Navigation**: Shows full path (e.g., "Main Menu > Dashboard > Statistics")
- **Status Indicators**: Shows current position (e.g., "Selection: 3/9")
- **Color-Coded Sections**: Different colors for menu categories

### Keyboard Shortcuts (Preserved)
- **1-9** - Direct selection by number (still works)
- **s** - Search all menus by keyword
- **m** - Return to main menu
- **b** - Back to previous menu
- **i** - Show alphabetical index
- **?** or **h** - Show help
- **x** or **q** - Exit

## Configuration Options

### Environment Variables (.env)
```bash
USE_HIERARCHICAL_MENUS="true"         # Enable hierarchical system
ENABLE_ARROW_NAVIGATION="true"        # Enable arrow key navigation
SHOW_MENU_DESCRIPTIONS="true"         # Show item descriptions
```

### Fallback Behavior
- **Non-interactive mode**: Automatically uses standard input/output
- **Terminal limitations**: Falls back to number-only navigation
- **Missing dependencies**: Falls back to original menu system

## Migration Process

### Automated Migration
The system automatically migrates from the old flat structure:

```bash
# Run migration (automatic on first use)
./shared-utilities/migrate_menu_hierarchy.sh

# Backup created automatically
shared-config/menu_backup_YYYYMMDD_HHMMSS.db
```

### Migration Results
- **9 root menus** converted to hierarchical structure
- **3 submenus** properly nested under parents
- **48 action items** linked to appropriate parent menus
- **8 navigation shortcuts** preserved

## Usage Examples

### Basic Navigation
1. Start GWOMBAT: `./gwombat.sh`
2. Use arrow keys to highlight desired option
3. Press Enter to select
4. Use ← or 'b' to go back

### Search Integration
- Press 's' from any menu to search
- Search works across all hierarchy levels
- Results show full breadcrumb paths

### Direct Number Access
- Number keys (1-9) still work for quick access
- Combines traditional and modern navigation

## Technical Implementation

### Universal Renderer
Single `render_menu_enhanced()` function handles all menus:
- Queries database for menu items based on parent_id
- Displays with highlighting and navigation
- Handles both menu containers and action items

### State Management
- **Current Menu ID**: Tracks current location
- **Menu History**: Space-separated list for bash 3.2 compatibility
- **Breadcrumb Path**: Auto-generated from database relationships

### Terminal Compatibility
- **Bash 3.2 Compatible**: Works on older systems
- **ANSI Escape Codes**: Standard terminal control sequences
- **stty Integration**: Proper raw mode handling for arrow keys

## Benefits for Issue #8

### ✅ **Core Navigation Improvements**
- **Arrow Key Navigation** - ↑↓ move, Enter select, ← back
- **Visual Highlighting** - Blue background shows current selection
- **Enter to Select** - Modern interface standard
- **Escape/Back Navigation** - ← key and 'b' both work

### ✅ **Keyboard Shortcuts & Power User Features**
- **Enhanced Shortcuts** - All original shortcuts preserved plus arrow keys
- **Quick Jump** - Number keys still work (1-9)
- **Vim-like Navigation** - ← → for back/forward navigation
- **Context Help** - Enhanced help with arrow key documentation

### ✅ **Visual & UX Improvements**
- **Menu Item Highlighting** - Current selection clearly visible with color
- **Category Color Coding** - Different colors for menu sections
- **Progress Indicators** - Selection counter (3/9)
- **Context-Sensitive Help** - Help shows current navigation options
- **Better Error Messages** - Clear feedback for invalid selections

## Performance Impact
- **Minimal Overhead**: Single database query per menu level
- **Efficient Caching**: Menu items loaded once per navigation
- **Fast Navigation**: Arrow keys provide immediate visual feedback
- **Memory Efficient**: bash 3.2 compatible arrays and strings

## Future Enhancements
- **Tab Completion**: Auto-complete for search terms
- **Mouse Support**: Click selection in compatible terminals
- **Themes**: Customizable color schemes
- **Pagination**: Automatic handling of long menu lists
- **Quick Commands**: Type-ahead search within current menu