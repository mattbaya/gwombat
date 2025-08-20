# GWOMBAT Test Domain Management

## Overview

GWOMBAT's Test Domain Management system allows you to safely switch between production and test Google Workspace domains for development, testing, and training without affecting your production environment.

## Features

### 🧪 Multi-Domain Configuration
- **Production Domain** - Your live Google Workspace domain
- **3 Test Domains** - Configure up to 3 different test domains
- **Safe Switching** - Automatic configuration backup before domain changes
- **Independent Settings** - Each domain has its own GAM path, admin user, and settings

### 🛡️ Safety Features
- **Automatic Backups** - Configuration backed up before any domain switch
- **GAM Connectivity Testing** - Verify domain access before switching
- **Test Mode Indicators** - Clear visual indicators when in test mode
- **Enhanced Confirmations** - Extra safety prompts for destructive operations
- **Production Protection** - Additional safeguards when switching back to production

### 🔄 Configuration Management
- **Persistent Settings** - Domain configurations saved between sessions
- **Backup/Restore** - Full configuration history and rollback capability
- **Environment Isolation** - Test domains don't affect production data
- **Automated Verification** - Domain connectivity testing for all configured domains

## Accessing Test Domain Management

Navigate to: **Configuration → Test Domain Management**

```bash
./gwombat.sh
# Select: Configuration
# Select: Test Domain Management (option 3)
```

## Domain Management Options

### 1. 🏢 Switch to Production Domain
Switches to your production Google Workspace domain.
- Restores production GAM configuration
- Disables test mode safety features  
- Confirms GAM connectivity to production domain

### 2-4. 🧪 Switch to Test Domains 1-3
Switches to configured test domains.
- Automatically enables test mode safety features
- Updates GAM configuration for test domain
- Shows test mode warnings and confirmations

### 5-7. ⚙️ Configure Test Domains 1-3  
Interactive configuration of test domain settings:
- Google Workspace domain name
- Admin user account
- GAM executable path
- Descriptive name/purpose

### 8. 📋 View All Domain Configurations
Displays complete overview of all configured domains:
- Current active domain mode
- All domain configurations (production + test)
- GAM paths and admin users
- Test mode status

### 9. 🔍 Test GAM Connectivity
Tests GAM connectivity for all configured domains:
- Verifies GAM authentication
- Tests domain access permissions
- Reports connectivity status for each domain

### 10. 🛡️ Configure Test Mode Safety Settings
Configures safety features for test domains:
- **Dry Run Mode** - Preview operations without execution
- **Confirmation Required** - Extra prompts for operations
- **Enhanced Logging** - Detailed operation logging in test mode

### 11. 💾 Backup/Restore Domain Configurations
Manages configuration backups:
- Create manual configuration backups
- Restore from previous configuration backup
- List available configuration backups

## Configuration File Structure

### Test Domain Configuration (`local-config/test-domains.env`)
```bash
# Production domain (current active domain)
PRODUCTION_DOMAIN="your-domain.edu"
PRODUCTION_ADMIN_USER="admin@your-domain.edu"
PRODUCTION_GAM_PATH="/usr/local/bin/gam"

# Test Domain 1
TEST_DOMAIN_1="test1.your-domain.edu"
TEST_DOMAIN_1_ADMIN_USER="testadmin@test1.your-domain.edu"
TEST_DOMAIN_1_GAM_PATH="/usr/local/bin/gam-test1"
TEST_DOMAIN_1_DESCRIPTION="Development Test Domain"

# Test Domain 2  
TEST_DOMAIN_2="sandbox.your-domain.edu"
TEST_DOMAIN_2_ADMIN_USER="admin@sandbox.your-domain.edu"
TEST_DOMAIN_2_GAM_PATH="/usr/local/bin/gam-sandbox"
TEST_DOMAIN_2_DESCRIPTION="Staging Test Domain"

# Test Domain 3
TEST_DOMAIN_3=""
TEST_DOMAIN_3_ADMIN_USER=""
TEST_DOMAIN_3_GAM_PATH=""
TEST_DOMAIN_3_DESCRIPTION="Sandbox Test Domain"

# Current active domain mode (production, test1, test2, test3)
ACTIVE_DOMAIN_MODE="production"

# Test mode safety settings
TEST_MODE_ENABLED="false"
TEST_MODE_DRY_RUN="true"  
TEST_MODE_CONFIRMATION_REQUIRED="true"
```

### Environment Configuration (`local-config/.env`)
The main environment file is automatically updated when switching domains:
```bash
DOMAIN="current-active-domain.edu"
ADMIN_USER="admin@current-active-domain.edu" 
GAM_PATH="/path/to/current/gam"
# ... other settings remain unchanged
```

## Domain Switching Process

### 1. Pre-Switch Backup
```bash
# Automatic backup creation
backup_file=".env.backup.20250819_103045"
```

### 2. Configuration Update  
```bash
# Update environment variables
DOMAIN="test1.your-domain.edu"
ADMIN_USER="testadmin@test1.your-domain.edu"
GAM_PATH="/usr/local/bin/gam-test1"
ACTIVE_DOMAIN_MODE="test1"
TEST_MODE_ENABLED="true"
```

### 3. GAM Connectivity Verification
```bash
# Test GAM connection to new domain
gam info domain
# Verify authentication and permissions
```

### 4. Confirmation and Status Display
```bash
✓ Switched to test domain 1: test1.your-domain.edu
⚠️ TEST MODE ENABLED - Operations will be logged and confirmed
```

## Test Mode Safety Features

### Enhanced Confirmations
When in test mode, destructive operations require additional confirmation:
```bash
⚠️ TEST MODE ACTIVE - This operation will affect test domain: test1.your-domain.edu
Confirm operation? (y/N):
```

