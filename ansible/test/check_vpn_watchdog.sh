#!/bin/sh
# Checks the VPN watchdog (playbooks/apps/vpn-watchdog/vpn-watchdog.sh): when the circuit breaker stops a
# gluetun container, and what it reports to Uptime Kuma. Runs on the controller only: docker, nc and wget
# are replaced by fakes, nothing connects to the hosts.
# POSIX sh, so that it also runs in the watchdog's image (busybox):
#   docker run --rm -v "$PWD:/repo:ro" --entrypoint sh docker:28-cli /repo/test/check_vpn_watchdog.sh

TEST_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHDOG="$TEST_DIR/../playbooks/apps/vpn-watchdog/vpn-watchdog.sh"
export TZ=UTC # expiry days counted without daylight saving shifts
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
NOW="$(date +%s)"
failures=0

mkdir -p "$WORK/bin"
# Fake docker. Log fixtures are lines "<epoch> <log line>", filtered on --since like docker does.
cat > "$WORK/bin/docker" <<'EOF'
#!/bin/sh
echo "$*" >> "$FAKE/docker.calls"
case "$1" in
  ps) [ -f "$FAKE/docker-down" ] && exit 1; cat "$FAKE/ps" ;;
  logs)
    [ -f "$FAKE/logs-fail-$4" ] && { echo "Error response from daemon" >&2; exit 1; }
    [ -f "$FAKE/logs-$4" ] && awk -v since="$3" '$1 >= since { $1 = ""; print substr($0, 2) }' "$FAKE/logs-$4"
    exit 0 ;;
  stop) echo "$2" >> "$FAKE/stopped"; echo "$2" ;;
esac
EOF
# Fake nc: internet reachable outside the VPN unless $FAKE/internet-down exists
cat > "$WORK/bin/nc" <<'EOF'
#!/bin/sh
[ ! -f "$FAKE/internet-down" ]
EOF
# Fake wget: records the pushed URLs
cat > "$WORK/bin/wget" <<'EOF'
#!/bin/sh
for arg; do url="$arg"; done
echo "$url" >> "$FAKE/pushes"
EOF
chmod +x "$WORK/bin/"*

new_case() {
  echo "== $1"
  FAKE="$WORK/case$((case_number = ${case_number:-0} + 1))"
  mkdir -p "$FAKE"
  : > "$FAKE/ps"
  echo "qbittorrent $(date -d "@$((NOW + 365 * 86400))" +%Y-%m-%d)" > "$FAKE/keys"
}

# Usage: container <name> <image> <state>
container() { echo "$1 $2 $3" >> "$FAKE/ps"; }

# Usage: connections <container> <count> <seconds ago of the first one> <seconds between two>
# Writes what gluetun v3.41.3 logs on each reconnection.
connections() {
  i=0
  while [ "$i" -lt "$2" ]; do
    t=$((NOW - $3 + i * $4))
    echo "$t 2026-11-16T10:00:00Z WARN [vpn] restarting VPN because it failed to pass the healthcheck: startup check: all check tries failed" >> "$FAKE/logs-$1"
    echo "$t 2026-11-16T10:00:00Z INFO [wireguard] Using available kernelspace implementation" >> "$FAKE/logs-$1"
    echo "$t 2026-11-16T10:00:00Z INFO [wireguard] Connecting to 185.159.157.1:51820" >> "$FAKE/logs-$1"
    i=$((i + 1))
  done
}

run_watchdog() {
  FAKE="$FAKE" PATH="$WORK/bin:$PATH" TMPDIR="$FAKE" \
    KUMA_BREAKER_URL=http://kuma/breaker KUMA_EXPIRY_URL=http://kuma/expiry \
    KEYS_FILE="$FAKE/keys" STATE_FILE="$FAKE/state" \
    sh "$WATCHDOG" once > "$FAKE/output" 2>&1
}

fail() { echo "FAIL: $1"; sed 's/^/    /' "$FAKE/output"; failures=$((failures + 1)); }

# Usage: expect_push <breaker|expiry> <up|down> [text in the message]
expect_push() {
  last="$(grep "^http://kuma/$1?" "$FAKE/pushes" 2>/dev/null | tail -n 1)"
  case "$last" in
    *"status=$2&"*) ;;
    *) fail "$1 monitor: expected $2, got '${last:-no push}'"; return ;;
  esac
  [ -z "${3:-}" ] || echo "$last" | sed 's/%20/ /g' | grep -qF "$3" || fail "$1 monitor: no '$3' in '$last'"
}

expect_stopped() { grep -qx "$1" "$FAKE/stopped" 2>/dev/null || fail "$1 should have been stopped"; }
expect_not_stopped() { [ ! -s "$FAKE/stopped" ] || fail "nothing should have been stopped, got: $(cat "$FAKE/stopped")"; }

new_case "a healthy tunnel is left alone"
container qbittorrent-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
container qbittorrent lscr.io/linuxserver/qbittorrent:5.1.2-libtorrentv1 running
connections qbittorrent-vpn-client-1 1 5000 0
run_watchdog
expect_not_stopped
expect_push breaker up
expect_push expiry up

