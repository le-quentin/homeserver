#!/bin/sh
set -e

# Parameters from environment variables
PVC_NAMESPACE=${PVC_NAMESPACE}
PVC_NAME=${PVC_NAME}
RCLONE_REMOTE=${RCLONE_REMOTE}
K3S_SERVICE_NAME=${K3S_SERVICE_NAME}

# Use the rclone config from the mounted secret
mkdir -p /tmp/rclone
cp /config/rclone.conf /tmp/rclone/rclone.conf
export RCLONE_CONFIG=/tmp/rclone/rclone.conf

# Construct the backup pattern
BACKUP_PATTERN="${PVC_NAMESPACE}-${PVC_NAME}-*.tar.gz"

# Determine the latest backup
LATEST_BACKUP=$(rclone lsf "$RCLONE_REMOTE" --max-depth 1 | grep "$BACKUP_PATTERN" | sort | tail -n 1)

if [ -z "$LATEST_BACKUP" ]; then
  echo "No backup found for PVC $PVC_NAME in namespace $PVC_NAMESPACE"
  exit 1
fi

echo "Restoring from backup: $LATEST_BACKUP"

# Download and extract the backup
rclone copy "$RCLONE_REMOTE/$LATEST_BACKUP" /tmp/restore/
tar -xzf /tmp/restore/$LATEST_BACKUP -C /tmp/restore/

# Stop the pod(s) using the PVC
kubectl scale deployment "$K3S_SERVICE_NAME" --replicas=0 -n $PVC_NAMESPACE

# Create a temporary pod to restore data
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: restore-pod
  namespace: $PVC_NAMESPACE
spec:
  containers:
  - name: restore-container
    image: busybox
    command: ["/bin/sh", "-c", "while true; do sleep 3600; done"]
    volumeMounts:
    - mountPath: /restore
      name: restore-volume
    - mountPath: /config
      name: rclone-config
  volumes:
  - name: restore-volume
    persistentVolumeClaim:
      claimName: $PVC_NAME
  - name: rclone-config
    secret:
      secretName: rclone-config
EOF

# Wait for the temporary pod to be ready
kubectl wait --for=condition=Ready pod/restore-pod -n $PVC_NAMESPACE --timeout=60s

# Copy data into the PVC
kubectl cp /tmp/restore/. $PVC_NAMESPACE/restore-pod:/restore

# Clean up the temporary pod
kubectl delete pod restore-pod -n $PVC_NAMESPACE

# Start the pod(s) again
kubectl scale deployment "$K3S_SERVICE_NAME" --replicas=1 -n $PVC_NAMESPACE

# Clean up
rm -rf /tmp/restore 