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
Function Export-AzSentinelAutomationRuleToJSON ($workspaceName, $resourceGroupName, $WatchListName) {

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
    $url = "https://management.azure.com/subscriptions/$($subscriptionId)/resourceGroups/$($resourceGroupName)/providers/Microsoft.OperationalInsights/workspaces/$($workspaceName)/providers/Microsoft.SecurityInsights/watchlists/$($WatchListName)/watchlistItems?api-version=2021-10-01"
    $results = (Invoke-RestMethod -Method "Get" -Uri $url -Headers $authHeader )
    $resultJson = ConvertTo-Json $results -depth 100
    return $resultJson

}

$characters = [regex]('\r\n')

$WatchListNames = Get-ChildItem -Path $rootDirectory\1-Watchlists | Select-Object -ExpandProperty Basename

foreach ($Watchlist in $WatchListNames)
{
    if ($Watchlist -eq "Automation_Names") {
        Write-Host "Skipping update for Watchlist: $Watchlist"
        
    }

    elseif ($Watchlist -eq "Analytics_Names") {
        Write-Host "Skipping update for Watchlist: $Watchlist"
        
    }

    else {
            # Runs function to get values for ARM template
    $GetWatchListValues = Export-AzSentinelAutomationRuleToJSON $WorkSpaceName $ResourceGroupName $Watchlist

    $JsonWatchListName = "$Watchlist.json"
    # Parses recieved JSON file from API call in order to get key value pairs in required format
    $parsedJson = $GetWatchListValues | ConvertFrom-Json | foreach-Object { $_.value.properties.itemsKeyValue } | ConvertTo-Csv -UseQuotes AsNeeded | ForEach-Object { $_ + $characters }
    
    # Make a single string for rawConent key without any spaces in between 
    $JoinedString = $parsedJson -join ""

    #Loads ARM template, updates values and saves it 
    $OpenARMTemplate = Get-Content "$rootDirectory\1-Watchlists\$JsonWatchListName" -Raw | ConvertFrom-Json
    $OpenARMTemplate.resources[0]."properties"."rawContent" = $JoinedString 
    ($OpenARMTemplate | ConvertTo-Json -Depth 100 ).Replace('\\r\\n','\r\n') | Out-File "$rootDirectory\1-Watchlists\$JsonWatchListName"
    
    Write-Host "Updated Watchlist: $Watchlist"
    }

}

