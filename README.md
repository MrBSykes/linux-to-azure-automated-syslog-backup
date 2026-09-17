# 🐧☁️ Linux to Azure: Automated System Log Backup
### Ubuntu CLI → Azure CLI → Blob Storage → Cron Automation

![Ubuntu](https://img.shields.io/badge/Ubuntu-26.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Azure](https://img.shields.io/badge/Azure-Blob_Storage-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-Scripting-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)
![Cron](https://img.shields.io/badge/Cron-Automated_Daily-6C757D?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Complete-2ea44f?style=for-the-badge)

---

## Overview

This project builds an automated pipeline that compresses Ubuntu system logs on a physical home lab machine and uploads them to **Microsoft Azure Blob Storage** on a daily cron schedule executed entirely from the command line over SSH.

No GUI tools were used at any stage. Every Azure resource was provisioned, configured, and verified through the **Azure CLI** running inside an SSH terminal session from a Windows desktop workstation.

> **Why this matters:** Log management and cloud storage pipelines are core to federal IT and cloud operations roles. This project demonstrates that combination. Hands-on Linux CLI, Azure resource provisioning, RBAC configuration, bash scripting, and automation in a single working system.

---

## Architecture

```
sykes-ubuntu (ASUS X550ZA)
     │
     │  SSH from SYKES-DESKTOP (192.168.1.162)
     │
     ├── /var/log/syslog
     │        │
     │        │  gzip compression (daily via cron @ midnight)
     │        ▼
     │   /tmp/syslog-YYYY-MM-DD.gz
     │        │
     │        │  az storage blob upload (Azure CLI)
     │        ▼
     └──▶ Azure Blob Storage
              └── sykeslogstorage / syslogs / syslog-YYYY-MM-DD.gz
```

---

## Azure Resources

| Resource | Name | Configuration |
|---|---|---|
| **Resource Group** | LinuxLogsRG | East US |
| **Storage Account** | sykeslogstorage | Standard LRS, StorageV2, HTTPS-only, SSE enabled |
| **Blob Container** | syslogs | Private access |
| **RBAC Role** | Storage Blob Data Contributor | Assigned at storage account scope via Object ID |

---

## Source Machine

| Component | Spec |
|---|---|
| **Hostname** | sykes-ubuntu |
| **Hardware** | ASUS X550ZA — AMD A8-7100, 8GB DDR3, 256GB SATA SSD |
| **OS** | Ubuntu Desktop 26.04 LTS (Resolute Raccoon) |
| **Access** | SSH from primary Windows desktop — no direct physical interaction |
| **Log Source** | /var/log/syslog |

---

## Setup

### 1. Install Azure CLI

```bash
sudo apt install curl -y
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az --version
```

### 2. Authenticate

```bash
az login --use-device-code
```

Go to **microsoft.com/devicelogin**, enter the code, sign in. If you hit a subscription error, specify the tenant directly:

```bash
az login --tenant <your-tenant-id> --use-device-code
```

### 3. Provision Azure Resources

```bash
# Resource Group
az group create --name LinuxLogsRG --location eastus

# Storage Account
az storage account create \
  --name sykeslogstorage \
  --resource-group LinuxLogsRG \
  --location eastus \
  --sku Standard_LRS

# Blob Container
az storage container create \
  --name syslogs \
  --account-name sykeslogstorage \
  --auth-mode login
```

### 4. Assign RBAC Role

```bash
# Get your Object ID
az ad signed-in-user show --query id -o tsv

# Assign Storage Blob Data Contributor
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id <your-object-id> \
  --assignee-principal-type User \
  --scope /subscriptions/<subscription-id>/resourceGroups/LinuxLogsRG/providers/Microsoft.Storage/storageAccounts/sykeslogstorage
```

> **Note:** Use Object ID rather than email when the account is a Yahoo or non-native Microsoft identity email lookup fails in the Azure AD graph for federated accounts.

### 5. Create the Backup Script

```bash
nano ~/backup.sh
```

```bash
#!/bin/bash

STORAGE_ACCOUNT="sykeslogstorage"
CONTAINER="syslogs"
DATE=$(date +%Y-%m-%d)
BACKUP_FILE="/tmp/syslog-$DATE.gz"

# Compress syslog
gzip -c /var/log/syslog > $BACKUP_FILE

# Upload to Azure Blob Storage
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name "syslog-$DATE.gz" \
  --file $BACKUP_FILE \
  --auth-mode login

# Cleanup
rm $BACKUP_FILE

echo "Backup completed: syslog-$DATE.gz uploaded to Azure"
```

```bash
chmod +x ~/backup.sh
~/backup.sh   # test run
```

### 6. Schedule with Cron

```bash
crontab -e
```

Add this line (no `#`):

```
0 0 * * * /home/mrbryansykes/backup.sh >> /home/mrbryansykes/backup.log 2>&1
```

Verify:

```bash
crontab -l
```

---

## Screenshots

| # | Screenshot | Description |
|---|---|---|
| 07 | ![](screenshots/07_Azure_CLI_Login_Success.png) | Azure CLI login — subscription confirmed |
| 09 | ![](screenshots/09_Azure_CLI_Subscription_Confirmed.png) | Azure subscription 1 active |
| 11 | ![](screenshots/11_Azure_Resource_Group_Created.png) | LinuxLogsRG created |
| 12 | ![](screenshots/12_Azure_Storage_Account_Created.png) | sykeslogstorage created |
| 13 | ![](screenshots/13_Backup_Script_Permissions_Error.png) | RBAC error — before role assignment |
| 14 | ![](screenshots/14_Azure_Role_Assignment_Blob_Contributor.png) | Storage Blob Data Contributor assigned |
| 15 | ![](screenshots/15_Backup_Script_Upload_Success.png) | Successful upload — 100% confirmed |

---

## Troubleshooting Log

| # | Issue | Root Cause | Resolution |
|---|---|---|---|
| 1 | az login returned no subscriptions | Ctrl+C interrupted the login flow before completion | Ran az login again and waited for full completion |
| 2 | AADSTS530035 — authentication blocked | Microsoft security defaults block device code auth for Yahoo-federated accounts | Disabled security defaults in Microsoft Entra ID |
| 3 | Full Azure portal lockout | Multiple failed CLI attempts flagged as suspicious | Recovered via account.live.com/password/reset |
| 4 | Subscription visible in portal but not in CLI | CLI defaulted to wrong tenant context | Used az login --tenant <id> --use-device-code |
| 5 | Cannot find user in graph — assignee email error | Yahoo-federated accounts don't resolve by email in Azure AD graph | Used --assignee-object-id with Object ID from az ad signed-in-user show |
| 6 | Permissions error on first backup run | Control plane access ≠ data plane access in Azure — blob write requires explicit RBAC | Assigned Storage Blob Data Contributor role at storage account scope |

---

## AZ-900 Alignment

This project provides hands-on coverage of core AZ-900 exam domains:

- **Cloud Concepts** — Cloud storage models, shared responsibility
- **Azure Architecture** — Resource groups, regions, subscriptions
- **Azure Storage** — Blob storage, Standard LRS, access tiers, containers
- **Identity & Access (RBAC)** — Role assignment, least privilege, Object ID
- **Azure Management Tools** — Azure CLI, device code auth, management interfaces
- **Security** — Encryption in transit, server-side encryption, RBAC over account keys

---

## Next Steps

- [ ] Connect to Azure Monitor / Log Analytics Workspace (Phase 3)
- [ ] Add UFW logs to backup scope
- [ ] Configure blob lifecycle management auto-delete logs after 90 days
- [ ] Add backup failure alerting via backup.log monitoring
- [ ] Configure UFW firewall on sykes-ubuntu (port 22 only)

---

## Related Projects

- [🐧 Linux Lab Machine — Swapping Kali for Ubuntu](#)
- [🏠 Home Lab Server — SYKESHOMESERVER](#)
- [🪟 Active Directory Home Lab — Phase 1](#)
- [🔒 Security Onion Home Lab](#)
- [☁️ AWS GuardDuty Threat Detection](#)

---

## Documentation

Full project documentation (PDF) is available in this repository covering Azure CLI setup, resource provisioning walkthrough, RBAC configuration, bash script, cron automation, troubleshooting log with root cause analysis, and AZ-900 exam alignment mapping.

---

*Bryan Sykes | Home Lab Portfolio | September 2026*
*[![LinkedIn](https://img.shields.io/badge/LinkedIn-SecuredByBryan-0A66C2?style=flat&logo=linkedin)](https://linkedin.com) [![GitHub](https://img.shields.io/badge/GitHub-MrBSykes-181717?style=flat&logo=github)](https://github.com/MrBSykes) [![X](https://img.shields.io/badge/X-@SecuredByBryan-000000?style=flat&logo=x)](https://x.com/SecuredByBryan)*
