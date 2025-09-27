#Requires -Version 7.2
<#
.SYNOPSIS
    SharePoint Download Monitoring Script - SharePoint Upload Option
    
.DESCRIPTION
    Monitors SharePoint download activity and uploads Excel reports to SharePoint document libraries.
    This script requires specific module versions for reliable authentication and upload functionality.
    
.PARAMETER TenantId
    Azure AD Tenant ID
    
.PARAMETER ClientId
    Application (Client) ID from App Registration
    
.PARAMETER CertificateThumbprint
    Certificate thumbprint for authentication
    
.PARAMETER ReportSiteId
    SharePoint site ID where reports will be uploaded
    
.PARAMETER ReportLibraryName
    Document library name for report uploads (default: 'Download Reports')
    
.PARAMETER DaysBack
    Number of days to look back for audit logs (default: 7)
    
.EXAMPLE
    .\Monitor-SharePointDownloads-SharePointUpload.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id" -CertificateThumbprint "your-cert-thumbprint" -ReportSiteId "your-site-id"
    
.NOTES
    Author: Ofir Gavish & Eitan Talmi
    Version: 2.0
    
    CRITICAL MODULE REQUIREMENTS:
    - ExchangeOnlineManagement 3.5.0
    - Microsoft.Graph.Authentication 2.25.0
    - Az.Storage 6.0.0
    - ImportExcel (latest)
    
    These specific versions are required for reliable SharePoint upload functionality.
    DO NOT use newer versions without testing as they may break authentication.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TenantId = (Get-AutomationVariable -Name "TenantID" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$ClientId = (Get-AutomationVariable -Name "AppID" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$CertificateThumbprint,
    
    [Parameter(Mandatory = $false)]
    [string]$CertificateName = (Get-AutomationVariable -Name "CertificateName" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$ReportSiteId = (Get-AutomationVariable -Name "ReportSiteId" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$ReportLibraryName = "Download Reports",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 7
)

# Import required modules with version check
try {
    Write-Output "📦 Checking module versions..."
    
    # Import ExchangeOnlineManagement 3.5.0
    $EXOModule = Get-Module -Name ExchangeOnlineManagement -ListAvailable | Where-Object { $_.Version -eq "3.5.0" }
    if (-not $EXOModule) {
        throw "ExchangeOnlineManagement version 3.5.0 is required. Current version may cause authentication issues."
    }
    Import-Module ExchangeOnlineManagement -RequiredVersion 3.5.0 -Force -ErrorAction Stop
    
    # Import Microsoft.Graph.Authentication 2.25.0
    $GraphModule = Get-Module -Name Microsoft.Graph.Authentication -ListAvailable | Where-Object { $_.Version -eq "2.25.0" }
    if (-not $GraphModule) {
        throw "Microsoft.Graph.Authentication version 2.25.0 is required. Current version may cause authentication issues."
    }
    Import-Module Microsoft.Graph.Authentication -RequiredVersion 2.25.0 -Force -ErrorAction Stop
    
    # Import ImportExcel for Excel generation
    Import-Module ImportExcel -Force -ErrorAction Stop
    
    Write-Output "✅ Successfully imported required modules with correct versions"
}
catch {
    Write-Error "❌ Failed to import required modules: $($_.Exception.Message)"
    Write-Error "Please ensure you have the specific module versions installed as documented"
    exit 1
}

# Get certificate for authentication
try {
    if ($CertificateName) {
        $Certificate = Get-AutomationCertificate -Name $CertificateName
        $CertificateThumbprint = $Certificate.Thumbprint
        Write-Output "✅ Retrieved certificate from Automation Account: $CertificateName"
    }
    elseif (-not $CertificateThumbprint) {
        throw "Certificate thumbprint or certificate name must be provided"
    }
}
catch {
    Write-Error "❌ Failed to retrieve certificate: $($_.Exception.Message)"
    exit 1
}

# Connect to Exchange Online
try {
    Connect-ExchangeOnline -CertificateThumbprint $CertificateThumbprint -AppId $ClientId -Organization "$TenantId" -ShowBanner:$false
    Write-Output "✅ Connected to Exchange Online"
}
catch {
    Write-Error "❌ Failed to connect to Exchange Online: $($_.Exception.Message)"
    exit 1
}

# Connect to Microsoft Graph
try {
    Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
    Write-Output "✅ Connected to Microsoft Graph"
}
catch {
    Write-Error "❌ Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# Calculate date range
$EndDate = Get-Date
$StartDate = $EndDate.AddDays(-$DaysBack)

Write-Output "📅 Searching audit logs from $($StartDate.ToString('yyyy-MM-dd')) to $($EndDate.ToString('yyyy-MM-dd'))"

# Search for SharePoint download events
try {
    $AuditResults = Search-UnifiedAuditLog -StartDate $StartDate -EndDate $EndDate -Operations "FileDownloaded" -ResultSize 5000
    Write-Output "📊 Found $($AuditResults.Count) download events"
    
    if ($AuditResults.Count -eq 0) {
        Write-Output "ℹ️ No download events found in the specified date range"
        $ProcessedData = @()
    }
    else {
        # Process audit data for Excel export
        $ProcessedData = foreach ($Result in $AuditResults) {
            $AuditData = $Result.AuditData | ConvertFrom-Json
            
            [PSCustomObject]@{
                'Date/Time' = $Result.CreationDate.ToString('yyyy-MM-dd HH:mm:ss')
                'User' = $AuditData.UserId
                'User Type' = $AuditData.UserType
                'File Name' = $AuditData.ObjectId -replace '.*/', ''
                'File Extension' = ($AuditData.ObjectId -replace '.*/', '') -replace '.*\.', ''
                'File Path' = $AuditData.ObjectId
                'Site URL' = $AuditData.SiteUrl
                'Site Name' = ($AuditData.SiteUrl -replace 'https://.*sharepoint.com/sites/', '') -replace '/', ''
                'Client IP' = $AuditData.ClientIP
                'User Agent' = $AuditData.UserAgent
                'Operation' = $AuditData.Operation
                'Workload' = $AuditData.Workload
            }
        }
        
        Write-Output "✅ Processed $($ProcessedData.Count) download events for Excel export"
    }
}
catch {
    Write-Error "❌ Failed to search audit logs: $($_.Exception.Message)"
    exit 1
}

# Generate Excel report
try {
    $ReportDate = Get-Date -Format 'yyyy-MM-dd-HHmm'
    $ExcelFileName = "SharePoint_Downloads_$ReportDate.xlsx"
    $TempFile = Join-Path $env:TEMP $ExcelFileName
    
    # Create Excel workbook with multiple worksheets
    $ProcessedData | Export-Excel -Path $TempFile -WorksheetName "Download Details" -AutoSize -FreezeTopRow -BoldTopRow
    
    # Add summary worksheet
    $Summary = [PSCustomObject]@{
        'Report Generated' = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        'Date Range Start' = $StartDate.ToString('yyyy-MM-dd')
        'Date Range End' = $EndDate.ToString('yyyy-MM-dd')
        'Total Downloads' = $ProcessedData.Count
        'Unique Users' = ($ProcessedData | Select-Object -Unique User).Count
        'Unique Sites' = ($ProcessedData | Select-Object -Unique 'Site URL').Count
        'Unique Files' = ($ProcessedData | Select-Object -Unique 'File Path').Count
    }
    
    $Summary | Export-Excel -Path $TempFile -WorksheetName "Summary" -AutoSize -BoldTopRow -Append
    
    # Add top users analysis
    $TopUsers = $ProcessedData | Group-Object User | Sort-Object Count -Descending | Select-Object -First 20 | ForEach-Object {
        [PSCustomObject]@{
            'User' = $_.Name
            'Download Count' = $_.Count
        }
    }
    
    if ($TopUsers) {
        $TopUsers | Export-Excel -Path $TempFile -WorksheetName "Top Users" -AutoSize -BoldTopRow -Append
    }
    
    # Add file type analysis
    $FileTypes = $ProcessedData | Group-Object 'File Extension' | Sort-Object Count -Descending | ForEach-Object {
        [PSCustomObject]@{
            'File Type' = $_.Name
            'Download Count' = $_.Count
        }
    }
    
    if ($FileTypes) {
        $FileTypes | Export-Excel -Path $TempFile -WorksheetName "File Types" -AutoSize -BoldTopRow -Append
    }
    
    Write-Output "✅ Generated Excel report: $ExcelFileName"
}
catch {
    Write-Error "❌ Failed to generate Excel report: $($_.Exception.Message)"
    exit 1
}

# Upload to SharePoint
try {
    Write-Output "📤 Uploading report to SharePoint..."
    
    # Read file content
    $FileContent = [System.IO.File]::ReadAllBytes($TempFile)
    $Base64Content = [System.Convert]::ToBase64String($FileContent)
    
    # Get access token for Graph API
    $Context = Get-MgContext
    $Token = [Microsoft.Graph.PowerShell.Authentication.GraphSession]::Instance.AuthenticationProvider.GetAccessTokenAsync("https://graph.microsoft.com/").GetAwaiter().GetResult()
    
    # Upload file using Graph API
    $UploadUrl = "https://graph.microsoft.com/v1.0/sites/$ReportSiteId/drive/root:/$ReportLibraryName/$ExcelFileName:/content"
    
    $Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    }
    
    $Response = Invoke-RestMethod -Uri $UploadUrl -Method PUT -Body $FileContent -Headers $Headers
    
    Write-Output "✅ Successfully uploaded report to SharePoint"
    Write-Output "📁 File location: $($Response.webUrl)"
    
    # Clean up temp file
    Remove-Item $TempFile -Force
}
catch {
    Write-Error "❌ Failed to upload to SharePoint: $($_.Exception.Message)"
    Write-Error "This may be due to insufficient permissions or incorrect module versions"
    exit 1
}
finally {
    # Disconnect from services
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Write-Output "✅ Disconnected from services"
    }
    catch {
        Write-Warning "⚠️ Error disconnecting from services: $($_.Exception.Message)"
    }
}

Write-Output "🎉 Script completed successfully!"
Write-Output "📊 Summary: $($ProcessedData.Count) downloads processed and uploaded to SharePoint"
Write-Output "📈 Excel report contains detailed analysis across multiple worksheets"