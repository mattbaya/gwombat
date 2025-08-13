# Suspended Account Lifecycle Management System

A comprehensive, interactive system that manages Google Workspace accounts through their complete lifecycle from suspension to deletion. This master script consolidates 100+ individual utility scripts into a unified, menu-driven interface.

## 🚀 Recent Updates (August 2025)

### ✅ Menu Navigation Improvements
- **Option counts** displayed for all submenus (e.g., "Stage 1: Recently Suspended (5 options)")
- **Universal navigation**: Press 'm' for main menu or 'x' to exit from any submenu
- **Clear menu structure** with improved user experience

### ✅ Complete Script Integration
- All script collections consolidated and archived in `old-scripts-replaced-by-master/`
- Essential utilities preserved in `shared-utilities/` folder
- Group management operations integrated into administrative tools

## 📋 System Overview

### Account Lifecycle Stages
```
1. Recently Suspended → 2. Pending Deletion → 3. Share Analysis → 4. Final Decisions → 5. Deletion
```

The system manages accounts through five distinct stages:

1. **📋 Stage 1: Recently Suspended** (5 options)
   - Query and analyze newly suspended accounts
   - Review account status and details
   - Export suspended account lists

2. **🔄 Stage 2: Pending Deletion** (6 options)
   - Process accounts for pending deletion
   - Rename files and add deletion markers
   - Remove users from groups
   - Support both single user and batch processing

3. **📊 Stage 3: File Sharing Analysis** (7 options)
   - Generate detailed sharing analysis reports
   - Identify files shared with active users
   - Update filenames with pending deletion labels
   - Clean up analysis files

4. **🎯 Stage 4: Final Decisions** (6 options)
   - Move accounts to Temporary Hold (more time)
   - Move accounts to Exit Row (prepare for deletion)
   - Query users in different organizational units

5. **🗑️ Stage 5: Account Deletion** (5 options)
   - Final deletion operations and auditing
   - Orphaned file collection
   - Pre-deletion audit reports
   - License management for deletion candidates

## 🛠️ Utilities & Tools

### Discovery & Query Tools (11 options)
- Query users by organizational unit or status
- Scan for orphaned pending deletion files
- Diagnose account consistency issues
- Check for incomplete operations

### Administrative Tools & Cleanup (6 options)
- **Shared Drive Operations**: Cleanup, preview, and management
- **License Management**: Add, remove, and audit user licenses
- **File Ownership Audit**: Track ownership across the organization
- **Group Management**: Bulk add/remove operations
- **Dry-run Mode**: Preview operations before execution

### Reports & Monitoring (10 options)
- Daily activity reports and session summaries
- Performance statistics and error logs
- Configuration management interface
- Log cleanup and maintenance tools

## 🎯 Key Features

### Interactive Menu System
- **Hierarchical navigation** with clear option counts
- **Universal shortcuts**: 'm' (main menu), 'x' (exit) available everywhere
- **Context-aware menus** showing relevant operations for each stage
- **Color-coded output** for easy status identification

### Advanced Operations
- **Batch Processing**: Handle multiple users from files
- **Preview Mode**: Show detailed summaries before execution
- **Progress Tracking**: Real-time progress for batch operations
- **Comprehensive Logging**: Detailed audit trails for all operations
- **Error Recovery**: Robust error handling and validation

### Google Workspace Integration
- **GAM Integration**: Full Google Apps Manager compatibility
- **Drive Operations**: File ownership transfer, sharing analysis
- **Group Management**: Bulk membership operations
- **Organizational Units**: User movement between OUs
- **License Management**: Automated license assignment/removal

## 📦 Installation & Setup

### Prerequisites
- GAM (Google Apps Manager) installed and configured
- Bash shell environment (Linux/macOS)
- Appropriate Google Workspace administrative permissions

### Installation
1. **Clone/Download** the script collection
2. **Set permissions**:
   ```bash
   chmod +x temphold-master.sh
   chmod +x shared-utilities/*.sh
   ```
3. **Configure paths** in the script or use default structure
4. **Test GAM connectivity**:
   ```bash
   gam info domain
   ```

## 🚀 Usage

### Quick Start
```bash
./temphold-master.sh
```

The script will launch an interactive menu system. Navigate using:
- **Number keys** to select options
- **'m'** to return to main menu from anywhere
- **'x'** to exit from any menu

### Menu Navigation Example
```
=== LIFECYCLE OPERATIONS ===
1. 📋 Stage 1: Manage Recently Suspended Accounts (5 options)
2. 🔄 Stage 2: Process Pending Deletion (Rename & Label) (6 options)
3. 📊 Stage 3: File Sharing Analysis & Reports (7 options)
...

=== UTILITIES & TOOLS ===  
6. 🔍 Discovery & Query Tools (11 options)
7. 🛠️  Administrative Tools & Cleanup (6 options)
8. 📈 Reports & Monitoring (10 options)
```

