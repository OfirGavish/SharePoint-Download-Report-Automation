# Post-Deployment Setup Guide

> ⚠️ **Note**: As of the latest template version, the dashboard files are **automatically uploaded** during deployment using Azure deployment scripts. This guide is only needed for manual deployments or troubleshooting.

## Automatic vs Manual Setup

✅ **Standard "Deploy to Azure" Button**: Dashboard files are automatically downloaded from GitHub and uploaded to your storage account. No manual steps required!

🔧 **Manual/Custom Deployments**: If you deployed the ARM template manually or need to update dashboard files, follow the steps below.

## Step 1: Upload Dashboard Files (Manual Only)

For manual deployments, the ARM template creates the storage account and enables static website hosting, but you'll need to run the upload script:

### Option A: Using PowerShell (Recommended)
```powershell
# Navigate to the deployment folder
cd "C:\path\to\your\repo\deployment"

# Run the upload script
.\upload-dashboard-files.ps1 -StorageAccountName "your-storage-account-name" -ResourceGroupName "your-resource-group-name"
```

### Option B: Using Azure CLI
```bash
# Upload dashboard files to $web container
az storage blob upload-batch --account-name "your-storage-account-name" --destination '$web' --source "../dashboard" --pattern "*.html" --content-type "text/html"
az storage blob upload-batch --account-name "your-storage-account-name" --destination '$web' --source "../dashboard" --pattern "*.css" --content-type "text/css"
az storage blob upload-batch --account-name "your-storage-account-name" --destination '$web' --source "../dashboard" --pattern "*.js" --content-type "application/javascript"
```

### Option C: Using Azure Portal
1. Navigate to your storage account in the Azure Portal
2. Go to **Data storage** > **Containers**
3. Click on the **$web** container
4. Upload the following files from the `dashboard` folder:
   - `index.html`
   - `dashboard.css`
   - `dashboard.js`

## Step 2: Configure PowerShell Scripts

Update the PowerShell monitoring scripts with your storage account details:

1. Open `scripts/SharePoint-Download-Report-AzureStorage.ps1`
2. Update these variables:
   ```powershell
   $StorageAccountName = "your-storage-account-name"
   $ResourceGroupName = "your-resource-group-name"
   ```

## Step 3: Set Up Scheduled Task

Create a scheduled task to run the monitoring script automatically:

```powershell
# Create scheduled task (run as Administrator)
$ScriptPath = "C:\path\to\your\repo\scripts\SharePoint-Download-Report-AzureStorage.ps1"
$TaskName = "SharePoint Download Monitor"

# Create daily task at 6 AM
schtasks /create /tn "$TaskName" /tr "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath`"" /sc daily /st 06:00 /ru SYSTEM
```

## Step 4: Test the Setup

1. **Access the Dashboard**: Navigate to your static website URL (found in the storage account overview)
2. **Run the Script Manually**: Execute the monitoring PowerShell script to generate test data
3. **Verify Data Flow**: Check that data appears in both the storage account and the dashboard

## URLs and Endpoints

After deployment, you'll have these endpoints:
- **Static Website URL**: `https://yourstorageaccount.z6.web.core.windows.net/`
- **Storage Account**: Available in the Azure Portal under your resource group
- **Blob Storage**: Two containers created - `$web` (for dashboard) and `data` (for reports)

## Troubleshooting

### Dashboard Shows No Data
1. Verify the monitoring script has run at least once
2. Check that JSON files exist in the `data` container
3. Ensure CORS is properly configured (handled by ARM template)

### Static Website Not Accessible
1. Confirm static website hosting is enabled in storage account settings
2. Verify dashboard files are uploaded to the `$web` container
3. Check that the index.html file exists in the root of `$web`

### PowerShell Script Errors
1. Ensure you're connected to Azure: `Connect-AzAccount`
2. Verify you have the required PowerShell modules installed
3. Check that the storage account name and resource group are correct

## Next Steps

1. **Customize the Dashboard**: Modify the HTML/CSS/JS files to match your branding
2. **Set Up Alerts**: Configure Azure Monitor alerts for the monitoring script
3. **Scale the Solution**: Consider Azure Functions for serverless execution
4. **Add Authentication**: Implement Azure AD authentication if needed for sensitive data

For additional support, refer to the main README.md file or check the documentation in the `/docs` folder.