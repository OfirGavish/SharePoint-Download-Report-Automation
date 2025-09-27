# Upload Dashboard Files to Azure Storage Static Website
# This script uploads the dashboard files to the $web container after ARM template deployment

param(
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$DashboardPath = "..\dashboard"
)

# Check if Azure PowerShell module is installed
if (!(Get-Module -ListAvailable -Name Az.Storage)) {
    Write-Host "Installing Azure PowerShell Az.Storage module..." -ForegroundColor Yellow
    Install-Module -Name Az.Storage -Force -AllowClobber
}

# Import required modules
Import-Module Az.Storage

try {
    Write-Host "Connecting to Azure..." -ForegroundColor Green
    
    # Get storage account context
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $ctx = $storageAccount.Context
    
    Write-Host "Storage account '$StorageAccountName' found successfully." -ForegroundColor Green
    
    # Verify static website is enabled
    $staticWebsite = Get-AzStorageServiceProperty -ServiceType Blob -Context $ctx
    if ($staticWebsite.StaticWebsite.Enabled) {
        Write-Host "Static website hosting is enabled." -ForegroundColor Green
    } else {
        Write-Warning "Static website hosting is not enabled. Enabling now..."
        Enable-AzStorageStaticWebsite -Context $ctx -IndexDocument "index.html" -ErrorDocument404Path "error.html"
    }
    
    # Check if dashboard files exist
    $dashboardFiles = @(
        @{LocalPath = "$DashboardPath\index.html"; BlobPath = "index.html"},
        @{LocalPath = "$DashboardPath\dashboard.css"; BlobPath = "dashboard.css"},
        @{LocalPath = "$DashboardPath\dashboard.js"; BlobPath = "dashboard.js"}
    )
    
    Write-Host "Uploading dashboard files to `$web container..." -ForegroundColor Green
    
    foreach ($file in $dashboardFiles) {
        if (Test-Path $file.LocalPath) {
            Write-Host "  Uploading $($file.BlobPath)..." -ForegroundColor Yellow
            
            # Determine content type
            $contentType = switch ([System.IO.Path]::GetExtension($file.LocalPath)) {
                ".html" { "text/html" }
                ".css" { "text/css" }
                ".js" { "application/javascript" }
                default { "application/octet-stream" }
            }
            
            # Upload file
            Set-AzStorageBlobContent -File $file.LocalPath -Container "`$web" -Blob $file.BlobPath -Context $ctx -Properties @{"ContentType" = $contentType} -Force
            Write-Host "  ✓ $($file.BlobPath) uploaded successfully" -ForegroundColor Green
        } else {
            Write-Warning "File not found: $($file.LocalPath)"
        }
    }
    
    # Get the static website URL
    $webEndpoint = $storageAccount.PrimaryEndpoints.Web
    Write-Host "`n🎉 Dashboard deployment completed successfully!" -ForegroundColor Green
    Write-Host "Static website URL: $webEndpoint" -ForegroundColor Cyan
    Write-Host "`nYou can now access your SharePoint Download Monitoring Dashboard at the URL above." -ForegroundColor Green
    
} catch {
    Write-Error "Failed to upload dashboard files: $($_.Exception.Message)"
    exit 1
}