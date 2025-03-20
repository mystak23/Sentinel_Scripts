## Skript, který v repozitáři zákazníka najde duplikátní pravidla 

Write-Host "🔹 Nezapomeň se přihlásit k Azure CLI (az login)!"
$customer = Read-Host "🔹 Zadejte název zákazníka: "

$directoryPath = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-$customer/4-AnalyticRules"
$outputFile = "DuplicateId.txt"

# Najde všechny JSON soubory v daném adresáři a podadresářích
$jsonFiles = Get-ChildItem -Path $directoryPath -Recurse -Filter "*.json"

# HashTable pro sledování ID, názvů pravidel a cest k souborům
$idCounts = @{}
$idNames = @{}
$idPaths = @{}

foreach ($file in $jsonFiles) {
    $content = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($content -and $content.resources) {
        foreach ($resource in $content.resources) {
            if ($resource.name -match "/Microsoft.SecurityInsights/([^/]+)$") {
                $ruleId = $matches[1]
                $ruleName = $resource.properties.displayName
                $filePath = $file.FullName
                
                if ($ruleId) {
                    if (-not $idCounts.ContainsKey($ruleId)) {
                        $idCounts[$ruleId] = 0
                        $idNames[$ruleId] = @()
                        $idPaths[$ruleId] = @()
                    }
                    
                    $idCounts[$ruleId] += 1
                    $idNames[$ruleId] += $ruleName
                    $idPaths[$ruleId] += $filePath
                }
            }
        }
    }
}

# Zkontrolujeme, zda jsou nějaká data v hash tabulce
if ($idCounts.Count -eq 0) {
    "Žádná analytická pravidla nebyla nalezena." | Out-File -FilePath $outputFile
    exit
}

# Uložení všech ID pravidel
"Všechna nalezená ID pravidel:" | Out-File -FilePath $outputFile
foreach ($ruleId in $idCounts.Keys) {
    $ruleId | Out-File -FilePath $outputFile -Append
}

# Uložení duplikátních ID, jejich názvů a cest k souborům
"`nDuplikátní ID pravidel:" | Out-File -FilePath $outputFile -Append
$hasDuplicates = $false
foreach ($ruleId in $idCounts.Keys) {
    if ($idCounts[$ruleId] -gt 1) {
        $hasDuplicates = $true
        $count = $idCounts[$ruleId]
        $ruleNames = ($idNames[$ruleId] | Select-Object -Unique) -join ", "  # Odstranění duplicitních názvů
        $filePaths = ($idPaths[$ruleId] | Select-Object -Unique) -join "`n  "  # Odstranění duplicitních cest
        
        "$ruleId (Počet: $count) - Názvy: $ruleNames" | Out-File -FilePath $outputFile -Append
        "  Cesty k souborům:`n  $filePaths" | Out-File -FilePath $outputFile -Append
    }
}

# Pokud nejsou duplikáty, informujeme uživatele
if (-not $hasDuplicates) {
    "Žádná duplikátní pravidla nebyla nalezena." | Out-File -FilePath $outputFile -Append
}

Write-Host "Výstup byl uložen do $outputFile"
