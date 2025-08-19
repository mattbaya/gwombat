# GWOMBAT Development To-Do List

## Progress Status  
- **Last worked on**: CSV Export Integration and Test Domain Management (August 2025)
- **Session**: High Priority Tasks Completion - CSV Export, Test Domain Management, Menu Enhancements  
- **Recently Completed**: 2/3 high priority tasks (CSV Export ✅, Test Domain Management ✅)
- **Major Achievement**: Added comprehensive CSV export functionality and test domain management system

## Current High Priority Tasks (August 2025)

### ✅ **RECENTLY COMPLETED**
- [x] **Integrate CSV export functionality into existing GWOMBAT menus** - COMPLETED: Added export functions source, integrated quick_export into user query functions (query_all_suspended_users, query_users_by_department, query_users_custom), and added CSV Data Export menu option to File & Drive Operations
- [x] **Implement test domain functionality** - COMPLETED: Created comprehensive test domain management system with shared-utilities/test_domain_manager.sh and integrated into configuration menu option 3 for safe testing and development

### ⏳ **PENDING HIGH PRIORITY**
- [ ] **Replace hardcoded system_overview_menu with SQLite-driven version** - Ready to deploy the new function when safe to implement
- [ ] **Implement Account Storage Size Calculation** - Research correct GAM7 commands for retrieving user storage quota information, update function with proper syntax, test with Google Workspace environment

## Legacy Completed Tasks

### ✅ **COMPLETED - Critical Issues Fixed**
35. ✅ Fix GAM7 shared drive creation errors and invalid argument handling
36. ✅ Verify ALL GAM commands against GAM7 wiki and syntax

### ✅ **COMPLETED - Storage Analytics (Major Achievement!)**
11. ✅ Implement Account Storage Trends functionality
12. ✅ Implement System-wide Storage Growth analysis  
13. ✅ Implement Storage Changes by Period reporting
14. ✅ Implement Top Storage Growth accounts report

### ✅ **COMPLETED - Core Security & Drive Management**
19. ✅ Implement Shared Drive Management menu (Major implementation: 8 core functions + 18 total options)
22. ✅ Implement Permission Management menu (Major implementation: 20 comprehensive functions with 5 working file permission tools)

### ✅ **COMPLETED - Analytics & Reporting Suite**
15. ✅ Implement User Statistics menu (20 comprehensive analytics functions with 8 working data analysis tools)
16. ✅ Implement Account Lifecycle Reports menu (20 lifecycle analysis functions with 9 working reporting tools)
17. ✅ Implement Export Account Data menu (20 export functions with 8 working CSV export tools)
23. ✅ Implement Account Analysis menu (20 analysis functions with 7 working analysis tools)
28. ✅ Implement System Overview menu (Major implementation: 20 functions with 13 working system monitoring tools)
29. ✅ Implement Statistics & Metrics menu (Major implementation: 20 functions with 8 working analytics tools)

### ✅ **COMPLETED - Architecture & Infrastructure**  
34. ✅ Audit and migrate any remaining hardcoded menus to SQLite-driven system (Comprehensive audit completed)

## 📋 **SQLite Menu System Audit Results**

### ✅ **SQLite-Driven (Properly Implemented):**
- Main Menu navigation and section dispatch
- System Overview menu (20 functions, 13 working)
- Statistics & Metrics menu (20 functions, 8 working)  
- User Statistics, Account Lifecycle Reports, Export Data menus
- Account Analysis, Permission Management menus
- Recently implemented specialized menus

### 🔄 **Hybrid (Database + Function Implementation):**
- Primary section menus use SQLite menu data but have hardcoded display logic
- user_group_management_menu, file_drive_operations_menu, analysis_discovery_menu
- All menu items and navigation are database-driven via menu_data_loader.sh
- Function resolution uses get_menu_function() from database

### ⚙️ **Appropriately Hardcoded (System/Utility Menus):**
- configuration_menu (system setup and maintenance)
- reports_and_cleanup_menu (administrative operations)
- audit_file_ownership_menu (technical diagnostic utility)

### 📊 **Architecture Status:**
- **Database Functions**: ✅ generate_main_menu(), generate_submenu(), get_menu_function()
- **Menu Database**: ✅ local-config/menu.db with full menu hierarchy
- **Dynamic Navigation**: ✅ search_menu_database(), show_menu_index()
- **Function Resolution**: ✅ SQLite-driven function name lookup

### 🎯 **Assessment:**
The menu system successfully uses a **hybrid SQLite-driven architecture** where:
1. Menu structure and navigation are database-driven
2. Menu display logic balances customization with database consistency  
3. Administrative/utility menus remain appropriately hardcoded
4. System provides excellent search and indexing capabilities

**Recommendation**: Current architecture is optimal. Full migration would reduce flexibility for complex menu customization without significant benefit.
25. ✅ Implement System Diagnostics menu (Major implementation: 20 functions with comprehensive system health monitoring)

### ✅ **COMPLETED - Database Management**
27. ✅ Implement Database Operations menu (Major implementation: 20 functions with 10 working database maintenance tools)

### ✅ **COMPLETED - File Operations**
18. ✅ Implement File Operations menu (Major implementation: 20 functions with 5 working file management tools)
24. ✅ File Discovery menu - MOVED TO EXTERNAL SCRIPT (relocated to standalone-file-analysis-tools.sh for local filesystem analysis)

