#!/bin/sh
set -e

DATE=$(date +%F-%H%M)
BACKUP_DIR="/backup"
REMOTE="${RCLONE_REMOTE:-gdrive:longhorn-tar-backups}"

echo "📁 Starting backup at $DATE"
mkdir -p "$BACKUP_DIR"

# Loop through all mounted PVCs
for pvc in $(ls /mnt); do
  echo "📦 Backing up PVC: $pvc"
  tar czf "$BACKUP_DIR/$pvc-$DATE.tar.gz" -C "/mnt/$pvc" .
done

echo "☁️ Uploading to $REMOTE/$DATE"
rclone copy "$BACKUP_DIR" "$REMOTE/$DATE" --progress

echo "✅ Backup complete"
