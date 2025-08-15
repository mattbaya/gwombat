![GWOMBAT Logo](assets/gwombat2.png)

# GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner

A comprehensive Google Workspace administration system providing enterprise-grade account lifecycle management, file operations, and automated workflows with database tracking and verification.

## 🚀 Key Features

- **🔄 Account Lifecycle Management** - Complete suspended account processing with database tracking
- **💾 File & Drive Operations** - Bulk operations, shared drive cleanup, ownership management  
- **🔍 Analysis & Discovery** - File sharing analysis, license management, compliance reporting
- **📋 List Management** - Database-driven batch operations with progress tracking
- **📈 Reports & Monitoring** - Comprehensive logging, audit trails, and analytics
- **⚙️ System Administration** - Automated backups, deployment, and configuration management

## 🏗️ Architecture

- **Database-Driven**: SQLite backend with 7-table schema for persistent state tracking
- **Menu-Driven Interface**: Intuitive navigation with 8 main functional categories
- **Security-First**: Environment-based configuration, audit logging, SSH key deployment
- **Modular Design**: 60+ individual operations organized by function type
- **Command Transparency**: All GAM commands displayed before execution

## 📊 Core Functionality

### Account Management (10 operations)
- Suspended account lifecycle processing
- Temporary hold and pending deletion management
- Batch operations with CSV import/export
- Automated account discovery and staging

### File Operations (13 operations)
- Shared drive cleanup and administration
- Bulk file ownership transfer
- URL parsing and drive search
- File activity analysis and archiving

### Analysis Tools (11 operations)
- Cross-domain sharing detection
- License auditing and management
- Storage usage analysis
- Compliance reporting

### Database Management (11 operations)
- Account list creation and management
- Progress tracking and verification
- Import/export capabilities
- Automated backup and recovery

## 📋 Requirements

### Required
- **Linux/macOS** - Primary platforms
- **Bash 4.0+** - Shell environment
- **GAM** - Google Apps Manager ([installation guide](https://github.com/GAM-team/GAM))
- **SQLite** - Database backend
- **Git** - Version control

### Optional
- **SSH/expect** - For deployment automation
- **Google Drive API** - For backup uploads

## 🚀 Quick Start

```bash
# Clone and setup
git clone git@github.com:mattbaya/gwombat.git
cd gwombat
cp .env.template .env

# Configure your environment
nano .env  # Set DOMAIN, ADMIN_USER, GAM_PATH, etc.

# Run GWOMBAT
./gwombat.sh
```

## 📚 Documentation

- **[INSTALLATION.md](INSTALLATION.md)** - Detailed setup and configuration guide
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Production deployment instructions  
- **[CLAUDE.md](CLAUDE.md)** - Development context and architecture notes

## 🔐 Security Features

- **Environment Isolation** - All secrets in .env files, nothing hardcoded
- **Complete Audit Trail** - Every operation logged with session correlation
- **Automated Backups** - Database and configuration backup to Google Drive
- **SSH Key Authentication** - Secure deployment with automated key management
- **Clean Git History** - No sensitive data in version control

## 🌟 Recent Enhancements (v3.0)

- **History Sanitization** - Removed all institutional references from git history
- **Configurable Paths** - Local directory usage, no system path assumptions
- **Enhanced Security** - Environment-based configuration, no hardcoded credentials
- **Command Transparency** - Display all GAM commands before execution
- **URL Intelligence** - Smart drive URL parsing and name-based search

## 🎯 Why GWOMBAT?

1. **Enterprise Scale** - Handles large Google Workspace environments
2. **Database Persistence** - Reliable state tracking across all operations  
3. **Security First** - Clean audit trails and secure configuration
4. **User Friendly** - Intuitive menus with real-time progress tracking
5. **Transparent** - See exactly what commands are executed
6. **Extensible** - Modular design for easy feature additions

## 📊 Project Stats

- **6800+ lines** - Main application
- **700+ lines** - Database functions
- **11 utility scripts** - Specialized operations
- **7 database tables** - Comprehensive data model
- **60+ operations** - Across 8 functional categories

## 🚀 Future Roadmap

- Web-based dashboard interface
- RESTful API for integration
- Multi-domain management
- Advanced analytics and ML insights
- Mobile monitoring interface

---

**GWOMBAT** transforms Google Workspace administration from script collections into a comprehensive, enterprise-grade platform with database persistence, security-first design, and transparent operations.

*For detailed installation instructions, see [INSTALLATION.md](INSTALLATION.md)*