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

# === PŘIDÁNÍ OBSAHU A VYTVOŘENÍ PIPELINE ===

# 1. Přesun .devops-pipeline složky do repozitáře zákazníka
$repoPath = "$PWD/$repoName"
$sourceDevOpsFolder = ".devops-pipeline"
$targetDevOpsFolder = "$repoPath/.devops"

Write-Host https://dev.azure.com/$devOpsOrg/$projectName/_git/$repoName

if (!(Test-Path $repoPath)) {
    git clone git@ssh.dev.azure.com:v3/$devOpsOrg/$projectName/$repoName $repoPath
}


Copy-Item -Path $sourceDevOpsFolder -Destination $targetDevOpsFolder -Recurse -Force

# 2. Přesun pipeline.yml do root složky
Copy-Item -Path "$sourceDevOpsFolder/pipeline.yml" -Destination "$repoPath/pipeline.yml" -Force

# 3. Úprava proměnných v pipeline.yml
(Get-Content "$repoPath/pipeline.yml") |
    ForEach-Object {
        $_ -replace "(?<=name: VarResourceGroupName\s+value: ).*", "RG-$customer" `
           -replace "(?<=name: ConnectionName\s+value: ).*", "$serviceConnectionName" `
           -replace "(?<=name: VarWorkSpaceName\s+value: ).*", "LA-$customer"
    } | Set-Content "$repoPath/pipeline.yml"

# 4. Commit a push změn
Set-Location $repoPath

git config user.email "automation@devops"
git config user.name "Automation Script"
git add .
git commit -m "Add .devops and pipeline.yml"
git push

Set-Location ..

# 5. Vytvoření pipeline v Azure DevOps
$pipelineName = "Deploy-Sentinel-$customer"
az pipelines create `
  --name $pipelineName `
  --repository $repoName `
  --repository-type tfsgit `
  --branch main `
  --yaml-path pipeline.yml `
  --project $projectName `
  --org "$devOpsOrgUrl"

# 6. Přiřazení oprávnění pro pipeline k Service Connection
$pipelineId = az pipelines show --name $pipelineName --org "$devOpsOrgUrl" --project "$projectName" --query id -o tsv
$serviceConnectionId = az devops service-endpoint list --project "$projectName" --org "$devOpsOrgUrl" --query "[?name=='$serviceConnectionName'].id" -o tsv

az devops service-endpoint update `
    --id $serviceConnectionId `
    --project "$projectName" `
    --org "$devOpsOrgUrl" `
    --enable-for-all-pipelines true

Write-Host "`n✅ Pipeline vytvořena a nastaveny proměnné i oprávnění."
