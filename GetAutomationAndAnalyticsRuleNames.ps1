# Needs Workspace name and Resource group name where watchlists are stored
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$WorkSpaceName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$rootDirectory

)

# Will make a API call connection to export Watchlist values from Azure Cloud 
Function Export-AzSentinelAutomationRuleToJSON ($WorkSpaceName, $ResourceGroupName) {

    #Setup the Authentication header needed for API call
    $context = Get-AzContext
    $profile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($profile)
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }
    
    $SubscriptionId = (Get-AzContext).Subscription.Id

    #Gets Watchlists based on their names
    $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/automationRules/?api-version=2021-10-01-preview"
    $results = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader )
    $resultJson = ConvertTo-Json $results -depth 100
    return $resultJson

}

Function Export-AzSentinelAnalyticsRuleToJSON ($WorkSpaceName, $ResourceGroupName) {

    #Setup the Authentication header needed for API call
    $context = Get-AzContext
    $profile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($profile)
    $token = $profileClient.AcquireAccessToken($context.Subscription.TenantId)
    $authHeader = @{
        'Content-Type'  = 'application/json' 
        'Authorization' = 'Bearer ' + $token.AccessToken 
    }
    
    $SubscriptionId = (Get-AzContext).Subscription.Id

    #Gets Watchlists based on their names
    $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/alertRules/?api-version=2021-10-01-preview"
    $results = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader )
    $resultJson = ConvertTo-Json $results -depth 100
    Write-Host $rusults
    return $resultJson

}

$characters = [regex]('\r\n')


$GetAutomationRules = Export-AzSentinelAutomationRuleToJSON $WorkSpaceName $ResourceGroupName 
$parsedId = $GetAutomationRules | ConvertFrom-Json | foreach-Object {  $_.value.name} 
$parsedNames = $GetAutomationRules  | ConvertFrom-Json | foreach-Object { $_.value.properties.displayName} 


[int]$max = $parsedId.Count
if ([int]$parsedNames.count -gt [int]$parsedId.count) { $max = $parsedNames.Count; }
 
$CreateObjectsForAutomation = for ( $i = 0; $i -lt $max; $i++)
{
    Write-Verbose "$($parsedId[$i]),$($parsedNames[$i])"
    [PSCustomObject]@{
        AutomationRuleID = $parsedId[$i]
        AutomationRuleName = $parsedNames[$i]
 
    }
}
$ConvertToCSVAutomation = $CreateObjectsForAutomation | ConvertTo-Csv -UseQuotes AsNeeded | ForEach-Object { $_ + $characters }
$JoinedStringAutomation = $ConvertToCSVAutomation -join ""

$OpenWatchListAutomation = Get-Content "$rootDirectory\1-Watchlists\Automation_Names.json" -Raw | ConvertFrom-Json
$OpenWatchListAutomation.resources[0]."properties"."rawContent" = $JoinedStringAutomation 
($OpenWatchListAutomation | ConvertTo-Json -Depth 100 ).Replace('\\r\\n','\r\n') | Out-File "$rootDirectory\1-Watchlists\Automation_Names.json"

Write-Host "Watchlist Automation_Names was updated"

# Analytics Rule section
$GetAnalyticsRules = Export-AzSentinelAnalyticsRuleToJSON $WorkSpaceName $ResourceGroupName 
$parsedAnalyticsId = $GetAnalyticsRules | ConvertFrom-Json | foreach-Object {  $_.value.name} 
$parsedAnalyticsNames = $GetAnalyticsRules  | ConvertFrom-Json | foreach-Object { $_.value.properties.displayName} 

[int]$max = $parsedAnalyticsId.Count
if ([int]$parsedAnalyticsNames.count -gt [int]$parsedAnalyticsId.count) { $max = $parsedAnalyticsNames.Count; }
 
$CreateObjectsforAnalytics = for ( $i = 0; $i -lt $max; $i++)
{
    Write-Verbose "$($parsedAnalyticsId[$i]),$($parsedAnalyticsNames[$i])"
    [PSCustomObject]@{
        AnalyticsRuleID = $parsedAnalyticsId[$i]
        AnalyticsRuleName = $parsedAnalyticsNames[$i]
 
    }
}

$ConvertToCSVAnalytics = $CreateObjectsforAnalytics | ConvertTo-Csv -UseQuotes AsNeeded | ForEach-Object { $_ + $characters }
$JoinedStringAnalytics = $ConvertToCSVAnalytics -join ""

$OpenWatchListAnalytics = Get-Content "$rootDirectory\1-Watchlists\Analytics_Names.json" -Raw | ConvertFrom-Json
$OpenWatchListAnalytics.resources[0]."properties"."rawContent" = $JoinedStringAnalytics 
($OpenWatchListAnalytics | ConvertTo-Json -Depth 100 ).Replace('\\r\\n','\r\n') | Out-File "$rootDirectory\1-Watchlists\Analytics_Names.json"

Write-Host "Watchlist Analytics_Names was updated"