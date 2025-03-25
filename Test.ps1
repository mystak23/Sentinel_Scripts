# === KONFIGURACE ===
$configPath = "DevOps.json"
$config = Get-Content $configPath | ConvertFrom-Json

# Customer
$customer = $config.customer
$repoNameBase = $config.repoName
$repoName = "$repoNameBase-$customer"
$projectName = $config.projectName
$devOpsOrg = $config.devOpsOrg
$devOpsOrgUrl = $config.devOpsOrgUrl

# Git URL a cesta
$gitUrl = "git@ssh.dev.azure.com:v3/$devOpsOrg/$projectName/$repoName"
$clonePath = Join-Path -Path $PWD -ChildPath $repoName

Write-Host "Cloning from: $gitUrl"
git clone $gitUrl $clonePath

# Přesun složky .devops-pipeline
$sourcePipelineFolder = ".devops-pipeline"
$targetPipelineFolder = Join-Path -Path $clonePath -ChildPath ".devops-pipeline"

$workspaceName = "LA-Test"
$resourceGroupName = "RG-Test"

if (Test-Path $sourcePipelineFolder) {
    Copy-Item -Path $sourcePipelineFolder -Destination $targetPipelineFolder -Recurse -Force
} else {
    Write-Error ".devops-pipeline folder not found"
    exit 1
}

# Přesun pipeline.yml do root složky
$pipelineFile = Join-Path -Path $targetPipelineFolder -ChildPath "pipeline.yml"
$targetPipelineFile = Join-Path -Path $clonePath -ChildPath "pipeline.yml"

if (Test-Path $pipelineFile) {
    Move-Item -Path $pipelineFile -Destination $targetPipelineFile -Force
} else {
    Write-Error "pipeline.yml not found in .devops-pipeline"
    exit 1
}

# === ÚPRAVA pipeline.yml PROMĚNNÝCH ===
$pipelineFilePath = Join-Path -Path $clonePath -ChildPath "pipeline.yml"
(Get-Content $pipelineFilePath) -replace 'value: RG-', "value: $($resourceGroupName)" `
                                   -replace 'value: Sentinel-', "value: Sentinel-$customer" `
                                   -replace 'value: LA-', "value: $($workspaceName)" |
    Set-Content $pipelineFilePath

# Git commit a push
Set-Location $clonePath
git add .
git commit -m "Add DevOps pipeline configuration"
git push
Set-Location $PSScriptRoot

# === AUTENTIZACE (PAT) ===
$pat = "DtTpngksSHlYuevZCA1YQZQZEv6RckmvWF1EsX5mH2zpHGJpsbS7JQQJ99BCACAAAAAVWrSRAAASAZDO2Ypx"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$headers = @{ Authorization = "Basic $base64AuthInfo" }

$configPath = "DevOps.json"
$config = Get-Content $configPath | ConvertFrom-Json

# Customer
$customer = $config.customer
$repoNameBase = $config.repoName
$repoName = "$repoNameBase-$customer"
$projectName = $config.projectName
$devOpsOrg = $config.devOpsOrg
$devOpsOrgUrl = $config.devOpsOrgUrl

# Git URL a cesta
$gitUrl = "git@ssh.dev.azure.com:v3/$devOpsOrg/$projectName/$repoName"
$clonePath = Join-Path -Path $PWD -ChildPath $repoName
$workspaceName

# === ZÍSKÁNÍ REPOSITORY ID ZOZNAMEM ===
$reposUri = "https://dev.azure.com/$devOpsOrg/$projectName/_apis/git/repositories?api-version=7.1-preview.1"
$reposResponse = Invoke-RestMethod -Uri $reposUri -Headers $headers -Method Get

$repo = $reposResponse.value | Where-Object { $_.name -eq $repoName }

if (-not $repo) {
    Write-Error "❌ Repozitář '$repoName' nebyl nalezen v projektu '$projectName'"
    Write-Host "Dostupné repozitáře:"
    $reposResponse.value.name
    exit 1
}

$repoId = $repo.id
Write-Host "✅ Repository ID: $repoId"

# === VYTVOŘENÍ PIPELINE ===
$pipelineName = "CI-$repoName"
$branch = "main"  # přizpůsob podle skutečné větve

$body = @{
    name = $pipelineName
    configuration = @{
        type = "yaml"
        path = "pipeline.yml"
        repository = @{
            id = $repoId
            name = $repoName
            type = "azureReposGit"
            defaultBranch = "refs/heads/$branch"
        }
    }
} | ConvertTo-Json -Depth 10

$uri = "https://dev.azure.com/$devOpsOrg/$projectName/_apis/pipelines?api-version=7.1-preview.1"

Write-Host "Creating pipeline '$pipelineName'..."
$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body -ContentType "application/json"

if ($response.id) {
    Write-Host "✅ Pipeline '$pipelineName' created successfully (ID: $($response.id))"
} else {
    Write-Error "❌ Pipeline creation failed"
}

# === SPUŠTĚNÍ PIPELINE ===
if ($response.id) {
    $runUri = "https://dev.azure.com/$devOpsOrg/$projectName/_apis/pipelines/$($response.id)/runs?api-version=7.1-preview.1"
    $runBody = @{
        resources = @{ repositories = @{ self = @{ refName = "refs/heads/$branch" } } }
    } | ConvertTo-Json -Depth 10

    $runResponse = Invoke-RestMethod -Uri $runUri -Method Post -Headers $headers -Body $runBody -ContentType "application/json"
    Write-Host "🚀 Pipeline spuštěna (Run ID: $($runResponse.id))"
}

# === SMAZÁNÍ LOKÁLNÍ KOPIE REPOZITÁŘE ===
if (Test-Path $clonePath) {
    Remove-Item -Path $clonePath -Recurse -Force
    Write-Host "🧹 Lokální složka '$repoName' byla odstraněna."
}