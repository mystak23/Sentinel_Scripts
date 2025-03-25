# === ZÁKLADNÍ PROMĚNNÉ ===

# Config
$configPath = "DevOps.json"
$config = Get-Content $configPath | ConvertFrom-Json

# Customer
$customer = $config.customer
$customerTenantId = $config.customerTenantId
$customerSubscriptionId = $config.customerSubscriptionId
$spName = $config.spName

# Dev Ops
$projectName = $config.projectName
$repoName = $config.repoName
$subClaim = $config.subClaim
$issuer = $config.issuer
$audience = $config.audience
$devOpsOrg = $config.devOpsOrg
$devOpsOrgUrl = $config.devOpsOrgUrl
$serviceConnectionName = $config.serviceConnectionName
$devOpsJsonPath = $config.devOpsJsonPath

# === PŘIHLÁŠENÍ DO TENANTU ZÁKAZNÍKA ===
az login --tenant $customerTenantId

# === VYTVOŘENÍ APLIKACE ===
$app = az ad app create --display-name $spName | ConvertFrom-Json
$appId = $app.appId
$appObjectId = $app.id

# === FEDERATED CREDENTIAL ===
$federatedCredential = @{
    name = "DevOpsFederatedLogin"
    issuer = $issuer
    subject = $subClaim
    audiences = @($audience)
} | ConvertTo-Json -Depth 10 -Compress

$federatedCredentialFile = "federated.json"
$federatedCredential | Out-File -Encoding utf8 $federatedCredentialFile

az ad app federated-credential create `
    --id $appObjectId `
    --parameters $federatedCredentialFile

Remove-Item $federatedCredentialFile

# === VYTVOŘENÍ SERVICE PRINCIPALU ===
$sp = az ad sp create --id $appId | ConvertFrom-Json

# === PŘIŘAZENÍ ROLÍ ===
$roles = @(
    "Microsoft Sentinel Contributor",
    "Logic App Contributor",
    "Monitoring Contributor"
)

foreach ($role in $roles) {
    az role assignment create `
        --assignee $sp.appId `
        --role $role `
        --scope "/subscriptions/$customerSubscriptionId"
}

# === PŘIHLÁŠENÍ ZPĚT DO TVÉHO TENANTU ===
az login --allow-no-subscriptions

# === DEVOPS NASTAVENÍ ===
az devops configure --defaults organization=$devOpsOrgUrl project=$projectName

# === VYTVOŘENÍ REPOZITÁŘE ===
az repos create --name $repoName

# === ZÍSKÁNÍ ID PROJEKTU ===
$projectId = az devops project show --project $projectName --query id -o tsv

# === VYTVOŘENÍ devops.json PRO FEDEROVANOU SERVICE CONNECTION ===
$devOpsJson = @{
    data = @{
        subscriptionId = $customerSubscriptionId
        subscriptionName = "Customer Subscription"
        environment = "AzureCloud"
        scopeLevel = "Subscription"
    }
    name = $serviceConnectionName
    type = "azurerm"
    url = "https://management.azure.com/"
    authorization = @{
        scheme = "WorkloadIdentityFederation"
        parameters = @{
            tenantid = $customerTenantId
            serviceprincipalid = $appId
        }
    }
    isShared = $false
    isReady = $true
    projectReferences = @(@{
        id = $projectId
        name = $projectName
    })
} | ConvertTo-Json -Depth 10

$devOpsJson | Out-File -Encoding utf8 $devOpsJsonPath

# === VYTVOŘENÍ SERVICE CONNECTION ===
az devops service-endpoint create `
    --service-endpoint-configuration $devOpsJsonPath `
    --org $devOpsOrgUrl `
    --project $projectName

Remove-Item $devOpsJsonPath

Write-Host "`n✅ Vše hotovo – Service Connection přes federované přihlášení byla úspěšně vytvořena."

