# Google Workspace OAuth Troubleshooting Guide

## Common OAuth Authentication Issues

### Error: `admin_policy_enforced`

**Symptoms:**
- GAM OAuth setup fails with "Access blocked: Authorization Error"
- Error message: "Access to your account data is restricted by policies within your organization"
- Error code: `admin_policy_enforced`

**Root Cause:**
Your Google Workspace organization has security policies that prevent GAM from authenticating via OAuth.

---

## Solutions (Choose One)

### Solution 1: Whitelist GAM OAuth Client (Recommended)

**For Google Workspace Super Admins:**

1. **Access Google Admin Console**
   - Go to [admin.google.com](https://admin.google.com)
   - Sign in with Super Admin account

2. **Navigate to API Controls**
   - Go to **Security > API Controls > App access control**
   - Click **Manage Third-Party App Access**

3. **Add GAM to Trusted Apps**
   - Click **Add app > OAuth App ID or client name**
   - Enter GAM's OAuth Client ID:
     ```
     591136899245-3p91hir237nvvn71vkl1vetndgeg360v.apps.googleusercontent.com
     ```
   - Set access to **Trusted**
   - Apply to appropriate organizational units

4. **Alternative Method - By App Name**
   - Search for "GAM" or "Google Apps Manager"
   - If found, set to **Trusted**

### Solution 2: Service Account Authentication

**For Advanced Users:**

1. **Create Service Account**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create new project or use existing
   - Enable Admin SDK API
   - Create service account with domain-wide delegation

2. **Download Service Account Key**
   - Generate and download JSON key file
   - Store securely (never commit to version control)

3. **Configure GAM for Service Account**
   ```bash
   # Set GAM to use service account
   gam oauth create service <path-to-json-key>
   
   # Or configure in GAM config
   echo "service_account_json = /path/to/service-account.json" >> ~/.gam/gam.cfg
   ```

### Solution 3: Domain-Wide Delegation

**For Organizations with Strict Policies:**

1. **Enable Domain-Wide Delegation**
   - In Google Cloud Console, edit your service account
   - Check "Enable Google Workspace Domain-wide Delegation"
   - Note the Client ID

2. **Authorize in Google Workspace**
   - Go to **Security > API Controls > Domain-wide delegation**
   - Add Client ID with required scopes:
     ```
     https://www.googleapis.com/auth/admin.directory.user
     https://www.googleapis.com/auth/admin.directory.group
     https://www.googleapis.com/auth/admin.directory.orgunit
     https://www.googleapis.com/auth/admin.directory.domain
     https://www.googleapis.com/auth/admin.directory.device
     https://www.googleapis.com/auth/apps.groups.settings
     ```

---

## Temporary Workarounds

### Option 1: Different Admin Account
- Use an admin account that's not subject to organizational OAuth restrictions
- Often works with accounts in different OUs

### Option 2: External Configuration
- Configure GAM on a machine outside organizational network restrictions
- Copy configuration files to restricted environment

### Option 3: Relaxed Policies (Temporary)
⚠️ **Security Impact: High - Use with caution**

1. **Less Secure Apps Setting**
   - Go to **Security > Less secure apps**
   - Enable "Allow users to manage their access to less secure apps"
   - **Remember to disable after GAM setup**

2. **OAuth App Verification**
   - Go to **Security > API Controls**
   - Temporarily change "Configure new apps" to "Allowed"
   - **Revert to restricted after setup**

---

## GWOMBAT Integration

### Automatic Detection

GWOMBAT automatically detects OAuth authentication failures and provides these options:

1. **Guided Troubleshooting** - Step-by-step OAuth policy resolution
2. **Alternative Authentication** - Service account setup guidance
3. **Admin Contact Information** - Instructions for requesting policy changes

### Error Recovery

When OAuth fails, GWOMBAT will:
- Display specific error details
- Provide relevant troubleshooting steps
- Offer alternative authentication methods
- Guide you through policy request process

---

## Prevention

### For New Deployments

1. **Plan OAuth Strategy**
   - Identify organizational OAuth policies before GAM setup
   - Choose appropriate authentication method (OAuth vs Service Account)
   - Coordinate with Google Workspace admins

2. **Document Requirements**
   - List required OAuth scopes for GAM
   - Identify trusted applications policy needs
   - Plan service account strategy if needed

### For Organizations

1. **Create GAM Policy**
   - Standardize on OAuth client whitelisting approach
   - Document service account creation process
   - Establish approval workflow for third-party tools

2. **Security Best Practices**
   - Use service accounts for production environments
   - Regularly audit trusted applications
   - Implement least-privilege access principles

---

## Advanced Troubleshooting

### Debug OAuth Flow

```bash
# Test GAM OAuth manually
gam oauth info

# Verbose OAuth debugging
gam config debug_level oauth

# Check current authentication status
gam info domain
```

### Common OAuth Scopes Required by GAM

```
https://www.googleapis.com/auth/admin.directory.user
https://www.googleapis.com/auth/admin.directory.group
https://www.googleapis.com/auth/admin.directory.orgunit
https://www.googleapis.com/auth/admin.directory.domain
https://www.googleapis.com/auth/admin.directory.device
https://www.googleapis.com/auth/apps.groups.settings
https://www.googleapis.com/auth/gmail.settings.basic
https://www.googleapis.com/auth/gmail.settings.sharing
```

### Log Analysis

```bash
# Check GAM debug logs
cat ~/.gam/debug.log | grep -i oauth

# Check GWOMBAT authentication logs
cat local-config/logs/operations-$(date +%Y%m%d).log | grep -i auth
```

---

## Getting Help

### Contact Information

1. **Google Workspace Admin**
   - Request OAuth policy changes
   - Service account creation assistance
   - Domain-wide delegation setup

2. **GWOMBAT Support**
   - OAuth integration issues
   - Alternative authentication setup
   - Configuration troubleshooting

### Useful Resources

- [GAM OAuth Documentation](https://github.com/GAM-team/GAM/wiki/OAuth)
- [Google Workspace API Controls](https://support.google.com/a/answer/7281227)
- [Service Account Authentication](https://developers.google.com/identity/protocols/oauth2/service-account)
- [Domain-Wide Delegation](https://developers.google.com/admin-sdk/directory/v1/guides/delegation)

---

## Error Reference

| Error Code | Description | Solution |
|------------|-------------|----------|
| `admin_policy_enforced` | OAuth blocked by organizational policy | Whitelist GAM OAuth client |
| `access_denied` | User denied OAuth consent | Re-run OAuth setup |
| `invalid_client` | OAuth client not recognized | Check GAM installation |
| `unauthorized_client` | Client not authorized for requested scopes | Add required scopes to trusted app |
| `invalid_grant` | OAuth token expired or invalid | Re-run `gam oauth create` |

This guide ensures GWOMBAT users can successfully authenticate GAM regardless of organizational OAuth policies.