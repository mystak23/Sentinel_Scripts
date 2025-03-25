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

# === ÚPRAVA pipeline.yml PROMĚNNÝCH ===
$pipelineFilePath = Join-Path -Path $clonePath -ChildPath "pipeline.yml"
(Get-Content $pipelineFilePath) -replace 'value: RG-', "value: $($workspaceName)" `
                                   -replace 'value: Sentinel-', "value: Sentinel-$customer" `
                                   -replace 'value: LA-', "value: $($resourceGroupName)" |
    Set-Content $pipelineFilePath

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