#!/bin/sh
# VPN watchdog: circuit breaker for the gluetun tunnels, and WireGuard key expiry alerts.
#
# Why: gluetun reconnects forever. WireGuard is silent, so gluetun cannot tell a dead, expired or banned
# key from a network glitch, and Docker never stops an unhealthy container. Any cause (shared key,
# expired key, Proton outage...) becomes an endless reconnection loop, which got the Proton account
# restricted for abuse in 2026-11. Every 2 minutes, for each gluetun container (found by image):
# - count its WireGuard connection attempts ("[wireguard] Connecting to", logged on every tunnel setup,
#   whatever the cause: healthcheck restart, container crash and restart...);
# - stop it when it reconnects too often. It stays down (restart: unless-stopped), and its app shares
#   its network namespace, so the app cannot run or leak without it. Restart it by hand.
#   When a tunnel cannot come up, gluetun v3.41 retries every ~6s, forever, with no setting to space
#   the attempts out (v3.40 had one). During an ISP outage that is ~10 attempts a minute that reach
#   nothing: they must not stop the tunnel, which recovers on its own. Hence two caps:
#   * >= 50 in the last hour, counting only the attempts made while internet was reachable outside
#     the VPN. Each run counts the attempts since the previous run, and keeps them only if internet
#     was reachable at both runs: attempts during an outage never count, and outages do not reset
#     the count (a flapping line with a dead key still trips). An outage shorter than the interval
#     can go unseen and count ~20: two of them in an hour stay under the cap. A real loop is
#     stopped in ~6 minutes.
#   * >= 300 in the last 3 hours whatever the internet check says: safety net if that check is wrong.
#     It also means that after ~30 minutes of outage the tunnel has to be restarted by hand.
# Reports to two Uptime Kuma push monitors: the breaker (also the watchdog's heartbeat: no push means
# the watchdog is dead) and the key expiry (down from 28 days before a key expires).
#
# Usage: vpn-watchdog.sh [loop|once]. Config through the environment, see below.
set -u

KUMA_BREAKER_URL="${KUMA_BREAKER_URL:?push URL of the breaker monitor}"
KUMA_EXPIRY_URL="${KUMA_EXPIRY_URL:?push URL of the key expiry monitor}"
KEYS_FILE="${KEYS_FILE:-/config/vpn-keys.conf}" # lines "<app> <YYYY-MM-DD>": when each WireGuard key expires
STATE_FILE="${STATE_FILE:-/state/tripped}"      # lines "<container> <epoch> tripped|cleared"
# Lines "<epoch> <container> <count>": connection attempts made while internet was reachable, per run
LEDGER_FILE="${LEDGER_FILE:-/state/connections}"
LAST_RUN_FILE="${LAST_RUN_FILE:-/state/last-run}" # "<epoch> <up|down>": the previous run, and its internet check
INTERVAL="${INTERVAL:-120}" # gluetun retries every ~6s on a dead tunnel: at most ~20 attempts between two runs

GLUETUN_IMAGE="qmcgaw/gluetun"
# The connection log line was checked in the source of these versions only: a new version could log
# it differently and the count would silently drop to zero. Any other version is reported as a problem.
KNOWN_GLUETUN_TAGS="v3.41.3"
CONNECT_PATTERN="[wireguard] Connecting to"
MAX_CONNECTIONS_WITH_INTERNET_1H=50
MAX_CONNECTIONS_3H=300
EXPIRY_WARNING_DAYS=28
# Reached outside the VPN, on several providers: internet is up if any answers
INTERNET_TARGETS="1.1.1.1:443 8.8.8.8:443 9.9.9.9:443 208.67.222.222:443"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >&2; } # stderr: stdout carries the problems found

# Number of WireGuard connection attempts in the logs read on stdin
count_connections() { grep -cF "$CONNECT_PATTERN" || true; }

internet_is_up() {
  for target in $INTERNET_TARGETS; do
    nc -z -w 5 "${target%:*}" "${target#*:}" 2>/dev/null && return 0
  done
  return 1
}

# Usage: days_until <YYYY-MM-DD> <now epoch>. Fails on an invalid date.
days_until() {
  echo "$1" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || return 1
  expires="$(date -d "$1" +%s 2>/dev/null)" || return 1
  echo $(( (expires - $2) / 86400 ))
}

urlencode() { printf '%s' "$1" | sed 's/%/%25/g; s/ /%20/g; s/&/%26/g; s/+/%2B/g; s/#/%23/g; s/?/%3F/g; s/=/%3D/g'; }

# Usage: push <url> <up|down> <message>
push() {
  wget -q -O /dev/null -T 15 "$1?status=$2&msg=$(urlencode "$3")&ping=" || log "could not push to Uptime Kuma"
}

# Usage: state_get <container>: prints "<epoch> <tripped|cleared>", nothing if unknown
state_get() { [ -f "$STATE_FILE" ] && awk -v c="$1" '$1 == c { print $2, $3 }' "$STATE_FILE"; }

# Usage: state_set <container> <epoch> <tripped|cleared>
state_set() {
  touch "$STATE_FILE" \
    && awk -v c="$1" '$1 != c' "$STATE_FILE" > "$STATE_FILE.new" \
    && echo "$1 $2 $3" >> "$STATE_FILE.new" \
    && mv "$STATE_FILE.new" "$STATE_FILE"
}

# Usage: forget_missing <file> <field of the container name> <existing container names, one per line>
forget_missing() {
  [ -f "$1" ] || return 0
  echo "$3" | awk -v field="$2" 'NR == FNR { exists[$1]; next } $field in exists' - "$1" > "$1.new" \
    && mv "$1.new" "$1"
}

