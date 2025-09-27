#Requires -Version 7.2
<#
.SYNOPSIS
    SharePoint Download Monitoring Script - Azure Storage Option
    
.DESCRIPTION
    Monitors SharePoint download activity and uploads data to Azure Storage for interactive dashboard consumption.
    This script is optimized for Azure Automation runbooks and generates JSON data for modern web dashboards.
    
.PARAMETER TenantId
    Azure AD Tenant ID
    
.PARAMETER ClientId
    Application (Client) ID from App Registration
    
.PARAMETER CertificateThumbprint
    Certificate thumbprint for authentication
    
.PARAMETER StorageAccountName
    Azure Storage Account name where data will be uploaded
    
.PARAMETER StorageAccountKey
    Azure Storage Account access key
    
.PARAMETER ContainerName
    Container name for storing JSON data (default: 'data')
    
.PARAMETER DaysBack
    Number of days to look back for audit logs (default: 7)
    
.EXAMPLE
    .\Monitor-SharePointDownloads-AzureStorage.ps1 -TenantId "your-tenant-id" -ClientId "your-client-id" -CertificateThumbprint "your-cert-thumbprint" -StorageAccountName "yourstorageaccount" -StorageAccountKey "your-storage-key"
    
.NOTES
    Author: Ofir Gavish & Eitan Talmi
    Version: 2.0
    Requires: PowerShell 7.2+, ExchangeOnlineManagement, Microsoft.Graph.Authentication, Az.Storage modules
    
    For Azure Automation use, store sensitive parameters as Automation Variables:
    - TenantID
    - AppID (ClientId)
    - CertificateName (Certificate stored in Automation Account)
    - StorageAccountName
    - StorageAccountKey
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
    [string]$StorageAccountName = (Get-AutomationVariable -Name "StorageAccountName" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$StorageAccountKey = (Get-AutomationVariable -Name "StorageAccountKey" -ErrorAction SilentlyContinue),
    
    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "data",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 7
)

# Import required modules
try {
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
    Import-Module Microsoft.Graph.Authentication -Force -ErrorAction Stop
    Import-Module Az.Storage -Force -ErrorAction Stop
    Write-Output "✅ Successfully imported required modules"
}
catch {
    Write-Error "❌ Failed to import required modules: $($_.Exception.Message)"
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
        # Process audit data
        $ProcessedData = foreach ($Result in $AuditResults) {
            $AuditData = $Result.AuditData | ConvertFrom-Json
            
            [PSCustomObject]@{
                Timestamp = $Result.CreationDate.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
                User = $AuditData.UserId
                UserType = $AuditData.UserType
                FileName = $AuditData.ObjectId -replace '.*/', ''
                FileExtension = ($AuditData.ObjectId -replace '.*/', '') -replace '.*\.', ''
                FilePath = $AuditData.ObjectId
                SiteUrl = $AuditData.SiteUrl
                SiteName = ($AuditData.SiteUrl -replace 'https://.*sharepoint.com/sites/', '') -replace '/', ''
                UserAgent = $AuditData.UserAgent
                ClientIP = $AuditData.ClientIP
                Workload = $AuditData.Workload
                RecordType = $Result.RecordType
                Operation = $AuditData.Operation
            }
        }
        
        Write-Output "✅ Processed $($ProcessedData.Count) download events"
    }
}
catch {
    Write-Error "❌ Failed to search audit logs: $($_.Exception.Message)"
    exit 1
}

# Generate summary statistics
$Summary = @{
    GeneratedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
    DateRange = @{
        Start = $StartDate.ToString('yyyy-MM-dd')
        End = $EndDate.ToString('yyyy-MM-dd')
    }
    TotalDownloads = $ProcessedData.Count
    UniqueUsers = ($ProcessedData | Select-Object -Unique User).Count
    UniqueSites = ($ProcessedData | Select-Object -Unique SiteUrl).Count
    UniqueFiles = ($ProcessedData | Select-Object -Unique FilePath).Count
    TopFileTypes = $ProcessedData | Group-Object FileExtension | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { @{FileType = $_.Name; Count = $_.Count} }
    TopUsers = $ProcessedData | Group-Object User | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { @{User = $_.Name; Count = $_.Count} }
    TopSites = $ProcessedData | Group-Object SiteName | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object { @{Site = $_.Name; Count = $_.Count} }
}

# Create final JSON structure
$JsonData = @{
    metadata = $Summary
    downloads = $ProcessedData
}

# Convert to JSON
try {
    $JsonContent = $JsonData | ConvertTo-Json -Depth 10 -Compress
    Write-Output "✅ Generated JSON data ($(([System.Text.Encoding]::UTF8.GetBytes($JsonContent)).Length) bytes)"
}
catch {
    Write-Error "❌ Failed to convert data to JSON: $($_.Exception.Message)"
    exit 1
}

# Upload to Azure Storage
try {
    $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    
    $BlobName = "sharepoint-downloads-$(Get-Date -Format 'yyyy-MM-dd-HHmm').json"
    $LatestBlobName = "sharepoint-downloads-latest.json"
    
    # Upload current data with timestamp
    $TempFile = [System.IO.Path]::GetTempFileName()
    $JsonContent | Out-File -FilePath $TempFile -Encoding UTF8
    
    Set-AzStorageBlobContent -File $TempFile -Container $ContainerName -Blob $BlobName -Context $StorageContext -Force | Out-Null
    Write-Output "✅ Uploaded data to: $BlobName"
    
    # Upload as latest (for dashboard consumption)
    Set-AzStorageBlobContent -File $TempFile -Container $ContainerName -Blob $LatestBlobName -Context $StorageContext -Force | Out-Null
    Write-Output "✅ Updated latest data file: $LatestBlobName"
    
    # Clean up temp file
    Remove-Item $TempFile -Force
}
catch {
    Write-Error "❌ Failed to upload to Azure Storage: $($_.Exception.Message)"
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
Write-Output "📊 Summary: $($ProcessedData.Count) downloads from $($Summary.UniqueUsers) users across $($Summary.UniqueSites) sites"
Write-Output "🌐 Dashboard data available at: https://$StorageAccountName.blob.core.windows.net/$ContainerName/$LatestBlobName"