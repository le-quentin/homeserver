#!/bin/bash
set -euo pipefail

# Define apps
# apps=(radarr sonarr lidarr prowlarr qbittorrent)
apps=(radarr sonarr lidarr prowlarr qbittorrent slskd picard navidrome wiki uptime-kuma paperless jellyfin)

# Start SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/homeserver-prod

# Store PIDs and statuses
declare -A pids
declare -A statuses

# Create logs dir
restore_logs_dir="./out/restore-logs"
mkdir -p $restore_logs_dir

# Start all restores in parallel
for app in "${apps[@]}"; do
  log_file="$restore_logs_dir/$app.log"
  echo "[+] Starting restore for $app (logging to $log_file)"
  (
    ansible-playbook -i ansible/inventories/prod ansible/playbooks/restore-app.yaml \
      -v --extra-vars app="$app" >"$log_file" 2>&1
  ) &
  pids["$app"]=$!
done

# Live tail output with app prefix
for app in "${apps[@]}"; do
  log_file="$restore_logs_dir/$app.log"
  tail -f "$log_file" | sed -u "s/^/[$app] /" &
done

# Wait and collect status
for app in "${apps[@]}"; do
  pid="${pids[$app]}"
  if wait "$pid"; then
    statuses["$app"]="✅ SUCCESS"
  else
    statuses["$app"]="❌ FAILED"
  fi
done

# Print summary
echo ""
echo "========== RESTORE SUMMARY =========="
for app in "${apps[@]}"; do
  echo "$app: ${statuses[$app]}"
done
echo "====================================="
