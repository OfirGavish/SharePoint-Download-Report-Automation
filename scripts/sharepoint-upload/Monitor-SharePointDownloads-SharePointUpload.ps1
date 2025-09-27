#Requires -Version 5.1
<#
.SYNOPSIS
    SharePoint Download Monitoring Script - SharePoint Upload Option (Azure Automation Compatible)
    
.DESCRIPTION
    Monitors SharePoint download activity and uploads Excel reports to SharePoint document libraries.
    This script is optimized for Azure Automation Runbooks and supports both manual execution and automation.
    Based on proven working script for reliable SharePoint upload functionality.
    
.PARAMETER TenantId
    Azure AD Tenant ID (optional if using Azure Automation Variables)
    
.PARAMETER TenantName
    Tenant name for Exchange Online connection (optional if using Azure Automation Variables)
    
.PARAMETER AppId  
    Application (Client) ID from App Registration (optional if using Azure Automation Variables)
    
.PARAMETER CertificateThumbprint
    Certificate thumbprint for authentication (optional if using Azure Automation Variables)
    
.PARAMETER CertificateName
    Certificate name in Azure Automation (optional if using Azure Automation Variables)
    
.PARAMETER SiteId
    SharePoint site ID where reports will be uploaded (optional if using Azure Automation Variables)
    
.PARAMETER DriveId
    SharePoint drive ID for the target document library (optional if using Azure Automation Variables)
    
.PARAMETER FolderPath
    Folder path within the document library for reports (default: 'Reports')
    
.PARAMETER DaysBack
    Number of days to look back for audit logs (default: 14)
    
.PARAMETER TargetSiteIds
    Comma-separated list of specific site IDs to monitor (optional - monitors all sites if not specified)
    
.EXAMPLE
    # Azure Automation Runbook execution (uses Automation Variables)
    .\Monitor-SharePointDownloads-SharePointUpload.ps1
    
.EXAMPLE
    # Manual execution with parameters
    .\Monitor-SharePointDownloads-SharePointUpload.ps1 -TenantId "your-tenant-id" -AppId "your-app-id" -CertificateThumbprint "your-cert-thumbprint" -SiteId "your-site-id" -DriveId "your-drive-id"
    
.NOTES
    Author: Ofir Gavish, Eitan Talmi, and Community Contributors
    Version: 2.1 - Azure Automation Optimized
    
    VERIFIED MODULE REQUIREMENTS (tested and working):
    - ExchangeOnlineManagement 3.5.0
    - Microsoft.Graph.Authentication 2.25.0  
    - ImportExcel (latest)
    
    These specific versions are CRITICAL for reliable authentication in Azure Automation.
    
    AZURE AUTOMATION VARIABLES REQUIRED:
    - AppId: Application ID from App Registration
    - TenantName: Your M365 tenant name (e.g., 'contoso')
    - TenantID: Azure AD Tenant ID
    - CertThumbprint: Certificate thumbprint OR CertificateName
    - CertificateName: Name of certificate in Automation Account
    - SiteID: Target SharePoint site ID for reports
    - DriveID: Target drive ID within the site
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantName,
    
    [Parameter(Mandatory = $false)]
    [string]$AppId,
    
    [Parameter(Mandatory = $false)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory = $false)]
    [string]$CertificateName,
    
    [Parameter(Mandatory = $false)]
    [string]$SiteId,
    
    [Parameter(Mandatory = $false)]
    [string]$DriveId,
    
    [Parameter(Mandatory = $false)]
    [string]$FolderPath = "Reports",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 14,
    
    [Parameter(Mandatory = $false)]
    [string[]]$TargetSiteIds
)

# Get variables from Azure Automation if running in automation context
try {
    if (-not $AppId) { $AppId = Get-AutomationVariable -Name 'AppId' -ErrorAction SilentlyContinue }
    if (-not $TenantName) { $TenantName = Get-AutomationVariable -Name 'TenantName' -ErrorAction SilentlyContinue }
    if (-not $TenantId) { $TenantId = Get-AutomationVariable -Name 'TenantID' -ErrorAction SilentlyContinue }
    if (-not $CertificateThumbprint) { $CertificateThumbprint = Get-AutomationVariable -Name 'CertThumbprint' -ErrorAction SilentlyContinue }
    if (-not $CertificateName) { $CertificateName = Get-AutomationVariable -Name 'CertificateName' -ErrorAction SilentlyContinue }
    if (-not $SiteId) { $SiteId = Get-AutomationVariable -Name 'SiteID' -ErrorAction SilentlyContinue }
    if (-not $DriveId) { $DriveId = Get-AutomationVariable -Name 'DriveID' -ErrorAction SilentlyContinue }
    
    Write-Output "✅ Retrieved configuration from Azure Automation Variables"
}
catch {
    Write-Output "ℹ️ Not running in Azure Automation context or variables not configured"
}

