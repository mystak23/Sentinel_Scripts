Write-Host "🔹 Don't forget to log in to Azure CLI (az login)!"

$SubscriptionId = Read-Host "🔹 Enter the subscription ID: "
$RgName = Read-Host "🔹 Enter the Resource Group Name: "
$WorkspaceName = Read-Host "🔹 Enter the Log Analytics Workspace name "

## General content hub variables
$ApiVersion = "2025-03-01"
$BaseUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$RgName/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/contentpackages"

## Automatically obtain Bearer Token
$TokenResponse = az account get-access-token --resource https://management.azure.com | ConvertFrom-Json
$BearerToken = $TokenResponse.accessToken

## Load packages from JSON file 
$JsonFilePath = "values/solutions.json"
$Packages = (Get-Content -Path $JsonFilePath | ConvertFrom-Json).Packages

Write-Host "[START] 📅 Installing Content Hub Packages." -ForegroundColor Blue

## Install packages
foreach ($Package in $Packages) {
    $PackageId = $Package.contentId
    $Url = "$BaseUrl/$($Package.contentId)?api-version=$ApiVersion"
    
    $Body = @{
        properties = @{
            contentId = $Package.contentId
            contentKind = $Package.contentKind
            contentProductId = $Package.contentProductId
            displayName = $Package.displayName
            version = $Package.version
            contentSchemaVersion = $Package.contentSchemaVersion
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        $Response = Invoke-RestMethod -Uri $Url -Method Put -Headers @{
            Authorization = "Bearer $BearerToken"
            "Content-Type" = "application/json"
        } -Body $Body

        Write-Host "[SUCCESS] ✅ Content Hub package $($Package.displayName) installed" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] ❌ Error with installing Content Hub package $($Package.displayName): $_" -ForegroundColor Red
    }
}