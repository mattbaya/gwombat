# CLAUDE.md - AI Development Context

## Project Overview
This is the **Suspended Account Lifecycle Management System** - a comprehensive bash script that manages Google Workspace accounts through their complete lifecycle from suspension to deletion. The script consolidates over 100+ individual utility scripts into a unified, interactive system.

## Current State (August 2025)
- **Primary Script**: `temphold-master.sh` - Master lifecycle management script (6000+ lines)
- **Architecture**: Menu-driven interactive system with 5 lifecycle stages + utility tools
- **Integration Status**: All script collections consolidated and archived
- **Documentation**: Recently updated with comprehensive menu navigation improvements

## Key Components

### 1. Core Lifecycle Management (`temphold-master.sh`)
**Main Menu Structure** (with option counts for navigation):
- Stage 1: Recently Suspended Accounts (5 options)
- Stage 2: Process Pending Deletion (6 options)  
- Stage 3: File Sharing Analysis & Reports (7 options)
- Stage 4: Final Decisions - Exit Row/Temporary Hold (6 options)
- Stage 5: Account Deletion Operations (5 options)
- Discovery & Query Tools (11 options)
- Administrative Tools & Cleanup (6 options)
- Reports & Monitoring (10 options)

**Recent Navigation Improvements**:
- Added option counts to all main menu entries
- Universal 'm' (main menu) and 'x' (exit) options in all submenus
- Improved menu navigation UX with clear option indicators

### 2. Shared Utilities (`shared-utilities/`)
Essential standalone scripts:
- `add-members-to-group.sh` - Bulk group membership management
- `datefix.sh` - Sophisticated date restoration from Drive activity
- `recent4.sh` - File activity analysis with configurable thresholds
- `ownership_management.sh` - Enterprise-grade ownership transfer workflows
- `fixshared.sh` - Shared drive cleanup and pending deletion marker removal
- `find-suspended.sh` - Account analysis for deletion candidates

### 3. Archived Collections (`old-scripts-replaced-by-master/`)
Contains 8 complete script collections (5,100+ files):
- `calendar/` - Google Calendar operations
- `changeowner/` - File ownership management system
- `find-accounts-with-no-sharing/` and `find-no-shares/` - Account analysis tools
- `group/` - Google Groups management
- `misc/` - Date restoration and miscellaneous utilities
- `recentlymodified/` - File activity analysis
- `shareddrives/` - Shared drive management system

## Technical Architecture

### Menu System
- **Hierarchical structure** with clear navigation paths
- **Context-aware menus** that show relevant operations for each lifecycle stage
- **Comprehensive error handling** with user-friendly messages
- **Progress tracking** for batch operations
- **Dry-run capabilities** for preview before execution

### Key Functions Integration
- **Account Analysis**: `analyze_accounts_no_sharing()`, `analyze_file_activity()`
- **Ownership Management**: `transfer_ownership_to_gamadmin()`, `manage_suspension_groups()`
- **File Processing**: `restore_file_dates()`, `cleanup_shared_drive()`
- **Group Management**: `bulk_add_to_group()`, `remove_user_from_all_groups()`
- **Lifecycle Operations**: Complete stage-based workflow management

### Configuration Management
- **Dynamic configuration system** with fallback defaults
- **Flexible path management** for different environments
- **Comprehensive logging** with session tracking
- **Performance monitoring** and operation auditing

## Development Context for Claude

### Current Integration Status
✅ **Completed**: All major script collections have been analyzed, integrated, and archived
✅ **Menu Navigation**: Recently improved with option counts and universal navigation
✅ **Group Management**: Bulk operations fully integrated into administrative tools
✅ **Documentation**: Updated to reflect current system capabilities

### Key Development Patterns
1. **Function-based architecture** with clear separation of concerns
2. **Menu-driven UX** with consistent patterns across all sections
3. **Comprehensive error handling** and user input validation
4. **Extensive logging and audit trails** for all operations
5. **GAM integration** for Google Workspace management
6. **Dry-run capabilities** for safe operation preview

### Recent Major Changes
- **Script Consolidation**: Integrated 100+ scripts into unified system
- **Menu Enhancement**: Added navigation improvements and option counts
- **Group Management**: Added bulk group operations to administrative tools menu
- **Architecture Cleanup**: Eliminated external dependencies and improved modularity

### Dependencies
- **GAM (Google Apps Manager)**: Primary interface to Google Workspace
- **Standard Unix Tools**: bash, grep, sed, awk for text processing
- **File System**: Organized directory structure for logs, configs, and temporary files

### Testing Commands
```bash
# Test menu navigation
echo "1" | timeout 5 bash temphold-master.sh

# Test exit functionality  
echo -e "1\nx" | timeout 5 bash temphold-master.sh

# Verify script syntax
bash -n temphold-master.sh
```

### Future Considerations
- Additional utility script integration as needed
- Enhanced reporting and analytics capabilities
- Possible web interface for non-technical users
- Integration with other institutional systems

## File Organization
```
temphold-master/
├── temphold-master.sh              # Main lifecycle management script
├── shared-utilities/               # Essential standalone utilities
├── old-scripts-replaced-by-master/ # Archived script collections  
├── config/                        # Configuration files
├── logs/                          # Session and operation logs
├── reports/                       # Generated reports and summaries
├── backups/                       # Configuration and data backups
└── tmp/                          # Temporary processing files
```

This project represents a comprehensive consolidation of institutional Google Workspace management tools into a cohesive, user-friendly system suitable for both technical and non-technical administrators.