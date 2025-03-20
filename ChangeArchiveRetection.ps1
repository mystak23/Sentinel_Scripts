## Skript, který změní archivní retenci u všech požadovaných tabulek na 2 roky, zatímco nechá interaktivní retenci na úrovni workspace default.

Write-Host "🔹 Nezapomeň se přihlásit k Azure CLI (az login)!"
$customer = Read-Host "🔹 Zadejte název zákazníka: "

# Nastavení proměnných
$jsonFilePath = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Tools/Python Repository Scripts/CustomerAzureValues.json"
$jsonData = Get-Content -Raw -Path $jsonFilePath | ConvertFrom-Json
$resourceGroup = $jsonData.$customer.resource_group
$workspaceName = $jsonData.$customer.workspace_name

$archiveRetentionTableTime = -1 # -1 je workspace default pro interaktivni retenci
$interactiveRetentionTableTime = 730 # 2 roky interaktivni retence pro SecurityAlert, SecurityIncident
$totalRetention = 730 # 2 roky

# Seznam tabulek, u kterých chceme změnit retenci
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

# Procházení každé tabulky v seznamu a změna retence
foreach ($tableName in $archiveTables) {
    az monitor log-analytics workspace table update `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --name $tableName `
        --retention-time $archiveRetentionTableTime `
        --total-retention-time $totalRetention *> $null

    Write-Host "✅ Archivní retence (2 roky) úspěšně změněna pro tabulku: $tableName!" -ForegroundColor Green
}

# Nastav interaktivní retenci na 2 roky u SecurityAlert a SecurityIncident
foreach ($tableName in $interactiveTables) {
    az monitor log-analytics workspace table update `
        --resource-group $resourceGroup `
        --workspace-name $workspaceName `
        --name $tableName `
        --retention-time $interactiveRetentionTableTime `
        --total-retention-time $totalRetention *> $null

    Write-Host "✅ Interaktivní i archivní retence (2 roky) úspěšně změněna pro tabulku: $tableName!" -ForegroundColor Green
}


Write-Host "`n✅ Všechny tabulky byly úspěšně aktualizovány!" -ForegroundColor Green