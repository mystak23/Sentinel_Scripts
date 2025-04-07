$TenantID = Read-Host "🔹 Enter the tenant ID: "
$WindowsDefenderAtpAppId = Read-Host "🔹 Enter the "Windows Defender ATP" App ID: "
$DisplayNameOfMSI = Read-Host "🔹 Enter the Logic App Name Name: "
$PermissionName = "AdvancedQuery.Read.All" 

Write-Host "Tenant ID: $TenantID"
Write-Host "Graph App ID: $GraphAppId"
Write-Host "Graph App Name: $DisplayNameOfMSI"

Connect-MgGraph -TenantId $TenantID -NoWelcome

$MSI = (Get-MgServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'") 
$GraphServicePrincipal = Get-MgServicePrincipal -Filter "appId eq '$WindowsDefenderAtpAppId'" 
$AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $PermissionName -and $_.AllowedMemberTypes -contains "Application"} 

Write-Host "MSI Id: $($MSI.Id)"
Write-Host "Graph Service Principal Id: $($GraphServicePrincipal.Id)"
Write-Host "App Role Id: $($AppRole.Id)"

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $MSI.Id -PrincipalId $MSI.Id -ResourceId $GraphServicePrincipal.Id -AppRoleId $AppRole.Id