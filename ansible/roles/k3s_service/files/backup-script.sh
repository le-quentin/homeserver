#!/bin/sh
set -e

API_SERVER="https://kubernetes.default.svc"
SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"

command -v curl >/dev/null || apk add --no-cache curl
command -v jq >/dev/null || apk add --no-cache jq

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

kube_api_call() {
  method=$1
  endpoint=$2
  data=${3:-}

  if [ -n "$data" ]; then
    response=$(curl -s -X "$method" \
      --cacert "$CA_CERT" \
      -H "Authorization: Bearer $SA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$data" \
      "$API_SERVER$endpoint")
  else
    response=$(curl -s -X "$method" \
      --cacert "$CA_CERT" \
      -H "Authorization: Bearer $SA_TOKEN" \
      "$API_SERVER$endpoint")
  fi

  if [ "${DEBUG:-false}" = "true" ]; then
    log "DEBUG: [$method $endpoint] Response: $response" >&2
  fi

  echo "$response"
}

mkdir -p /tmp/rclone
cp $RCLONE_CONFIG /tmp/rclone/rclone.conf
export RCLONE_CONFIG=/tmp/rclone/rclone.conf

log "🚀 Starting backup for all defined PVCs"

SKIPPED_PVCS=""
VOLUME_DATA=$(echo "$DATA_VOLUMES_JSON" | jq -c '.[]')

