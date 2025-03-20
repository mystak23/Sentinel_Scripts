## Script that finds duplicate rules in the customer's repository 

Write-Host "🔹 Don't forget to log in to Azure CLI (az login)!"
$customer = Read-Host "🔹 Enter the customer name: "

$directoryPath = "/Users/mystak23/SentinelRepository/Seyfor.DevOps/Sentinel-$customer/4-AnalyticRules"
$outputFile = "DuplicateId.txt"

# Find all JSON files in the given directory and its subdirectories
$jsonFiles = Get-ChildItem -Path $directoryPath -Recurse -Filter "*.json"

# HashTable to track rule IDs, rule names, and file paths
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

# Check if there is any data in the hash table
if ($idCounts.Count -eq 0) {
    "No analytic rules were found." | Out-File -FilePath $outputFile
    exit
}

# Save all found rule IDs
"All found rule IDs:" | Out-File -FilePath $outputFile
foreach ($ruleId in $idCounts.Keys) {
    $ruleId | Out-File -FilePath $outputFile -Append
}

# Save duplicate rule IDs, their names, and file paths
"`nDuplicate rule IDs:" | Out-File -FilePath $outputFile -Append
$hasDuplicates = $false
foreach ($ruleId in $idCounts.Keys) {
    if ($idCounts[$ruleId] -gt 1) {
        $hasDuplicates = $true
        $count = $idCounts[$ruleId]
        $ruleNames = ($idNames[$ruleId] | Select-Object -Unique) -join ", "  # Remove duplicate names
        $filePaths = ($idPaths[$ruleId] | Select-Object -Unique) -join "`n  "  # Remove duplicate paths
        
        "$ruleId (Count: $count) - Names: $ruleNames" | Out-File -FilePath $outputFile -Append
        "  File paths:`n  $filePaths" | Out-File -FilePath $outputFile -Append
    }
}

# If no duplicates are found, inform the user
if (-not $hasDuplicates) {
    "No duplicate rules were found." | Out-File -FilePath $outputFile -Append
}

Write-Host "The output has been saved to $outputFile"