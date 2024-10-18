#!/bin/bash
set -e 

fail() {
    echo "$1" >&2
    exit "${2-1}"
}

BACKUP_ARCHIVE_PATH="$1"
BACKUP_NAME="$(basename $BACKUP_ARCHIVE_PATH)"

file $BACKUP_ARCHIVE_PATH | grep -q 'gzip compressed' || fail "Argument must be a tar.gz archive containing a backup"

echo "This will erase the current container data completely. Are you sure?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

echo "Stopping the container..."
docker compose -f ~/monitoring/compose.yaml down prometheus
docker compose -f ~/monitoring/compose.yaml rm prometheus

echo "Recreating the docker volume..."
docker volume rm prometheus-data
docker volume create prometheus-data
echo "Unzipping the backup to the new volume"
docker run --rm -it -v prometheus-data:/backup/prometheus -v ~/backups/:/archive:ro alpine tar -xvzf /archive/$BACKUP_NAME
echo "Restarting the container..."
docker compose -f ~/monitoring/compose.yaml up -d
echo "Completed."