for entry in $VOLUME_DATA; do
  PVC_NAME=$(echo "$entry" | jq -r .name)
  PVC_NAMESPACE="$NAMESPACE"
  SNAPSHOT_NAME="backup-$(date +%Y%m%d-%H%M%S)"
  SNAPSHOT_CLASS="longhorn-snapshot-class"
  TMP_PVC_NAME="${SNAPSHOT_NAME}-tmp"
  MOUNT_PATH="/mnt/${PVC_NAMESPACE}-${PVC_NAME}"
  ARCHIVE_NAME="${PVC_NAMESPACE}-${PVC_NAME}-$(date +%Y%m%d-%H%M).tar.gz"
  BACKUP_DIR="/tmp/backup"

  log "📦 Processing PVC: $PVC_NAME (namespace: $PVC_NAMESPACE)"

  PVC_JSON=$(kube_api_call GET "/api/v1/namespaces/$PVC_NAMESPACE/persistentvolumeclaims/$PVC_NAME")
  if echo "$PVC_JSON" | jq -e '.status.capacity.storage' >/dev/null 2>&1; then
    PVC_SIZE=$(echo "$PVC_JSON" | jq -r '.status.capacity.storage')
  else
    log "❌ Could not determine PVC size for $PVC_NAME in $PVC_NAMESPACE"
    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
    continue
  fi

  # Create VolumeSnapshot
  log "📸 Creating CSI VolumeSnapshot: $SNAPSHOT_NAME"
  SNAPSHOT_PAYLOAD=$(cat <<EOF
{
  "apiVersion": "snapshot.storage.k8s.io/v1",
  "kind": "VolumeSnapshot",
  "metadata": {
    "name": "$SNAPSHOT_NAME",
    "namespace": "$PVC_NAMESPACE"
  },
  "spec": {
    "volumeSnapshotClassName": "$SNAPSHOT_CLASS",
    "source": {
      "persistentVolumeClaimName": "$PVC_NAME"
    }
  }
}
EOF
  )
  kube_api_call POST "/apis/snapshot.storage.k8s.io/v1/namespaces/$PVC_NAMESPACE/volumesnapshots" "$SNAPSHOT_PAYLOAD"

  # Wait for snapshot to be ready
  log "⏳ Waiting for snapshot to be ready..."
  for i in $(seq 1 30); do
    SNAPSHOT_JSON=$(kube_api_call GET "/apis/snapshot.storage.k8s.io/v1/namespaces/$PVC_NAMESPACE/volumesnapshots/$SNAPSHOT_NAME")
    READY=$(echo "$SNAPSHOT_JSON" | jq -r '.status.readyToUse // false')
    [ "$READY" = "true" ] && break
    sleep 5
  done

  if [ "$READY" != "true" ]; then
    log "❌ Snapshot $SNAPSHOT_NAME was not ready in time. Skipping."
    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
    continue
  fi

  # Create temp PVC from snapshot
  log "🧱 Creating temp PVC $TMP_PVC_NAME from snapshot"
  PVC_FROM_SNAP_PAYLOAD=$(cat <<EOF
{
  "apiVersion": "v1",
  "kind": "PersistentVolumeClaim",
  "metadata": {
    "name": "$TMP_PVC_NAME",
    "namespace": "$PVC_NAMESPACE"
  },
  "spec": {
    "accessModes": ["ReadWriteOnce"],
    "resources": {
      "requests": {
        "storage": "$PVC_SIZE"
      }
    },
    "storageClassName": "longhorn-simple",
    "dataSource": {
      "name": "$SNAPSHOT_NAME",
      "kind": "VolumeSnapshot",
      "apiGroup": "snapshot.storage.k8s.io"
    }
  }
}
EOF
  )
  kube_api_call POST "/api/v1/namespaces/$PVC_NAMESPACE/persistentvolumeclaims" "$PVC_FROM_SNAP_PAYLOAD"

  # Wait for PVC to be bound
  log "⏳ Waiting for PVC to be Bound..."
  for i in $(seq 1 30); do
    BOUND=$(kube_api_call GET "/api/v1/namespaces/$PVC_NAMESPACE/persistentvolumeclaims/$TMP_PVC_NAME" | jq -r '.status.phase')
    [ "$BOUND" = "Bound" ] && break
    sleep 5
  done

  if [ "$BOUND" != "Bound" ]; then
    log "❌ Temp PVC $TMP_PVC_NAME not bound in time. Skipping."
    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
    continue
  fi

  BACKUP_JOB_NAME="backup-${TMP_PVC_NAME}-job"
  log "🚀 Launching helper job $BACKUP_JOB_NAME to archive and upload"

  JOB_PAYLOAD=$(cat <<EOF
{
  "apiVersion": "batch/v1",
  "kind": "Job",
  "metadata": {
    "name": "${BACKUP_JOB_NAME}",
    "namespace": "${PVC_NAMESPACE}"
  },
  "spec": {
    "ttlSecondsAfterFinished": 60,
    "template": {
      "spec": {
        "restartPolicy": "Never",
        "containers": [
          {
            "name": "backup",
            "image": "rclone/rclone:sha-61c3b27",
            "command": ["/bin/sh", "/scripts/backup.sh"],
            "env": [
              { "name": "PVC_NAME", "value": "${PVC_NAME}" },
              { "name": "RCLONE_REMOTE", "value": "${RCLONE_REMOTE}" },
              { "name": "ARCHIVE_NAME", "value": "${ARCHIVE_NAME}" }
            ],
            "volumeMounts": [
              { "name": "data", "mountPath": "/mnt/data" },
              { "name": "rclone-config", "mountPath": "/config", "readOnly": true },
              { "name": "backup-script", "mountPath": "/scripts", "readOnly": true },
              { "name": "backup-tmp", "mountPath": "/tmp/backup" }
            ]
          }
        ],
        "volumes": [
          { "name": "data", "persistentVolumeClaim": { "claimName": "${TMP_PVC_NAME}" } },
          { "name": "rclone-config", "secret": { "secretName": "rclone-config" } },
          { "name": "backup-script", "configMap": { "name": "backup-pvc-script", "defaultMode": 493 } },
          { "name": "backup-tmp", "emptyDir": {} }
        ]
      }
    }
  }
}
EOF
)

  kube_api_call POST "/apis/batch/v1/namespaces/$PVC_NAMESPACE/jobs" "$JOB_PAYLOAD"

  # Wait for the Job to be created and available
  log "⏳ Waiting for backup Job to be created..."
  for i in $(seq 1 10); do
    JOB_JSON=$(kube_api_call GET "/apis/batch/v1/namespaces/$PVC_NAMESPACE/jobs/$BACKUP_JOB_NAME")
    JOB_EXISTS=$(echo "$JOB_JSON" | jq -r '.metadata.name // empty')
    if [ "$JOB_EXISTS" = "$BACKUP_JOB_NAME" ]; then
      break
    fi
    sleep 2
  done

  if [ "$JOB_EXISTS" != "$BACKUP_JOB_NAME" ]; then
    log "❌ Backup job $BACKUP_JOB_NAME not found after retries. Skipping."
    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
    continue
  fi

  # Wait for Job to complete
  log "⏳ Waiting for backup Job to complete..."
  for i in $(seq 1 60); do
    JOB_STATUS=$(kube_api_call GET "/apis/batch/v1/namespaces/$PVC_NAMESPACE/jobs/$BACKUP_JOB_NAME")
    SUCCEEDED=$(echo "$JOB_STATUS" | jq -r '.status.succeeded // 0')
    FAILED=$(echo "$JOB_STATUS" | jq -r '.status.failed // 0')
    [ "$SUCCEEDED" = "1" ] && break
    [ "$FAILED" != "0" ] && log "❌ Backup job failed." && break
    sleep 5
  done

  if [ "$SUCCEEDED" != "1" ]; then
    log "❌ Backup job $BACKUP_JOB_NAME failed. Skipping."
    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
    continue
  fi

  # Stream logs from job pod
  POD_NAME=$(kube_api_call GET "/api/v1/namespaces/$PVC_NAMESPACE/pods?labelSelector=job-name=$JOB_NAME" \
    | jq -r '.items[0].metadata.name')
  log "📜 Logs from Job $JOB_NAME:"
  kube_api_call GET "/api/v1/namespaces/$PVC_NAMESPACE/pods/$POD_NAME/log"

  # Cleanup
  log "🧹 Cleaning up temp PVC and snapshot"
  kube_api_call DELETE "/api/v1/namespaces/$PVC_NAMESPACE/persistentvolumeclaims/$TMP_PVC_NAME"
  kube_api_call DELETE "/apis/snapshot.storage.k8s.io/v1/namespaces/$PVC_NAMESPACE/volumesnapshots/$SNAPSHOT_NAME"

  log "✅ Done with $PVC_NAMESPACE/$PVC_NAME"
