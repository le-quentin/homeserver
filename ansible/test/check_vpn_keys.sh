#!/bin/zsh
# Every VPN tunnel must have its own WireGuard key (see roles/homelab-app/tasks/assert_vpn_keys.yml).
# Checks the real inventories pass, and that a key shared between two apps is caught.
# Runs on the controller only: nothing connects to the hosts.

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR/.." # ansible.cfg (roles path) is read from the current directory

set -e
# Only prod: staging is not used anymore, its VPN keys are left as "TODO" so that no VPN app can be
# deployed there by mistake (the check rejects them).
echo "== prod inventory: every tunnel has its own key"
ansible-playbook -i inventories/prod test/check_vpn_keys.yaml

echo "== a key shared by two apps is rejected"
shared_key="$(printf 'A%.0s' {1..43})="
if ansible-playbook -i inventories/prod test/check_vpn_keys.yaml \
    -e "qbittorrent_vpn_private_key=$shared_key" -e "slskd_vpn_private_key=$shared_key" > /dev/null; then
  echo "FAIL: a shared VPN key was not rejected"
  exit 1
fi
echo "OK: shared key rejected"

echo "== a key without a valid expiry date is rejected"
for bad_date in "" "16/11/2027" "TODO"; do
  if ansible-playbook -i inventories/prod test/check_vpn_keys.yaml \
      -e "{\"slskd_vpn_key_expires\": \"$bad_date\"}" > /dev/null; then
    echo "FAIL: expiry date '$bad_date' was not rejected"
    exit 1
  fi
done
echo "OK: invalid expiry dates rejected"
