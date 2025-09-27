# Link Update Guide for SharePoint Download Report Article

## Required Link Updates

The original article needs to have all `mscloudninja.azureedge.net` CDN links replaced with GitHub repository raw URLs.

### Replace Old CDN Links With:

**Base GitHub URL:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/`

### PowerShell Scripts:
- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/Monitor-SharePointDownloads-AzureStorage.ps1`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/scripts/Monitor-SharePointDownloads-AzureStorage.ps1`

- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/Monitor-SharePointDownloads-SharePointUpload.ps1`  
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/scripts/Monitor-SharePointDownloads-SharePointUpload.ps1`

### Dashboard Files:
- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/dashboard.html`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/dashboard/index.html`

- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/dashboard.css`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/dashboard/dashboard.css`

- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/dashboard.js`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/dashboard/dashboard.js`

### ARM Templates:
- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/azuredeploy.json`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/deployment/azuredeploy.json`

- **Old:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/azuredeploy.parameters.json`
- **New:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/deployment/azuredeploy.parameters.json`

### Deploy to Azure Button:
Add this Deploy to Azure button to the article:

```html
<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fyour-username%2Fsharepoint-download-automation%2Fmain%2Fdeployment%2Fazuredeploy.json" target="_blank">
    <img src="https://aka.ms/deploytoazurebutton" alt="Deploy to Azure"/>
</a>
```

## Search and Replace Instructions

1. **Find all instances of:** `https://mscloudninja.azureedge.net/wp-content/uploads/2024/10/`
2. **Replace with:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/scripts/` (for .ps1 files)
3. **Replace with:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/dashboard/` (for dashboard files)
4. **Replace with:** `https://raw.githubusercontent.com/your-username/sharepoint-download-automation/main/deployment/` (for ARM templates)

## Repository Setup Instructions

1. **Create GitHub Repository:**
   - Repository name: `sharepoint-download-automation`
   - Make repository public for raw file access
   - Copy all files from the workspace to the repository

2. **Update URLs:**
   - Replace `your-username` with your actual GitHub username
   - Update the Deploy to Azure button URL in the ARM template

3. **Test Links:**
   - Verify all raw GitHub URLs are accessible
   - Test the Deploy to Azure button functionality
   - Confirm dashboard loads and functions properly

## Benefits of GitHub Migration

✅ **Version Control** - Track changes and improvements
✅ **Community Contributions** - Allow others to contribute
✅ **Reliability** - GitHub's global CDN infrastructure  
✅ **Professional Presentation** - Proper repository structure
✅ **One-Click Deployment** - Deploy to Azure button functionality
✅ **Documentation** - Comprehensive README and guides
✅ **Issue Tracking** - Built-in bug reporting and feature requests