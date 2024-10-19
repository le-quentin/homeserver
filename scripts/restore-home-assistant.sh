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
docker compose -f ~/services/docker-volume-backup/compose.yaml rm -f
docker compose -f ~/services/home-assistant/compose.yaml down home-assistant
docker compose -f ~/services/home-assistant/compose.yaml rm home-assistant

echo "Recreating the docker volume..."
docker volume rm home-assistant-data
docker volume create home-assistant-data
echo "Unzipping the backup to the new volume"
docker run --rm -it -v home-assistant-data:/backup/home-assistant -v ~/backups/:/archive:ro alpine tar -xvzf /archive/$BACKUP_NAME
echo "Restarting the container..."
docker compose -f ~/services/home-assistant/compose.yaml up -d
echo "Completed."