# Import required modules with version verification
try {
    Write-Output "📦 Importing required modules with verified versions..."
    
    # Import ExchangeOnlineManagement 3.5.0 (CRITICAL - tested working version)
    Import-Module ExchangeOnlineManagement -RequiredVersion 3.5.0 -Force -ErrorAction Stop
    Write-Output "✅ ExchangeOnlineManagement 3.5.0 imported successfully"
    
    # Import Microsoft.Graph.Authentication 2.25.0 (CRITICAL - tested working version)  
    Import-Module Microsoft.Graph.Authentication -RequiredVersion 2.25.0 -Force -ErrorAction Stop
    Write-Output "✅ Microsoft.Graph.Authentication 2.25.0 imported successfully"
    
    # Import ImportExcel for Excel report generation
    Import-Module ImportExcel -Force -ErrorAction Stop
    Write-Output "✅ ImportExcel module imported successfully"
    
    Write-Output "🔧 All required modules loaded with verified working versions"
}
catch {
    Write-Error "❌ CRITICAL ERROR - Failed to import required modules: $($_.Exception.Message)"
    Write-Error "💡 SOLUTION: Install exact versions with:"
    Write-Error "   Install-Module ExchangeOnlineManagement -RequiredVersion 3.5.0 -Force"
    Write-Error "   Install-Module Microsoft.Graph.Authentication -RequiredVersion 2.25.0 -Force"
    Write-Error "   Install-Module ImportExcel -Force"
    exit 1
}

# Validate required parameters
if (-not $AppId) { Write-Error "❌ AppId is required (parameter or Automation Variable)"; exit 1 }
if (-not $TenantName -and -not $TenantId) { Write-Error "❌ TenantName or TenantId is required"; exit 1 }
if (-not $SiteId) { Write-Error "❌ SiteId is required for report upload"; exit 1 }
if (-not $DriveId) { Write-Error "❌ DriveId is required for report upload"; exit 1 }

# Get certificate for authentication (Azure Automation compatible)
try {
    if ($CertificateName) {
        $Certificate = Get-AutomationCertificate -Name $CertificateName -ErrorAction Stop
        $CertificateThumbprint = $Certificate.Thumbprint
        Write-Output "✅ Retrieved certificate from Automation Account: $CertificateName"
    }
    elseif (-not $CertificateThumbprint) {
        Write-Error "❌ Either CertificateThumbprint or CertificateName must be provided"
        exit 1
    }
    
    Write-Output "🔐 Using certificate authentication with thumbprint: $($CertificateThumbprint.Substring(0,8))..."
}
catch {
    Write-Error "❌ Failed to retrieve certificate: $($_.Exception.Message)"
    exit 1
}

# Connect to Exchange Online (using proven working method)
try {
    Write-Output "🔗 Connecting to Exchange Online..."
    Connect-ExchangeOnline -AppId $AppId -Organization $TenantName -CertificateThumbprint $CertificateThumbprint -ShowBanner:$false
    Write-Output "✅ Successfully connected to Exchange Online"
}
catch {
    Write-Error "❌ Failed to connect to Exchange Online: $($_.Exception.Message)"
    Write-Error "💡 Verify TenantName, AppId, and certificate configuration"
    exit 1
}

# Connect to Microsoft Graph (using certificate method)
try {
    Write-Output "🔗 Connecting to Microsoft Graph..."
    if ($CertificateName) {
        # Use certificate object for Automation Account
        Connect-MgGraph -TenantId $TenantId -ClientId $AppId -Certificate $Certificate
    } else {
        # Use thumbprint for manual execution
        Connect-MgGraph -TenantId $TenantId -ClientId $AppId -CertificateThumbprint $CertificateThumbprint
    }
    Write-Output "✅ Successfully connected to Microsoft Graph"
}
catch {
    Write-Error "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    Write-Error "💡 Verify TenantId, AppId, and certificate permissions"
    exit 1
}

# Calculate date range
$EndDate = Get-Date
$StartDate = $EndDate.AddDays(-$DaysBack)

Write-Output "📅 Searching audit logs from $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"

