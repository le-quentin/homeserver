#!/bin/zsh
# Deploying AdGuard keeps the user rules set in its UI (see playbooks/tasks/adguard-user-rules.yaml).
# Runs on the controller only: nothing connects to the hosts.

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR/.." # ansible.cfg is read from the current directory

set -e
export ADGUARD_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$ADGUARD_TEST_DIR"' EXIT
ansible-playbook -i inventories/prod test/check_adguard_user_rules.yaml > "$ADGUARD_TEST_DIR/output" 2>&1 \
  || { cat "$ADGUARD_TEST_DIR/output"; echo "FAIL: AdGuard user rules"; exit 1; }
echo "OK: AdGuard user rules kept"
