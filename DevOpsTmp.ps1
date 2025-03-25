# === PŘIDÁNÍ OBSAHU A VYTVOŘENÍ PIPELINE ===

# 1. Klonování repozitáře
$repoPath = "$PWD/$repoName"
$cloneUrl = "git@ssh.dev.azure.com:v3/$devOpsOrg/$projectName/$repoName"


git clone $cloneUrl $repoPath/test

# 2. Přidání složky .devops-pipeline do repozitáře
$sourceDevOpsFolder = ".devops-pipeline"
$targetDevOpsFolder = "$repoPath/.devops"
Copy-Item -Path $sourceDevOpsFolder -Destination $targetDevOpsFolder -Recurse -Force

# 3. Přesun pipeline.yml do root repozitáře
Copy-Item -Path "$sourceDevOpsFolder/pipeline.yml" -Destination "$repoPath/pipeline.yml" -Force

# 4. Úprava proměnných v pipeline.yml
(Get-Content "$repoPath/pipeline.yml") |
    ForEach-Object {
        $_ -replace "(?<=name: VarResourceGroupName\s*`r?`n\s*value:\s*).*", "RG-$customer" `
           -replace "(?<=name: ConnectionName\s*`r?`n\s*value:\s*).*", "$serviceConnectionName" `
           -replace "(?<=name: VarWorkSpaceName\s*`r?`n\s*value:\s*).*", "LA-$customer"
    } | Set-Content "$repoPath/pipeline.yml"

# 5. Commit a push změn
Set-Location $repoPath
git config user.email "automation@devops"
git config user.name "Automation Script"
git add .
git commit -m "Add .devops and pipeline.yml"
git push

# 6. Vytvoření pipeline v Azure DevOps
$pipelineName = "Deploy-Sentinel-$customer"
az pipelines create `
  --name $pipelineName `
  --repository "$repoName" `
  --repository-type tfsgit `
  --branch main `
  --yaml-path pipeline.yml `
  --project "$projectName" `
  --organization "$devOpsOrgUrl"

# 7. Přiřazení oprávnění pro pipeline k Service Connection
$pipelineId = az pipelines show --name $pipelineName --organization "$devOpsOrgUrl" --project "$projectName" --query id -o tsv
$serviceConnectionId = az devops service-endpoint list --project "$projectName" --organization "$devOpsOrgUrl" --query "[?name=='$serviceConnectionName'].id" -o tsv

az devops service-endpoint update `
    --id $serviceConnectionId `
    --project "$projectName" `
    --organization "$devOpsOrgUrl" `
    --enable-for-all-pipelines true

Set-Location $PSScriptRoot
Write-Host "`n✅ Pipeline vytvořena a nastaveny proměnné i oprávnění."