### Batch Processing
For multiple users, create a text file with one email per line:
```
user1@domain.com
user2@domain.com
user3@domain.com
```

## 📁 File Structure

```
temphold-master/
├── temphold-master.sh                    # Main script (6000+ lines)
├── shared-utilities/                     # Essential standalone utilities
│   ├── add-members-to-group.sh          # Bulk group management
│   ├── datefix.sh                       # Date restoration from Drive activity
│   ├── recent4.sh                       # File activity analysis
│   ├── ownership_management.sh          # Enterprise ownership transfers
│   ├── fixshared.sh                     # Shared drive cleanup
│   └── find-suspended.sh                # Account analysis tools
├── old-scripts-replaced-by-master/      # Archived script collections (5100+ files)
├── config/                              # Configuration files
├── logs/                                # Session and operation logs
├── reports/                             # Generated reports
├── backups/                             # Configuration backups
└── tmp/                                 # Temporary processing files
```

## 🔧 Configuration

### Environment Variables
- `GAM_PATH`: Path to GAM executable (default: `/usr/local/bin/gam`)
- `SCRIPTPATH`: Base directory for operations (auto-detected)
- `LOG_LEVEL`: Logging verbosity level

### Configuration Files
- `config/default.conf`: Default settings
- `config/local.conf`: Local overrides
- User configurations stored in `config/` directory

## 📊 Logging & Monitoring

### Log Files
- **Session logs**: `logs/session-YYYYMMDD_HHMMSS.log`
- **Operation audit**: `logs/audit-YYYYMMDD.log`
- **Error tracking**: `logs/error-YYYYMMDD.log`
- **Performance stats**: `logs/performance-YYYYMMDD.log`

### Report Generation
- **Daily summaries**: Automated daily activity reports
- **Operation reports**: Detailed breakdowns of batch operations
- **Analysis reports**: File sharing and ownership analysis
- **Audit trails**: Complete operation history

## 🛡️ Safety Features

### Preview & Confirmation
- **Dry-run mode**: Preview all operations before execution
- **User confirmation**: Required approval for destructive operations
- **Detailed summaries**: Show exactly what will happen
- **Operation validation**: Check inputs and conditions

### Error Handling
- **Input validation**: Comprehensive user input checking
- **Graceful failures**: Robust error recovery mechanisms
- **Clear messaging**: User-friendly error descriptions
- **Audit logging**: Complete tracking of all issues

## 🔍 Troubleshooting

### Common Issues
1. **GAM not found**: Verify GAM installation and PATH
2. **Permission errors**: Check file permissions and directory access
3. **Network issues**: Verify Google Workspace connectivity
4. **Configuration problems**: Review config files and paths

### Debug Mode
Enable verbose logging by setting:
```bash
export DEBUG=1
./temphold-master.sh
```

### Getting Help
- Check the operation logs in `logs/` directory
- Review the error messages in the console output
- Verify GAM connectivity: `gam info domain`
- Test with a single user before batch operations

## 📈 Performance

### Optimization Features
- **Batch operations**: Process multiple users efficiently
- **Progress tracking**: Real-time status updates
- **Caching**: Intelligent caching of API responses
- **Parallel processing**: Where safe and beneficial

### Scale Considerations
- Handles hundreds of users in batch operations
- Configurable rate limiting for API calls
- Memory-efficient processing of large datasets
- Resumable operations for interrupted processes

## 🏛️ Enterprise Features

### Compliance & Auditing
- Complete audit trails for all operations
- Detailed operation logging and reporting
- User action tracking and accountability
- Compliance report generation

### Integration Capabilities
- GAM/Google Workspace API integration
- CSV import/export functionality
- Batch processing capabilities
- Custom reporting formats

### Administrative Controls
- Role-based operation access
- Configuration management interface
- System health monitoring
- Performance analytics

## 📚 Version History

- **v2.0** (August 2025): Menu navigation improvements, complete script consolidation
- **v1.8** (2025): Group management integration, administrative tools enhancement
- **v1.5** (2025): Multi-stage lifecycle management, comprehensive utility integration
- **v1.0** (Original): Basic temporary hold operations

## 👥 Contributing

This system consolidates years of institutional knowledge and operational scripts. When adding new functionality:

1. Follow the established menu hierarchy
2. Maintain comprehensive logging
3. Include dry-run/preview capabilities
4. Add appropriate error handling
5. Update documentation accordingly

---

**Note**: This system manages critical account lifecycle operations. Always test new changes in a development environment before production use.