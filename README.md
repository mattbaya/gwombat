![GWOMBAT Logo](assets/gwombat2.png)

# GWOMBAT - Google Workspace Optimization, Management, Backups And Taskrunner

A comprehensive Google Workspace administration system with revolutionary SQLite-driven dynamic interfaces, enterprise-grade account lifecycle management, and advanced automation capabilities.

## 🚀 Revolutionary Features

- **🔄 Dynamic Menu System** - SQLite-driven interfaces with intelligent search across 43+ operations
- **👥 Comprehensive User Management** - Complete lifecycle from creation to deletion with database tracking
- **🔍 Intelligent Search** - Real-time keyword search across all menu options with contextual results
- **📋 Alphabetical Index** - Complete operation catalog with navigation paths
- **⚙️ External Tools Integration** - Synchronized GAM, GYB, and rclone domain configuration
- **🔐 Advanced Security** - Domain verification, audit trails, and secure deployment
- **📊 Python Integration** - Compliance dashboards and API interfaces
- **🏗️ Multi-Schema Database** - Specialized schemas for different functional domains

## 🎯 Core Menu Categories

### 👥 User & Group Management (16 operations)
- **Account Discovery & Scanning** - Automated domain account scanning and categorization
- **Account Management** - Individual and bulk user operations
- **Group & License Management** - Comprehensive group membership and license administration
- **Suspended Account Lifecycle** - Complete 8-stage workflow from suspension to deletion
- **Reports & Analytics** - User statistics and lifecycle reporting

### 💾 Data & File Operations (11 operations)
- **File & Drive Operations** - Bulk operations, shared drive management, permissions
- **Analysis & Discovery** - File sharing analysis, account discovery, diagnostics
- **Account List Management** - Database-driven batch operations with progress tracking

### 📊 System & Monitoring (18 operations)
- **Dashboard & Statistics** - System overview (12 options) and statistics & metrics (8 options) 
- **Production-Ready Focus** - Only working features displayed, all placeholders removed
- **Reports & Monitoring** - Activity reports, log management, performance analysis
- **System Administration** - Configuration, maintenance, and backup operations

### 🔐 Security & Compliance (3 operations)
- **SCuBA Compliance Management** - CISA security baseline monitoring and reporting

### ⚙️ Configuration Management
- **External Tools Configuration** - GAM, GYB, rclone domain synchronization
- **System Setup & Settings** - Environment configuration and deployment management

## 🏗️ Revolutionary Architecture

### SQLite-Driven Dynamic Interfaces
- **Zero Hardcoded Menus** - All interfaces generated from database tables
- **Self-Maintaining** - Menus automatically reflect database changes
- **Intelligent Search** - Advanced keyword matching with relevance scoring
- **Database Integration** - Menu choices resolved via database queries
- **Performance Optimized** - Cached search results and indexed lookups

### Multi-Schema Database Design
- **Primary Schema** - Account lifecycle, lists, verification, audit logging
- **Menu Schema** - Dynamic menu system with search optimization  
- **Specialized Schemas** - SCuBA compliance, configuration, security, backups
- **View-Based Search** - Optimized search interface across all data

### Enterprise Security Features
- **Domain Verification** - Automatic verification GAM domain matches configuration
- **Environment Isolation** - All secrets in .env files, nothing hardcoded
- **Complete Audit Trail** - Every operation logged with session correlation
- **SSH Key Deployment** - Secure automated deployment with key management
- **Clean Git History** - No sensitive data in version control

## 📋 Requirements

