# Azure Automation Setup Guide - SharePoint Download Monitoring

This guide provides step-by-step instructions for setting up the SharePoint Download Monitoring solution using Azure Automation Runbooks, based on the proven working script approach.

## 🎯 Overview

This setup creates an automated solution that:
- ✅ Runs on a schedule in Azure Automation
- ✅ Uses certificate-based authentication (secure)
- ✅ Uploads Excel reports directly to SharePoint
- ✅ Requires specific PowerShell module versions (tested and verified)
- ✅ Uses Azure Automation Variables for configuration

## 📋 Prerequisites

### Azure Requirements
- Azure subscription with Contributor permissions
- Azure Automation Account
- App Registration in Azure AD
- Certificate for authentication (uploaded to Automation Account)

### SharePoint Requirements
- SharePoint Online site for report storage
- Document library for uploads
- Site Collection Administrator permissions

### PowerShell Modules (Exact Versions Required)
- `ExchangeOnlineManagement 3.5.0` ⚠️ CRITICAL - Do not use newer versions
- `Microsoft.Graph.Authentication 2.25.0` ⚠️ CRITICAL - Do not use newer versions
- `ImportExcel` (latest version)

## 🔧 Step 1: Create App Registration

1. **Navigate to Azure Portal** → Azure Active Directory → App registrations
2. **Create new registration:**
   - Name: `SharePoint-Download-Monitor`
   - Supported account types: `Accounts in this organizational directory only`
   - Redirect URI: Leave blank

3. **Note the Application (client) ID** - you'll need this for configuration

4. **Configure API Permissions:**
   ```
   Microsoft Graph:
   - Reports.Read.All (Application)
   - Sites.Read.All (Application)
   - Files.ReadWrite.All (Application)
   
   Office 365 Exchange Online:
   - Exchange.ManageAsApp (Application)
   ```

5. **Grant admin consent** for all permissions

## 🔐 Step 2: Certificate Setup

### Option A: Create Self-Signed Certificate (Development)

```powershell
# Create certificate
$cert = New-SelfSignedCertificate -CertStoreLocation "cert:\CurrentUser\My" -Subject "CN=SharePoint-Monitor" -KeySpec KeyExchange

# Export certificate
Export-Certificate -Cert $cert -FilePath "C:\temp\SharePoint-Monitor.cer"

# Get thumbprint
$cert.Thumbprint
```

### Option B: Use Existing Certificate (Production)

Ensure your certificate meets these requirements:
- Valid for authentication
- Private key available
- Proper subject name
- Not expired

### Upload Certificate to App Registration

1. **In your App Registration** → Certificates & secrets
2. **Upload certificate** (.cer file)
3. **Note the thumbprint** for configuration

## ⚙️ Step 3: Azure Automation Account Setup

### Create Automation Account