# Search for SharePoint download events (using proven working approach)
try {
    Write-Output "🔍 Searching for SharePoint download events..."
    
    # Build search parameters (similar to working script)
    $SearchParams = @{
        StartDate = $StartDate
        EndDate = $EndDate
        RecordType = 'SharePointFileOperation'
        Operations = 'FileDownloaded'
        ResultSize = 5000
    }
    
    # Add site filtering if specified
    if ($TargetSiteIds) {
        $SearchParams.SiteIds = $TargetSiteIds
        Write-Output "🎯 Filtering to specific sites: $($TargetSiteIds -join ', ')"
    }
    
    # Execute search
    $AuditResults = Search-UnifiedAuditLog @SearchParams
    Write-Output "📊 Found $($AuditResults.Count) download events"
    
    if ($AuditResults.Count -eq 0) {
        Write-Output "ℹ️ No download events found in the specified date range"
        $CleanedData = @()
    }
    else {
        # Process audit data (using working script approach)
        Write-Output "⚙️ Processing audit data for Excel export..."
        $CleanedData = foreach ($Row in $AuditResults) {
            try {
                $AuditData = $Row.AuditData | ConvertFrom-Json
                $FilePath = $AuditData.ObjectId
                
                [PSCustomObject]@{
                    "Date" = $Row.CreationDate
                    "Downloaded File Path" = $FilePath
                    "User" = $AuditData.UserId
                    "Site URL" = $AuditData.SiteUrl
                    "Client IP" = $AuditData.ClientIP
                    "File Name" = ($FilePath -split '/')[-1]
                    "Site Name" = if ($AuditData.SiteUrl) { ($AuditData.SiteUrl -split '/sites/')[-1] -split '/' | Select-Object -First 1 } else { 'Unknown' }
                }
            } catch {
                Write-Warning "⚠️ Failed to process audit record: $($_.Exception.Message)"
                $null
            }
        }
        
        # Remove null entries from processing errors
        $CleanedData = $CleanedData | Where-Object { $_ -ne $null }
        Write-Output "✅ Successfully processed $($CleanedData.Count) download events"
    }
}
catch {
    Write-Error "❌ Failed to search audit logs: $($_.Exception.Message)"
    exit 1
}

# Generate Excel report (using proven working method)
try {
    $DateString = (Get-Date -Format "yyyy-MM-dd")
    $FileName = "Logs_$DateString.xlsx"
    $ExcelPath = Join-Path $env:TEMP $FileName
    
    Write-Output "📊 Generating Excel report: $FileName"
    
    # Export main data to Excel with table formatting (matches working script)
    $CleanedData | Export-Excel -Path $ExcelPath -WorksheetName "AuditLog" -AutoSize -TableName "LogTable"
    
    Write-Output "✅ Successfully generated Excel report with $($CleanedData.Count) records"
    Write-Output "📁 Temporary file created: $ExcelPath"
}
catch {
    Write-Error "❌ Failed to generate Excel report: $($_.Exception.Message)"
    exit 1
}

# Upload to SharePoint using Microsoft Graph (proven working method)
try {
    Write-Output "📤 Uploading Excel report to SharePoint..."
    
    # Read file as bytes
    $FileBytes = [System.IO.File]::ReadAllBytes($ExcelPath)
    
    # Construct upload URL (matches working script format)
    $UploadUrl = "https://graph.microsoft.com/v1.0/sites/$SiteId/drives/$DriveId/root:/$FolderPath/${FileName}:/content"
    
    Write-Output "🎯 Upload target: $UploadUrl"
    
    # Upload using Invoke-MgGraphRequest (preferred method for Graph PowerShell SDK)
    $Response = Invoke-MgGraphRequest -Method PUT -Uri $UploadUrl -Body $FileBytes -ContentType "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    
    Write-Output "✅ File '$FileName' uploaded successfully to SharePoint"
    Write-Output "� SharePoint URL: $($Response.webUrl)"
    
    # Clean up temporary file
    Remove-Item $ExcelPath -Force -ErrorAction SilentlyContinue
    Write-Output "🧹 Cleaned up temporary files"
}
catch {
    Write-Error "❌ Upload failed: $($_.Exception.Message)"
    Write-Error "💡 Common causes:"
    Write-Error "   - Incorrect SiteId or DriveId"
    Write-Error "   - Insufficient permissions on target library"
    Write-Error "   - Network connectivity issues"
    Write-Error "   - Authentication token expired"
    exit 1
}
finally {
    # Disconnect from services (cleanup)
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Output "✅ Successfully disconnected from services"
    }
    catch {
        Write-Warning "⚠️ Warning during service disconnection: $($_.Exception.Message)"
    }
}

# Final summary
Write-Output ""
Write-Output "🎉 SharePoint Download Monitoring completed successfully!"
Write-Output "📊 Summary Statistics:"
Write-Output "   • Downloads processed: $($CleanedData.Count)"
Write-Output "   • Date range: $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"
Write-Output "   • Report uploaded: $FileName"
Write-Output "   • Target location: $FolderPath folder in SharePoint"
Write-Output ""
Write-Output "� Script version: 2.1 (Azure Automation Optimized)"
Write-Output "✅ All operations completed successfully"