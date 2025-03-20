## Script that changes archive retention for all required tables to 2 years while keeping interactive retention at the workspace default level.

Write-Host "🔹 Don't forget to log in to Azure CLI (az login)!"
$customer = Read-Host "🔹 Enter the customer name: "

# Setting up variables
$jsonFilePath = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Tools/Python Repository Scripts/CustomerAzureValues.json"
$jsonData = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
$resourceGroup = $jsonData.$customer.resource_group
$workspaceName = $jsonData.$customer.workspace_name

$archiveRetentionTableTime = -1 # -1 means workspace default for interactive retention
$interactiveRetentionTableTime = 730 # 2 years of interactive retention for SecurityAlert, SecurityIncident
$totalRetention = 730 # 2 years

# List of tables for which we want to change retention
$archiveTables = @(
    "SigninLogs",
    "AzureActivity",
    "CommonSecurityLog",
    "OfficeActivity",
    "DeviceInfo",
    "DeviceNetworkInfo",
    "DeviceNetworkEvents",
    "DeviceTvmSecureConfigurationAssessment",
    "DeviceTvmSecureConfigurationAssessmentKB",
    "DeviceTvmSoftwareInventory",
    "DeviceTvmSoftwareVulnerabilities",
    "DeviceTvmSoftwareVulnerabilitiesKB",
    "DeviceProcessEvents",
    "DeviceFileEvents",
    "DeviceRegistryEvents",
    "DeviceLogonEvents",
    "DeviceImageLoadEvents",
    "DeviceEvents",
    "DeviceFileCertificateInfo",
    "EmailEvents",
    "EmailAttachmentInfo",
    "EmailPostDeliveryEvents",
    "UrlClickEvents",
    "CloudAppEvents",
    "IdentityLogonEvents",
    "IdentityQueryEvents",
    "IdentityDirectoryEvents",
    "AuditLogs",
    "AADNonInteractiveUserSignInLogs",
    "AADRiskyUsers",
    "AADUserRiskEvents"
    "AADServicePrincipalSignInLogs",
    "AADManagedIdentitySignInLogs",
    "AADProvisioningLogs",
    "ADFSSignInLogs",
    "AADRiskyServicePrincipals",
    "MicrosoftGraphActivityLogs",
    "MicrosoftPurviewInformationProtection",
    "Syslog",
    "SecurityEvent",
    "LAQueryLogs",
    "Alert",
    "AlertEvidence",
    "AlertInfo",
    "Usage",
    "Event"
)

$interactiveTables = @(
    "SecurityIncident",
    "SecurityAlert"
)

# Iterate through each table in the list and change retention
foreach ($tableName in $archiveTables) {
    az monitor log-analytics workspace table update `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --name $tableName `
        --retention-time $archiveRetentionTableTime `
        --total-retention-time $totalRetention *> $null

    Write-Host "✅ Archive retention (2 years) successfully updated for table: $tableName!" -ForegroundColor Green
}

# Set interactive retention to 2 years for SecurityAlert and SecurityIncident
foreach ($tableName in $interactiveTables) {
    az monitor log-analytics workspace table update `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --name $tableName `
        --retention-time $interactiveRetentionTableTime `
        --total-retention-time $totalRetention *> $null

    Write-Host "✅ Interactive and archive retention (2 years) successfully updated for table: $tableName!" -ForegroundColor Green
}

Write-Host "`n✅ All tables have been successfully updated!" -ForegroundColor Green