1. **Azure Portal** → Create a resource → Automation Account
2. **Configure:**
   - Name: `sharepoint-monitoring-automation`
   - Resource group: Create new or use existing
   - Location: Choose appropriate region
   - Create Azure Run As account: **No** (we'll use certificate auth)

### Install Required Modules

⚠️ **CRITICAL**: Install exact versions to ensure compatibility

```powershell
# In Azure Automation Account → Modules → Browse gallery

# Install ExchangeOnlineManagement 3.5.0
Search: "ExchangeOnlineManagement"
Version: 3.5.0 (MUST be this exact version)

# Install Microsoft.Graph.Authentication 2.25.0  
Search: "Microsoft.Graph.Authentication"
Version: 2.25.0 (MUST be this exact version)

# Install ImportExcel (latest)
Search: "ImportExcel"
Version: Latest available
```

### Upload Certificate

1. **Automation Account** → Certificates → Add a certificate
2. **Upload your certificate** (.pfx file with private key)
3. **Certificate name**: `SharePointMonitorCert`
4. **Note the name** for configuration

## 📊 Step 4: Get SharePoint Site and Drive IDs

### Method 1: Using PowerShell (Recommended)

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Sites.Read.All"

# Get site ID
$SiteUrl = "https://yourtenant.sharepoint.com/sites/yoursite"
$Site = Get-MgSite -SiteId "yourtenant.sharepoint.com:/sites/yoursite"

Write-Host "Site ID: $($Site.Id)"

# Get drive ID for document library
$Drives = Get-MgSiteDrive -SiteId $Site.Id
$ReportsLibrary = $Drives | Where-Object { $_.Name -eq "Documents" -or $_.Name -eq "Your-Library-Name" }

Write-Host "Drive ID: $($ReportsLibrary.Id)"
```

### Method 2: Using Graph Explorer

1. **Navigate to** [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer)
2. **Get Site ID:**
   ```
   GET https://graph.microsoft.com/v1.0/sites/yourtenant.sharepoint.com:/sites/yoursite
   ```
3. **Get Drive ID:**
   ```
   GET https://graph.microsoft.com/v1.0/sites/{site-id}/drives
   ```

## 🔧 Step 5: Configure Automation Variables

In your **Automation Account** → Variables, create these variables:

| Variable Name | Type | Value | Description |
|---------------|------|-------|-------------|
| `AppId` | String | `your-app-registration-client-id` | Application ID from App Registration |
| `TenantName` | String | `yourtenant` | Your M365 tenant name (without .onmicrosoft.com) |
| `TenantID` | String | `your-tenant-guid` | Azure AD Tenant ID |
| `CertificateName` | String | `SharePointMonitorCert` | Name of certificate in Automation Account |
| `SiteID` | String | `your-sharepoint-site-id` | SharePoint site ID for report storage |
| `DriveID` | String | `your-document-library-drive-id` | Drive ID for the target document library |

### Variable Configuration Example:

```powershell
# Example values (replace with your actual values)
AppId: "12345678-1234-1234-1234-123456789012"
TenantName: "contoso"
TenantID: "87654321-4321-4321-4321-210987654321"
CertificateName: "SharePointMonitorCert"
SiteID: "contoso.sharepoint.com,12345678-1234-1234-1234-123456789012,87654321-4321-4321-4321-210987654321"
DriveID: "b!abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
```

## 📝 Step 6: Create Runbook

1. **Automation Account** → Runbooks → Create a runbook
2. **Configuration:**
   - Name: `Monitor-SharePoint-Downloads`
   - Runbook type: `PowerShell`
   - Runtime version: `5.1` (Important for module compatibility)

3. **Copy the updated script** from:
   ```
   scripts/sharepoint-upload/Monitor-SharePointDownloads-SharePointUpload.ps1
   ```

4. **Save and publish** the runbook

## ⏰ Step 7: Schedule the Runbook

1. **Runbook** → Schedules → Add a schedule
2. **Create schedule:**
   - Name: `Daily-SharePoint-Download-Report`
   - Start time: Choose appropriate time
   - Recurrence: `Recurring`
   - Recur every: `1 Day`

3. **Link schedule to runbook**

## 🧪 Step 8: Test the Setup

### Manual Test Run

1. **Runbook** → Start
2. **Monitor output** in the Output tab
3. **Expected output:**
   ```
   ✅ Retrieved configuration from Azure Automation Variables
   📦 Importing required modules with verified versions...
   ✅ ExchangeOnlineManagement 3.5.0 imported successfully
   ✅ Microsoft.Graph.Authentication 2.25.0 imported successfully
   ✅ ImportExcel module imported successfully
   🔐 Using certificate authentication with thumbprint: 12345678...
   🔗 Connecting to Exchange Online...
   ✅ Successfully connected to Exchange Online
   🔗 Connecting to Microsoft Graph...
   ✅ Successfully connected to Microsoft Graph
   🔍 Searching for SharePoint download events...
   📊 Found X download events
   ⚙️ Processing audit data for Excel export...
   ✅ Successfully processed X download events
   📊 Generating Excel report: Logs_2025-09-27.xlsx
   ✅ Successfully generated Excel report with X records
   📤 Uploading Excel report to SharePoint...
   ✅ File 'Logs_2025-09-27.xlsx' uploaded successfully to SharePoint
   🎉 SharePoint Download Monitoring completed successfully!
   ```

### Verify Upload

1. **Navigate to your SharePoint site**
2. **Check the Reports folder** in your document library
3. **Verify the Excel file** was uploaded successfully
4. **Open the file** to confirm data is correct

## 🔍 Troubleshooting

### Common Issues and Solutions

#### ❌ Authentication Failures

**Error**: "Failed to connect to Exchange Online"
**Solution**: 
- Verify TenantName is correct (without .onmicrosoft.com)
- Check certificate thumbprint
- Ensure app has Exchange.ManageAsApp permission

#### ❌ Module Import Errors

**Error**: "Failed to import required modules"
**Solution**:
- Install exact versions: ExchangeOnlineManagement 3.5.0, Microsoft.Graph.Authentication 2.25.0
- Wait for modules to finish installing before running
- Check module installation status in Automation Account

#### ❌ Upload Failures

**Error**: "Upload failed: Forbidden"
**Solution**:
- Verify SiteID and DriveID are correct
- Check app has Sites.Read.All and Files.ReadWrite.All permissions
- Ensure user has permissions to the target library

#### ❌ No Audit Data

**Error**: "Found 0 download events"
**Solution**:
- Audit logging may not be enabled
- Increase DaysBack parameter (default is 14 days)
- Check if there were actual downloads in the time period

### Debug Steps

1. **Check Variables**: Ensure all Automation Variables are set correctly
2. **Verify Permissions**: Confirm app registration has all required permissions
3. **Test Certificate**: Verify certificate is valid and accessible
4. **Module Versions**: Confirm exact versions are installed
5. **Run History**: Check previous run history for patterns

## 🚀 Advanced Configuration

### Custom Parameters

You can customize the script behavior by modifying these parameters in the runbook:

```powershell
# Customize these values in the runbook if needed
$DaysBack = 30           # Look back 30 days instead of 14
$FolderPath = "Reports"  # Change folder name
$TargetSiteIds = @("site1", "site2")  # Monitor specific sites only
```

### Multiple Sites Monitoring

To monitor specific SharePoint sites only:

1. **Get Site IDs** for target sites
2. **Modify the runbook** to include the TargetSiteIds parameter:
   ```powershell
   $TargetSiteIds = @("site-id-1", "site-id-2", "site-id-3")
   ```

### Custom Report Frequency

For different reporting frequencies:
- **Weekly**: Create schedule for every 7 days, set DaysBack to 7
- **Monthly**: Create schedule for every 30 days, set DaysBack to 30
- **Real-time**: Create schedule for every hour, set DaysBack to 1

## 📈 Monitoring and Maintenance

### Regular Checks

1. **Monthly**: Review runbook execution history
2. **Quarterly**: Verify certificates haven't expired
3. **Annually**: Review and update app registration permissions

### Performance Optimization

1. **Large Tenants**: Consider filtering to specific sites
2. **Historical Data**: Archive old reports to prevent storage buildup
3. **Error Handling**: Monitor failed runs and investigate causes

## 🔒 Security Best Practices

1. **Certificate Management**: Use proper certificate lifecycle management
2. **Least Privilege**: Only grant minimum required permissions
3. **Regular Rotation**: Rotate certificates annually
4. **Monitoring**: Set up alerts for failed authentications
5. **Access Review**: Regularly review who has access to reports

---

## 📞 Support

If you encounter issues:

1. **Check the troubleshooting section** above
2. **Review Azure Automation logs** for detailed error messages
3. **Verify all prerequisites** are met
4. **Test with a manual PowerShell session** first
5. **Submit GitHub issues** with full error details

**Remember**: This setup uses proven working module versions and methods. Deviating from the specified versions may cause authentication issues.