done

if [ -z "$SKIPPED_PVCS" ]; then
  log "🎉 All backups complete."
else
  log "⚠️ Backups completed with some skipped volumes:"
  for skipped in $SKIPPED_PVCS; do
    log "  - $skipped"
  done
fi


# First attempt, using longhorn API to create snapshots and temporary volumes
##!/bin/sh
#set -e
#
#API_SERVER="https://kubernetes.default.svc"
#SA_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
#CA_CERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
#
#command -v curl >/dev/null || apk add --no-cache curl
#command -v jq >/dev/null || apk add --no-cache jq
#
#log() {
#  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
#}
#
#kube_api_call() {
#  method=$1
#  endpoint=$2
#  data=${3:-}
#
#  if [ -n "$data" ]; then
#    response=$(curl -s -X "$method" \
#      --cacert "$CA_CERT" \
#      -H "Authorization: Bearer $SA_TOKEN" \
#      -H "Content-Type: application/json" \
#      -d "$data" \
#      "$API_SERVER$endpoint")
#  else
#    response=$(curl -s -X "$method" \
#      --cacert "$CA_CERT" \
#      -H "Authorization: Bearer $SA_TOKEN" \
#      "$API_SERVER$endpoint")
#  fi
#
#  if  [ "${DEBUG:-false}" == "true" ]; then
#      log "DEBUG: [$method $endpoint] Response: $response" >&2
#  fi
#
#  echo "$response"
#}
#
#to_bytes() {
#  value="$1"
#  case "$value" in
#    *Ki) echo $(( ${value%Ki} * 1024 )) ;;
#    *Mi) echo $(( ${value%Mi} * 1024 * 1024 )) ;;
#    *Gi) echo $(( ${value%Gi} * 1024 * 1024 * 1024 )) ;;
#    *Ti) echo $(( ${value%Ti} * 1024 * 1024 * 1024 * 1024 )) ;;
#    *) echo "$value" ;;  # Assume it's already raw bytes
#  esac
#}
#
#VOLUME_DATA=$(echo "$DATA_VOLUMES_JSON" | jq -c '.[]')
#
#log "🚀 Starting backup for all defined PVCs"
#
#SKIPPED_PVCS=""
#for entry in $VOLUME_DATA; do
#  PVC_NAME=$(echo "$entry" | jq -r .name)
#  PVC_NAMESPACE="$NAMESPACE"
#  SNAPSHOT_NAME="backup-$(date +%Y%m%d-%H%M%S)"
#  MOUNT_PATH="/mnt/${PVC_NAMESPACE}-${PVC_NAME}"
#  ARCHIVE_NAME="${PVC_NAMESPACE}-${PVC_NAME}-$(date +%Y%m%d-%H%M).tar.gz"
#  BACKUP_DIR="/tmp/backup"
#
#  log "📦 Processing PVC: $PVC_NAME (namespace: $PVC_NAMESPACE)"
#
#  # Get PVC size from original PVC
#  PVC_JSON=$(kube_api_call GET "/api/v1/namespaces/$PVC_NAMESPACE/persistentvolumeclaims/$PVC_NAME")
#  if echo "$PVC_JSON" | jq -e '.status.capacity.storage' >/dev/null 2>&1; then
#    PVC_SIZE_RAW=$(echo "$PVC_JSON" | jq -r '.status.capacity.storage')
#    PVC_SIZE=$(to_bytes "$PVC_SIZE_RAW")
#    PV_NAME=$(echo "$PVC_JSON" | jq -r '.spec.volumeName')
#  else
#    log "❌ Could not determine PVC size for $PVC_NAME in $PVC_NAMESPACE"
#    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
#    continue
#  fi
#
#  log "📏 Detected PVC size: $PVC_SIZE"
#  log "🔗 Bound PV name (Longhorn volume name): $PV_NAME"
#
#  # Get last snapshot, or create one if none exists
#  VOLUME_NAME="$PV_NAME"
#  VOLUME_JSON=$(kube_api_call GET "/apis/longhorn.io/v1beta2/namespaces/longhorn-system/volumes/$VOLUME_NAME")
#  SNAPSHOT_NAME=""
#  if echo "$VOLUME_JSON" | jq -e '.status.snapshots | type == "object"' >/dev/null 2>&1; then
#    SNAPSHOT_NAME=$(echo "$VOLUME_JSON" | jq -r '.status.snapshots | keys_unsorted | sort | reverse | .[0]')
#  fi
#
##  if [ -n "$SNAPSHOT_NAME" ]; then
##    log "✅ Using existing snapshot: $SNAPSHOT_NAME"
##  else
##    log "❌ The backups are created from snapshots, and this volume doesn't have any. Skipping."
##    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
##    continue
#  SNAPSHOT_NAME="backup-$(date +%Y%m%d-%H%M%S)"
#  log "📸 Creating snapshot $SNAPSHOT_NAME on volume $VOLUME_NAME"
#  SNAPSHOT_PAYLOAD=$(cat <<EOF
#{
#  "apiVersion": "longhorn.io/v1beta2",
#  "kind": "SnapshotInput",
#  "name": "$SNAPSHOT_NAME"
#}
#
#EOF
#  )
#  kube_api_call POST "/apis/longhorn.io/v1beta2/namespaces/$LONGHORN_NAMESPACE/volumes/$VOLUME_NAME?action=snapshotCRCreate" "$SNAPSHOT_PAYLOAD"  fi
##  fi
#
#  # Create temporary volume from snapshot
#  TMP_VOLUME_NAME="backup-tmp-$(echo "$VOLUME_NAME" | cut -c1-10)-$(date +%Y%m%d-%H%M%S)"
#  log "🧱 Creating temporary volume from snapshot $SNAPSHOT_NAME"
#  CREATE_VOLUME_PAYLOAD=$(cat <<EOF
#{
#  "apiVersion": "longhorn.io/v1beta2",
#  "kind": "Volume",
#  "metadata": {
#    "name": "$TMP_VOLUME_NAME",
#    "labels": {
#      "backup-script/temp-volume": "true"
#    }
#  },
#  "spec": {
#    "fromSnapshot": "$SNAPSHOT_NAME",
#    "numberOfReplicas": 1,
#    "size": "$PVC_SIZE",
#    "frontend": "blockdev"
#  }
#}
#EOF
#  )
#  CREATE_RESPONSE=$(kube_api_call POST "/apis/longhorn.io/v1beta2/namespaces/$LONGHORN_NAMESPACE/volumes" "$CREATE_VOLUME_PAYLOAD")
#  KIND=$(echo "$CREATE_RESPONSE" | jq -r '.kind // empty')
#  if [ "$KIND" != "Volume" ]; then
#    log "❌ Failed to create volume $TMP_VOLUME_NAME"
#    log "🧪 Response: $CREATE_RESPONSE"
#    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
#    continue
#  fi
#
#  log "⏳ Waiting for volume $TMP_VOLUME_NAME to become attached..."
#  ATTACHED=""
#  for i in $(seq 1 30); do
#    VOLUME_JSON=$(kube_api_call GET "/apis/longhorn.io/v1beta2/namespaces/$LONGHORN_NAMESPACE/volumes/$TMP_VOLUME_NAME")
#    STATUS=$(echo "$VOLUME_JSON" | jq -r '.status // empty')
#
#    if [ "$STATUS" != "Failure" ]; then
#      ATTACHED=$(echo "$VOLUME_JSON" | jq -r '.status.state')
#      if [ "$ATTACHED" == "attached" ]; then
#        continue
#      fi
#    fi
#
#    log "⏳ Volume $TMP_VOLUME_NAME is not attached yet. Retrying..."
#    sleep 2
#  done
#
#  if [ "$ATTACHED" != "attached" ]; then
#    log "❌ Volume $TMP_VOLUME_NAME failed to attach. Skipping."
#    SKIPPED_PVCS="$SKIPPED_PVCS ${PVC_NAMESPACE}/${PVC_NAME}"
#    continue
#  fi
#
#  # Mount + backup
#  mkdir -p "$MOUNT_PATH" "$BACKUP_DIR"
#  log "📁 Archiving contents from $MOUNT_PATH"
#  tar czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$MOUNT_PATH" .
#
#  log "☁️ Uploading to $RCLONE_REMOTE/$ARCHIVE_NAME"
#  rclone copy "$BACKUP_DIR/$ARCHIVE_NAME" "$RCLONE_REMOTE/" --progress
#
#  # Cleanup
#  log "🧹 Cleaning up volume $TMP_VOLUME_NAME"
#  kube_api_call DELETE "/apis/longhorn.io/v1beta2/namespaces/longhorn-system/volumes/$TMP_VOLUME_NAME"
#
#  log "✅ Done with $PVC_NAMESPACE/$PVC_NAME"
#done
#
#if [ -z "$SKIPPED_PVCS" ]; then
#  log "🎉 All backups complete."
#else
#  log "⚠️ Backups completed with some skipped volumes:"
#  for skipped in $SKIPPED_PVCS; do
#    log "  - $skipped"
#  done
#fi
#
