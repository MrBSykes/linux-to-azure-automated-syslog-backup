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