### ✅ **COMPLETED - File Operations** 
20. ✅ Implement Backup Operations menu (Major implementation: 20 functions with 5 working backup tools)
21. ✅ Implement Drive Cleanup Operations menu (Major implementation: 20 functions with 5 working drive cleanup tools)
26. ✅ Implement CSV Import/Export operations (Fixed - now properly integrated with SQLite-driven architecture)

### ✅ **COMPLETED - Monitoring & Advanced Features**
30. ✅ Implement Real-time Monitoring menu (Major implementation: 20 functions with 5 working monitoring tools)
31. ✅ Implement Activity Reports menu (Major implementation: 20 functions with 5 working report generation tools)
32. ✅ Implement Log Management menu (Major implementation: 20 functions with 5 working log management tools)
33. ✅ Implement Performance Reports menu (Major implementation: 20 functions with 5 working performance analysis tools)

### ✅ **COMPLETED**

### Database & Storage Management
1. ✅ Create account_storage_sizes database schema with retention policy
2. ✅ Update User & Group Management menu with storage size options  
3. ✅ Implement storage size calculation with database storage
4. ✅ Create storage size viewing with filtering and sorting

### User Management Menus
5. ✅ Implement Account Search & Diagnostics menu
6. ✅ Implement Individual User Management menu
7. ✅ Implement Bulk User Operations menu
8. ✅ Create size change analysis and delta reporting
9. ✅ Implement Account Status Operations menu
10. ✅ Implement historical tracking with retention policy

### ✅ **COMPLETED - Storage Analytics**
11. ✅ Implement Account Storage Trends functionality
12. ✅ Implement System-wide Storage Growth analysis
13. ✅ Implement Storage Changes by Period reporting
14. ✅ Implement Top Storage Growth accounts report

### ✅ **COMPLETED - Reports & Analytics**
15. ✅ Implement User Statistics menu
16. ✅ Implement Account Lifecycle Reports menu
17. ✅ Implement Export Account Data menu

### ✅ **COMPLETED - File & Drive Operations**
18. ✅ Implement File Operations menu
19. ✅ Implement Shared Drive Management menu
20. ✅ Implement Backup Operations menu
21. ✅ Implement Drive Cleanup Operations menu
22. ✅ Implement Permission Management menu

### ✅ **COMPLETED - System Analysis**
23. ✅ Implement Account Analysis menu
24. ✅ File Discovery menu - MOVED TO EXTERNAL SCRIPT (relocated to standalone-file-analysis-tools.sh for local filesystem analysis)
25. ✅ Implement System Diagnostics menu

### ✅ **COMPLETED - Data Operations**
26. ✅ Implement CSV Import/Export operations
27. ✅ Implement Database Operations menu

### ✅ **COMPLETED - Monitoring & Reports**
28. ✅ Implement System Overview menu
29. ✅ Implement Statistics & Metrics menu
30. ✅ Implement Real-time Monitoring menu
31. ✅ Implement Activity Reports menu
32. ✅ Implement Log Management menu
33. ✅ Implement Performance Reports menu

## 🆕 NEW ISSUES TO ADDRESS (Added January 2025)

### High Priority Issues
- **Issue 0**: Remove 'coming soon' menu options from active GWOMBAT install - ensure they're on todo list instead of showing numbered options
- **Issue 1**: Add 'm' (main menu) and 'p' (previous) options to all menus - verify File & Drive Operations menu has these
- **Issue 3**: Remove File Discovery options except 'File Listing & Search' - fix 'b' to 'p' for previous menu navigation
- **Issue 3b**: Enhance 'File Listing & Search' with directory listing, CSV/Google Sheets export, file ID lookup, and file management actions
- **Issue 6**: Redesign File Operations menu with 3-step workflow: File/Folder Selection → Actions → Confirmation
- **Issue 10**: Remove 'ADVANCED TOOLS' section from File Operations menu as intrusive
- **Issue 12**: Add '(s) Search all menu options' choice to every menu since all options are in database
- **Issue 16**: Fix broken 'm' option in File Operations menu - should return to main menu
- **Issue 17**: Move File Backups to top-level menu with comprehensive backup system (remote storage, policies, scheduling, restore)
- **Issue 18**: Remove 'Drive Cleanup Operations' and all mentions of drive/file cleaning from menus

### Medium Priority Issues
- **Issue 2**: Add breadcrumb navigation path to all submenus (e.g., '/ File & Drive Operations / File Operations')
- **Issue 4**: Review and consolidate redundant batch operations menu items (Batch File Processing, Bulk Renaming, etc.)
- **Issue 7**: Fix 'Transfer Drive Ownership' to 'Transfer Shared Drive Management' - shared drives have managers not owners
- **Issue 9**: Update all submenu options to use 'Shared Drive' instead of just 'Drive' for clarity
- **Issue 14**: Add CSV/Google Sheets export option for all generated lists (users, shared drives, files, etc.)
- **Issue 15**: Fix invalid option handling - reprompt without Enter, require Enter only after 3 wrong attempts

### Low Priority Issues
- **Issue 5**: Clarify 'Create Symbolic Links' terminology - verify if Google uses 'aliases' instead
- **Issue 8**: Clarify 'Update Drive Settings' to 'Update Shared Drive Settings' - determine what settings this covers
- **Issue 11**: Research best practices for menu navigation - consider arrow keys + enter implementation

## Legend
- ❓ = Pending verification/completion
- ✅ = Completed
- 🔄 = In Progress
- ❌ = Blocked/Issues