### Required
- **Linux/macOS** - Primary platforms
- **Bash 4.0+** - Shell environment  
- **GAM** - Google Apps Manager ([GAM7 compatible](https://github.com/GAM-team/GAM))
- **SQLite** - Multi-schema database backend
- **Git** - Version control and deployment

### Optional Advanced Features
- **Python 3.12+** - Compliance modules and dashboard capabilities
- **GYB** - Gmail backup with domain synchronization
- **rclone** - Cloud storage synchronization
- **SSH/expect** - Automated deployment and interactive prompts

## 🚀 Quick Start

```bash
# Clone and setup
git clone git@github.com:mattbaya/gwombat.git
cd gwombat

# Initialize environment
cp .env.template .env
nano .env  # Configure DOMAIN, ADMIN_USER, GAM_PATH, etc.

# Initialize menu database
./shared-utilities/menu_data_loader.sh

# Launch GWOMBAT
./gwombat.sh

# Try the new features:
# - Press 's' for intelligent search
# - Press 'i' for alphabetical index
# - Navigate to User & Group Management for integrated lifecycle
```

## 🔍 Advanced Menu Features

### Intelligent Search System
```bash
# Search examples
s → "user"      # Find all user-related operations
s → "lifecycle" # Find suspended account workflow options
s → "backup"    # Find backup and archival operations
s → "security"  # Find compliance and security features
```

### Menu Database Integration
- **43+ Operations** - Searchable with contextual descriptions
- **Navigation Paths** - Shows exactly how to reach each operation
- **Keyword Optimization** - Smart matching across titles, descriptions, and tags
- **Real-time Results** - Instant search with highlighted matches

## 📚 Documentation

- **[INSTALLATION.md](docs/INSTALLATION.md)** - Comprehensive setup and configuration
- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Production deployment procedures
- **[REQUIREMENTS.md](docs/REQUIREMENTS.md)** - System requirements and dependencies
- **[TESTING_PLAN.md](docs/TESTING_PLAN.md)** - Testing procedures and validation
- **[CLAUDE.md](CLAUDE.md)** - AI development context and architecture

## 🌟 Latest Enhancements (v4.0 - August 2025)

### SQLite Menu Revolution
- **Dynamic Menu Generation** - Complete replacement of hardcoded interfaces
- **Intelligent Search** - Advanced keyword matching across all operations
- **Alphabetical Index** - Complete operation catalog with descriptions
- **Self-Maintaining** - Zero maintenance overhead for menu changes

### Production-Ready Interface (January 2025)
- **"Coming Soon" Removal** - All placeholder options removed from active menus
- **Focused Functionality** - Dashboard & Statistics streamlined to 18 working features
- **Clean User Experience** - No confusing placeholders, only functional options
- **Comprehensive Future Roadmap** - All removed features tracked for future implementation

### Enhanced User Management
- **Integrated Lifecycle** - Suspended account management in User & Group Management
- **20 User Operations** - Comprehensive account, group, and license management
- **Advanced Scanning** - Automated account discovery and categorization

### External Tools Integration
- **Domain Synchronization** - GAM, GYB, rclone all point to same domain
- **Configuration Management** - Centralized external tool setup
- **Verification System** - Automated domain verification and tool status

### Advanced Security
- **Domain Security Verification** - Prevents operations on wrong domains
- **Multi-Schema Architecture** - Specialized databases for different functions
- **Python Integration** - Compliance dashboards and API interfaces

## 📊 Project Statistics

- **9000+ lines** - Main application with dynamic menu system
- **1000+ lines** - Database functions with menu management
- **30+ utility scripts** - Specialized operations and integrations
- **Multi-schema database** - 4+ specialized schemas with 15+ tables
- **43+ operations** - Across 8 functional categories with intelligent search

## 🎯 Why GWOMBAT v4.0?

1. **Revolutionary Interface** - SQLite-driven menus with zero maintenance overhead
2. **Enterprise Scale** - Handles large Google Workspace environments with database persistence
3. **Intelligent Discovery** - Advanced search finds operations instantly
4. **Security First** - Domain verification and comprehensive audit trails
5. **Self-Maintaining** - Database-driven architecture stays current automatically
6. **Integration Ready** - External tools synchronization and Python module support

## 🚀 Future Roadmap

- **Web Dashboard** - Browser interface leveraging Python modules
- **API Integration** - RESTful endpoints for external system integration
- **Workflow Automation** - Scheduled batch operations with cron integration
- **Mobile Interface** - Responsive design for mobile device management
- **AI-Powered Insights** - Machine learning for account lifecycle optimization

---

**GWOMBAT** represents a revolutionary evolution in Google Workspace administration - from simple script collections to enterprise-grade platform with cutting-edge database-driven interfaces, intelligent automation, and robust security features.

The SQLite menu system sets a new standard for admin tool interfaces, providing intelligent search, self-maintaining menus, and zero maintenance overhead.

*For detailed installation instructions, see [docs/INSTALLATION.md](docs/INSTALLATION.md)*