### Dry Run Mode (Optional)
When enabled, operations show what would be done without executing:
```bash
[DRY RUN] Would execute: gam user testuser@test1.domain.edu suspend
[DRY RUN] No actual changes made
```

### Visual Indicators
- **Menu Headers** show current domain mode
- **Test Mode Warnings** appear before operations
- **Domain Display** shows active domain in status

## Use Cases

### 1. Development Testing
```bash
# Switch to development domain
Configuration → Test Domain Management → Switch to Test Domain 1

# Test new features safely
# - User management operations
# - Group modifications  
# - Permission changes
# - Script testing

# Switch back to production when done
Configuration → Test Domain Management → Switch to Production Domain
```

### 2. Training Environment
```bash
# Configure training domain
Configuration → Test Domain Management → Configure Test Domain 2
# Domain: training.your-domain.edu
# Admin: trainer@training.your-domain.edu  
# Description: Training Test Domain

# Switch to training domain
Configuration → Test Domain Management → Switch to Test Domain 2

# Conduct training sessions safely
# Switch back when training complete
```

### 3. Staging/QA Testing
```bash
# Use test domain 3 for staging
Configuration → Test Domain Management → Configure Test Domain 3
# Domain: staging.your-domain.edu
# Admin: qa@staging.your-domain.edu
# Description: QA Staging Environment

# Test deployment procedures
# Validate changes before production
```

## Best Practices

### Domain Configuration
1. **Use Clear Names** - Make test domain purposes obvious
2. **Separate GAM Instances** - Use different GAM installations for each domain
3. **Test Connectivity** - Always test GAM connection after configuration
4. **Document Purposes** - Use descriptive names for each test domain

### Safety Procedures  
1. **Always Backup** - Automatic backups are created, but manual backups are good practice
2. **Verify Domain** - Check domain display before operations
3. **Test Mode First** - Use dry run mode for unfamiliar operations
4. **Limited Scope** - Keep test operations focused and documented

### Production Protection
1. **Double-Check Domain** - Verify you're in the right domain before operations
2. **Manual Verification** - When switching to production, manually verify critical settings
3. **Staged Rollout** - Test changes in test domains first
4. **Backup Production** - Always backup production config before testing

## Troubleshooting

### Common Issues

#### "GAM connection failed"
- **Cause**: GAM not authenticated for target domain
- **Solution**: Run `gam info domain` manually to diagnose authentication
- **Check**: Verify GAM path is correct for target domain

#### "Domain not configured"
- **Cause**: Attempting to switch to unconfigured test domain
- **Solution**: Use "Configure Test Domain" option first
- **Verify**: Check test-domains.env has required settings

#### "Configuration backup failed"
- **Cause**: Permissions issue in local-config directory
- **Solution**: Check file permissions on local-config/
- **Alternative**: Create manual backup before switching

#### "Test mode not working"
- **Cause**: Test mode settings not configured properly
- **Solution**: Use "Configure Test Mode Safety Settings" option
- **Check**: Verify TEST_MODE_ENABLED="true" in test-domains.env

### GAM Authentication Issues
Each domain requires separate GAM authentication:

```bash
# Authenticate GAM for each domain
gam info domain  # Should show current domain
gam oauth create  # If authentication needed
```

### Recovery Procedures
If domain switching fails:

1. **Check Backup Files**
   ```bash
   ls local-config/*.backup.*
   # Restore from most recent backup
   ```

2. **Manual Configuration Reset**  
   ```bash
   # Edit local-config/.env manually
   # Restore known-good values
   ```

3. **Test Mode Disable**
   ```bash
   # Edit local-config/test-domains.env
   ACTIVE_DOMAIN_MODE="production"
   TEST_MODE_ENABLED="false"
   ```

## Advanced Configuration

### Multiple GAM Installations
For complete isolation, use separate GAM installations:

```bash
# Production GAM
/usr/local/bin/gam-prod/gam

# Test Domain 1 GAM  
/usr/local/bin/gam-test1/gam

# Test Domain 2 GAM
/usr/local/bin/gam-test2/gam
```

### Automated Testing Integration
Test domain management can be integrated with automated testing:

```bash
# Switch to test domain programmatically
source shared-utilities/test_domain_manager.sh
switch_to_domain "test1"

# Run tests
./run_tests.sh

# Switch back to production
switch_to_domain "production"
```

### Configuration Templates
Create templates for common test domain setups:

```bash
# Development template
TEST_DOMAIN_X="dev.your-domain.edu"
TEST_DOMAIN_X_ADMIN_USER="developer@dev.your-domain.edu"
TEST_DOMAIN_X_DESCRIPTION="Development Environment"

# QA template  
TEST_DOMAIN_Y="qa.your-domain.edu"
TEST_DOMAIN_Y_ADMIN_USER="qa@qa.your-domain.edu"  
TEST_DOMAIN_Y_DESCRIPTION="QA Testing Environment"
```

## Security Considerations

### Access Control
- **Admin Permissions** - Test domains should use separate admin accounts
- **Scope Limitation** - Limit test domain GAM permissions  
- **Audit Logging** - Enhanced logging in test mode helps track changes

### Data Protection
- **Production Isolation** - Test domains cannot access production data
- **Backup Verification** - Verify backups before major domain switches
- **Configuration Security** - Protect test-domains.env file permissions

### Compliance
- **Change Documentation** - Test mode operations are logged for audit
- **Approval Processes** - Production switches can require additional approval
- **Access Reviews** - Regular review of test domain access and configuration

---

Test Domain Management enables safe development and testing workflows while protecting production Google Workspace environments.