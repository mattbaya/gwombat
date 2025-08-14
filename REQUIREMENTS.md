# GWOMBAT System Requirements

**GWOMBAT**: Google Workspace Optimization, Management, Backups And Taskrunner

## Required Dependencies

### Core System Requirements
- **Bash 4.0+** - Shell scripting environment
- **Linux/macOS** - Tested on CentOS, Ubuntu, and macOS
- **Internet connectivity** - Required for Google Workspace API access

### Essential Tools
- **GAM (Google Apps Manager)** - Primary Google Workspace interface
  - Version: Latest recommended (GAMadv-XTD3 preferred)
  - Installation: https://github.com/taers232c/GAMADV-XTD3
- **SQLite 3** - Database backend for persistent state
- **Git** - Version control for deployments
- **SSH** - Secure deployment and remote access

### Development/Deployment Tools (Optional)
- **expect** - SSH key password automation (deployment only)
- **curl/wget** - File downloads and web requests
- **jq** - JSON processing (if available)

## Installation Commands

### CentOS/RHEL/Rocky Linux
```bash
# Essential packages
sudo yum install -y sqlite git openssh-clients bash

# Optional deployment tools
sudo yum install -y expect curl wget

# GAM installation (separate process)
# Follow: https://github.com/taers232c/GAMADV-XTD3/wiki/How-to-Install-Advanced-GAM
```

### Ubuntu/Debian
```bash
# Essential packages
sudo apt-get update
sudo apt-get install -y sqlite3 git openssh-client bash

# Optional deployment tools
sudo apt-get install -y expect curl wget jq

# GAM installation (separate process)
# Follow: https://github.com/taers232c/GAMADV-XTD3/wiki/How-to-Install-Advanced-GAM
```

### macOS (Homebrew)
```bash
# Essential packages
brew install sqlite git bash

# Optional deployment tools
brew install expect curl wget jq

# GAM installation (separate process)
# Follow: https://github.com/taers232c/GAMADV-XTD3/wiki/How-to-Install-Advanced-GAM
```

## GAM (Google Apps Manager) Setup

### 1. Install GAM
Choose one of these GAM variants:
- **GAMadv-XTD3** (Recommended): Full-featured, actively maintained
- **GAMADV-X**: Alternative with similar features
- **Legacy GAM**: Basic functionality (not recommended for new installations)

### 2. Configure GAM Authentication
```bash
# Initialize GAM OAuth (one-time setup)
gam oauth create

# Verify installation
gam version
gam info domain
```

### 3. Set GAM Path
Update your environment configuration:
```bash
# In server.env
GAM_PATH="/path/to/your/gam"  # Common: /usr/local/bin/gam
```

## Google Workspace Requirements

### API Access
- **Admin SDK API** - User and group management
- **Drive API** - File access and manipulation
- **Directory API** - Organizational unit management

### Service Account (Recommended)
- Service account with domain-wide delegation
- Required scopes:
  - `https://www.googleapis.com/auth/admin.directory.user`
  - `https://www.googleapis.com/auth/admin.directory.group`
  - `https://www.googleapis.com/auth/admin.directory.orgunit`
  - `https://www.googleapis.com/auth/drive`

### Admin Permissions
The account running GAM requires:
- **Super Admin** privileges (recommended)
- Or specific admin roles:
  - User Management Admin
  - Groups Admin
  - Organizational Unit Admin

## File System Requirements

### Directory Structure
```
/path/to/gwombat/
├── gwombat.sh               # Main application
├── database_functions.sh    # Database operations
├── database_schema.sql      # SQLite schema
├── server.env              # Server configuration
├── logs/                   # Application logs
├── reports/                # Generated reports
├── tmp/                    # Temporary files
└── backups/                # Data backups
```

### Permissions
- **Read/Write access** to application directory
- **Execute permissions** on shell scripts
- **SQLite database** write permissions

### Disk Space
- **Minimum**: 100MB for application and basic logs
- **Recommended**: 1GB+ for extensive logging and reports
- **Database growth**: ~1KB per account record

## Network Requirements

### Outbound Connections
- **HTTPS (443)** to Google APIs:
  - `www.googleapis.com`
  - `admin.googleapis.com`
  - `oauth2.googleapis.com`

### SSH (Deployment Only)
- **SSH access** to production servers
- **Port 22** (or custom SSH port)
- **SSH key authentication** (recommended)

## Performance Considerations

### System Resources
- **RAM**: 512MB minimum, 2GB+ recommended for large domains
- **CPU**: Single core sufficient, multi-core improves batch operations
- **Concurrent Operations**: Limited by Google API quotas

### Google API Limits
- **Queries per second**: Varies by API (typically 100-1000 QPS)
- **Daily quotas**: Usually sufficient for normal operations
- **Batch size**: Recommended 100 accounts per batch operation

## Security Requirements

### File Permissions
```bash
# Secure configuration files
chmod 600 server.env .env
chmod 700 logs/ tmp/ backups/
chmod 755 *.sh
```

### Environment Variables
- **No secrets in code** - All credentials in .env files
- **Gitignore sensitive files** - .env, *.db, logs/
- **SSH key protection** - Password-protected deployment keys

### Audit Logging
- **Operation logging** enabled by default
- **Session tracking** with unique identifiers
- **Change auditing** for all account modifications

## Troubleshooting

### Common Issues

**GAM not found**
```bash
# Check installation
which gam
gam version

# Update PATH or GAM_PATH in server.env
```

**SQLite missing**
```bash
# Check installation
which sqlite3
sqlite3 --version

# Install per platform instructions above
```

**Permission denied**
```bash
# Fix script permissions
chmod +x gwombat.sh database_functions.sh

# Fix directory permissions
chmod 755 logs reports tmp backups
```

**Database initialization fails**
```bash
# Check SQLite installation
command -v sqlite3

# Check schema file exists
ls -la database_schema.sql

# Check write permissions
touch test.db && rm test.db
```

### Getting Help
- **Application logs**: Check `logs/` directory for errors
- **GAM debugging**: Add `-d` flag to GAM commands
- **Verbose mode**: Enable debug logging in configuration

## Version Compatibility

### Tested Environments
- **CentOS 7/8/Stream** - Fully supported
- **Ubuntu 18.04/20.04/22.04** - Fully supported
- **macOS 10.15+** - Development/testing
- **Rocky Linux 8/9** - Fully supported

### Minimum Versions
- **Bash**: 4.0+ (for associative arrays)
- **SQLite**: 3.6+ (for foreign key support)
- **Git**: 2.0+ (for deployment features)
- **GAM**: Any modern version (GAMadv-XTD3 recommended)

This requirements document ensures proper setup and helps diagnose common installation issues.