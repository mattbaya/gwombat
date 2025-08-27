# Drive API Troubleshooting Guide

## Issue: "Drive API v3 Service/App not enabled"

### Symptoms
- Shared Drive Operations menu fails to load shared drives
- Dashboard shows "Drive API v3 not enabled" instead of drive count
- GAM commands like `gam print shareddrives` fail with error:
  ```
  User: admin@domain.com, Drive API v3 Service/App not enabled
  ```

### Root Cause
The Google Drive API v3 service is not enabled in the Google Cloud project that GAM uses for authentication.

### Solution

#### Method 1: Google Cloud Console (Recommended)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your GAM project (check with `gam info project`)
3. Navigate to **APIs & Services** > **Library**
4. Search for **"Google Drive API"**
5. Click on **"Google Drive API"** and click **"Enable"**

#### Method 2: gcloud CLI (Advanced)
If you have gcloud CLI configured:
```bash
# Set the project (get project ID from 'gam info project')
gcloud config set project YOUR_PROJECT_ID

# Enable the Drive API
gcloud services enable drive.googleapis.com
```

### Verification
After enabling the API:
1. Wait 5-10 minutes for changes to propagate
2. Test with: `gam print shareddrives`
3. Should return CSV header and shared drive data (if any exist)

### Expected Output After Fix
```bash
$ gam print shareddrives
User,id,name
horace@domain.com,1BxYz...,Marketing Team Drive
horace@domain.com,2CyZa...,IT Department
```

### GWOMBAT Integration
Once fixed, GWOMBAT will:
- Display actual shared drive count in Dashboard
- Enable all Shared Drive Operations menu functions
- Allow shared drive management and permissions

### Related GAM Commands That Require Drive API
- `gam print shareddrives`
- `gam create shareddrive`
- `gam update shareddrive`
- `gam delete shareddrive`
- `gam show shareddrive`

### Prevention
When setting up GAM initially, ensure Drive API is enabled along with other required APIs:
- Admin SDK API
- Drive API v3
- Groups Settings API
- Gmail API (if using email features)

This prevents Drive-related functionality issues from occurring.