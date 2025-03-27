# Author

Matěj Hrabálek -- https://www.linkedin.com/in/matejhrabalek/

# 📌 Sentinel Scripts

This repository contains useful scripts for automating and managing **Microsoft Sentinel**.

## 📂 Repository Structure

- **Exports/** – Contains export templates and files related to Logic Apps.

- **CustomerContentDifference.py** – A Python script for detecting difference between central repository and customer repository.
- **GetDuplicateRuleId.ps1** – PowerShell script for identifying duplicate rule IDs in the customer's Microsoft Sentinel repository.
- **ChangeArchiveRetection.ps1** – PowerShell script for modifying archive detection in specified tables in Log Analytics Workspace.
- **MacOsExportLogicAppTemplate.ps1** – Export template for Azure Logic Apps on macOS.
- **WindowsExportLogicAppTemplate.ps1** – Export template for Azure Logic Apps on Windows.

# 🚀 Deployment Guide

## 1️⃣ Prerequisites

Ensure you have the following:
- **Microsoft Sentinel** with appropriate permissions.
- **Azure Logic Apps** (if working with Logic App templates).
- **PowerShell 7+** (for executing `.ps1` scripts).
- **Python 3.x** (if using `.py` scripts).
- **Owner** permissions on the target Azure subscription
- **Security Administrator or Global Administrator** permissions in tenant (not for every script)
-  **`./CustomerAzureValues.json`** for customer-specific values - or change the script

## 2️⃣ Deployment Steps

### 1️⃣ Run the script

Run the script

`./SentinelDeploy.ps1`

### 2️⃣ Enter parameters

RgName: `<your_RG_name>`
WorkspaceName: `<your_LA_name>`