# Usage: count_since <container> <epoch>: connection attempts logged since then
count_since() {
  docker logs --since "$2" "$1" > "${TMPDIR:-/tmp}/vpn-watchdog-logs" 2>&1 || return 1
  count_connections < "${TMPDIR:-/tmp}/vpn-watchdog-logs"
}

# Usage: latest <epoch> <epoch>
latest() { if [ "$1" -gt "$2" ]; then echo "$1"; else echo "$2"; fi; }

# Checks every gluetun container, stops the looping ones. Prints the problems found, one per line.
check_tunnels() {
  now="$1"
  if ! containers="$(docker ps -a --format '{{.Names}} {{.Image}} {{.State}}')"; then
    echo "cannot list the containers"
    return
  fi
  if internet_is_up; then internet=up; else internet=down; fi
  previous_run=""; previous_internet=""
  [ -f "$LAST_RUN_FILE" ] && read -r previous_run previous_internet < "$LAST_RUN_FILE"
  echo "$now $internet" > "$LAST_RUN_FILE"
  # Containers that are gone are forgotten, and so are the attempts older than the 1 hour window
  forget_missing "$STATE_FILE" 1 "$containers"
  forget_missing "$LEDGER_FILE" 2 "$containers"
  touch "$LEDGER_FILE" && awk -v from="$(( now - 3600 ))" '$1 > from' "$LEDGER_FILE" > "$LEDGER_FILE.new" \
    && mv "$LEDGER_FILE.new" "$LEDGER_FILE"

  echo "$containers" | while read -r name image state; do
    case "$image" in
      "$GLUETUN_IMAGE"|"$GLUETUN_IMAGE":*) ;;
      *) continue ;;
    esac
    tag="${image#"$GLUETUN_IMAGE"}"; tag="${tag#:}"
    case " $KNOWN_GLUETUN_TAGS " in
      *" $tag "*) ;;
      *) echo "$name runs gluetun '$tag', not validated for the watchdog (log format)" ;;
    esac
    previous="$(state_get "$name")"
    trip_time="${previous%% *}"; trip_time="${trip_time:-0}"
    if [ "$state" != "running" ]; then
      # A stopped tunnel is not a problem (it may be stopped on purpose) unless the breaker did it
      [ "${previous##* }" = "tripped" ] && echo "$name stopped by the breaker, restart it by hand once fixed"
      continue
    fi
    [ "${previous##* }" = "tripped" ] && state_set "$name" "$trip_time" cleared

    # What was logged before the breaker last stopped the container never counts (else restarting it
    # by hand would trip it again at once)
    if ! last_3_hours="$(count_since "$name" "$(latest "$(( now - 10800 ))" "$trip_time")")"; then
      echo "$name: cannot read its logs"
      continue
    fi
    if [ "$internet" = "up" ] && [ "$previous_internet" = "up" ]; then
      if ! since_previous_run="$(count_since "$name" "$(latest "$(latest "$(( now - 3600 ))" "$previous_run")" "$trip_time")")"; then
        echo "$name: cannot read its logs"
        continue
      fi
      [ "$since_previous_run" -gt 0 ] && echo "$now $name $since_previous_run" >> "$LEDGER_FILE"
    fi
    with_internet="$(awk -v c="$name" -v from="$trip_time" '$2 == c && $1 > from { n += $3 } END { print n + 0 }' "$LEDGER_FILE")"

    counts="$with_internet connections with internet in 1h, $last_3_hours in 3h, internet $internet"
    log "$name: $counts"
    if [ "$with_internet" -ge "$MAX_CONNECTIONS_WITH_INTERNET_1H" ] || [ "$last_3_hours" -ge "$MAX_CONNECTIONS_3H" ]; then
      if docker stop "$name" > /dev/null; then
        state_set "$name" "$now" tripped || echo "$name: cannot record its trip in $STATE_FILE"
        echo "$name stopped by the breaker: $counts"
      else
        echo "$name FAILED to stop: $counts"
      fi
    fi
  done
}

# Prints the keys that expire soon or have an invalid date, one per line
check_keys() {
  now="$1"
  if [ ! -r "$KEYS_FILE" ]; then
    echo "cannot read $KEYS_FILE"
    return
  fi
  grep -vE '^[[:space:]]*(#|$)' "$KEYS_FILE" | while read -r app expires; do
    if ! days="$(days_until "$expires" "$now")"; then
      echo "$app: invalid expiry date '$expires'"
    elif [ "$days" -lt 0 ]; then
      echo "$app: WireGuard key EXPIRED on $expires"
    elif [ "$days" -le "$EXPIRY_WARNING_DAYS" ]; then
      echo "$app: WireGuard key expires in $days days ($expires), extend it in the Proton dashboard"
    fi
  done
}

# Usage: report <url> <problems> <message when none>
report() {
  if [ -n "$2" ]; then
    problems="$(echo "$2" | tr '\n' ';' | sed 's/;$//; s/;/; /g')" # on one line, for the log too
    log "DOWN: $problems"
    push "$1" down "$problems"
  else
    log "UP: $3"
    push "$1" up "$3"
  fi
}

run_once() {
  now="${FAKE_NOW:-$(date +%s)}" # FAKE_NOW: the clock of test/check_vpn_watchdog.sh
  report "$KUMA_BREAKER_URL" "$(check_tunnels "$now")" "no VPN reconnection loop"
  report "$KUMA_EXPIRY_URL" "$(check_keys "$now")" "no WireGuard key expires within $EXPIRY_WARNING_DAYS days"
}

case "${1:-loop}" in
  once) run_once ;;
  loop)
    while true; do
      run_once
      sleep "$INTERVAL"
    done
    ;;
  *) echo "Usage: $0 [loop|once]" >&2; exit 2 ;;
esac