new_case "19 connections in the last hour: under the threshold"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
connections slskd-vpn-client-1 19 3500 180
connections slskd-vpn-client-1 30 10000 200 # older than 1 hour: 49 in 3 hours, under the safety net
run_watchdog
expect_not_stopped
expect_push breaker up

new_case "20 connections in the last hour with internet up: stopped"
container qbittorrent-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
connections qbittorrent-vpn-client-1 2 3000 60
connections slskd-vpn-client-1 20 3500 170
run_watchdog
expect_stopped slskd-vpn-client-1
grep -q qbittorrent "$FAKE/stopped" && fail "the healthy tunnel should not have been stopped"
expect_push breaker down "slskd-vpn-client-1 stopped by the breaker: 20 connections in 1h"
grep -q "^slskd-vpn-client-1 [0-9]* tripped$" "$FAKE/state" || fail "the trip should be recorded"

new_case "a loop during an internet outage is left alone under the safety net"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
connections slskd-vpn-client-1 25 3500 130 # 25 in 1 hour, 25 in 3 hours
touch "$FAKE/internet-down"
run_watchdog
expect_not_stopped
expect_push breaker up

new_case "safety net: 60 connections in 3 hours, stopped even if internet looks down"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
connections slskd-vpn-client-1 60 10000 160
touch "$FAKE/internet-down"
run_watchdog
expect_stopped slskd-vpn-client-1
expect_push breaker down "internet down"

new_case "a container restarting in a loop is caught too (its logs survive the restarts)"
container tool-vpn-client-1 qmcgaw/gluetun:v3.41.3 restarting
run_watchdog
expect_not_stopped # not running right now: checked on the next run
container_line="tool-vpn-client-1 qmcgaw/gluetun:v3.41.3 running"
echo "$container_line" > "$FAKE/ps"
connections tool-vpn-client-1 25 3000 100
run_watchdog
expect_stopped tool-vpn-client-1

new_case "a tripped container stays reported while it is down"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 exited
echo "slskd-vpn-client-1 $((NOW - 600)) tripped" > "$FAKE/state"
run_watchdog
expect_push breaker down "slskd-vpn-client-1 stopped by the breaker, restart it by hand"

new_case "a container stopped on purpose is not a problem"
container tool-vpn-client-1 qmcgaw/gluetun:v3.41.3 exited
run_watchdog
expect_push breaker up

new_case "restarted by hand after a trip: the loop from before the trip does not count"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
connections slskd-vpn-client-1 50 3500 50 # the loop that tripped it
echo "slskd-vpn-client-1 $((NOW - 600)) tripped" > "$FAKE/state"
connections slskd-vpn-client-1 1 300 0 # restarted by hand 5 minutes ago
run_watchdog
expect_not_stopped
expect_push breaker up
grep -q "^slskd-vpn-client-1 $((NOW - 600)) cleared$" "$FAKE/state" || fail "the trip should be cleared"

new_case "unknown gluetun version: reported, its log format is not validated"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.42.0 running
run_watchdog
expect_push breaker down "runs gluetun 'v3.42.0', not validated"
new_case "gluetun without a tag: reported too"
container slskd-vpn-client-1 qmcgaw/gluetun running
run_watchdog
expect_push breaker down "runs gluetun '', not validated"

new_case "unreadable logs: reported"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
touch "$FAKE/logs-fail-slskd-vpn-client-1"
run_watchdog
expect_push breaker down "slskd-vpn-client-1: cannot read its logs"

new_case "docker unreachable: reported"
container slskd-vpn-client-1 qmcgaw/gluetun:v3.41.3 running
touch "$FAKE/docker-down"
run_watchdog
expect_push breaker down "cannot list the containers"

new_case "key expiring in 28 days: warned"
echo "qbittorrent $(date -d "@$((NOW + 29 * 86400))" +%Y-%m-%d)" > "$FAKE/keys" # midnight of that day: 28 days left
echo "slskd $(date -d "@$((NOW + 300 * 86400))" +%Y-%m-%d)" >> "$FAKE/keys"
run_watchdog
expect_push expiry down "qbittorrent: WireGuard key expires in 28 days"
grep "^http://kuma/expiry" "$FAKE/pushes" | grep -q slskd && fail "slskd's key is far from expiry"

new_case "key expiring in 29 days: not yet"
echo "# comment line" > "$FAKE/keys"
echo "qbittorrent $(date -d "@$((NOW + 30 * 86400))" +%Y-%m-%d)" >> "$FAKE/keys"
run_watchdog
expect_push expiry up

new_case "expired key, invalid date, missing keys file: reported"
echo "qbittorrent $(date -d "@$((NOW - 2 * 86400))" +%Y-%m-%d)" > "$FAKE/keys"
echo "slskd 16/11/2027" >> "$FAKE/keys"
run_watchdog
expect_push expiry down "qbittorrent: WireGuard key EXPIRED"
expect_push expiry down "slskd: invalid expiry date"
rm "$FAKE/keys"
run_watchdog
expect_push expiry down "cannot read"

if [ "$failures" -gt 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "OK: VPN watchdog"
