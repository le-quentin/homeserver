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
#   Rules: >= 20 connections in the last hour while internet is reachable outside the VPN (a short ISP
#   outage loops too, but reaches nothing), or >= 60 in the last 3 hours whatever the internet check
#   says (safety net if that check is wrong; after a long outage the tunnel has to be restarted by hand).
# Reports to two Uptime Kuma push monitors: the breaker (also the watchdog's heartbeat: no push means
# the watchdog is dead) and the key expiry (down from 28 days before a key expires).
#
# Usage: vpn-watchdog.sh [loop|once]. Config through the environment, see below.
set -u

KUMA_BREAKER_URL="${KUMA_BREAKER_URL:?push URL of the breaker monitor}"
KUMA_EXPIRY_URL="${KUMA_EXPIRY_URL:?push URL of the key expiry monitor}"
KEYS_FILE="${KEYS_FILE:-/config/vpn-keys.conf}" # lines "<app> <YYYY-MM-DD>": when each WireGuard key expires
STATE_FILE="${STATE_FILE:-/state/tripped}"      # lines "<container> <epoch> tripped|cleared"
INTERVAL="${INTERVAL:-120}" # gluetun retries every ~6s on a dead tunnel: at most ~20 attempts between two runs

GLUETUN_IMAGE="qmcgaw/gluetun"
# The connection log line was checked in the source of these versions only: a new version could log
# it differently and the count would silently drop to zero. Any other version is reported as a problem.
KNOWN_GLUETUN_TAGS="v3.41.3"
CONNECT_PATTERN="[wireguard] Connecting to"
MAX_CONNECTIONS_1H=20
MAX_CONNECTIONS_3H=60
EXPIRY_WARNING_DAYS=28
# Reached outside the VPN, on several providers: internet is up if any answers
INTERNET_TARGETS="1.1.1.1:443 8.8.8.8:443 9.9.9.9:443 208.67.222.222:443"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >&2; } # stderr: stdout carries the problems found

# Number of WireGuard connection attempts in the logs read on stdin
count_connections() { grep -cF "$CONNECT_PATTERN" || true; }

# Usage: should_trip <connections last hour> <connections last 3 hours> <internet up: 0|1>
should_trip() {
  [ "$2" -ge "$MAX_CONNECTIONS_3H" ] && return 0
  [ "$3" -eq 1 ] && [ "$1" -ge "$MAX_CONNECTIONS_1H" ]
}

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

# Usage: count_since <container> <window seconds> <now> <trip epoch or 0>: connection attempts in the window,
# not counting what was logged before the breaker last stopped the container (else restarting it by
# hand would trip it again at once).
count_since() {
  since=$(( $3 - $2 ))
  [ "$4" -gt "$since" ] && since="$4"
  docker logs --since "$since" "$1" > "${TMPDIR:-/tmp}/vpn-watchdog-logs" 2>&1 || return 1
  count_connections < "${TMPDIR:-/tmp}/vpn-watchdog-logs"
}

# Checks every gluetun container, stops the looping ones. Prints the problems found, one per line.
check_tunnels() {
  now="$1"
  if ! containers="$(docker ps -a --format '{{.Names}} {{.Image}} {{.State}}')"; then
    echo "cannot list the containers"
    return
  fi
  internet="" # checked once, only if needed
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
    if ! last_hour="$(count_since "$name" 3600 "$now" "$trip_time")" \
      || ! last_3_hours="$(count_since "$name" 10800 "$now" "$trip_time")"; then
      echo "$name: cannot read its logs"
      continue
    fi
    if [ "$last_hour" -ge "$MAX_CONNECTIONS_1H" ] && [ -z "$internet" ]; then
      if internet_is_up; then internet=1; else internet=0; fi
    fi
    log "$name: $last_hour connections in 1h, $last_3_hours in 3h, internet ${internet:-not checked}"
    if should_trip "$last_hour" "$last_3_hours" "${internet:-0}"; then
      reason="$last_hour connections in 1h, $last_3_hours in 3h, internet $([ "${internet:-0}" -eq 1 ] && echo up || echo down)"
      if docker stop "$name" > /dev/null; then
        state_set "$name" "$now" tripped || echo "$name: cannot record its trip in $STATE_FILE"
        echo "$name stopped by the breaker: $reason"
      else
        echo "$name FAILED to stop: $reason"
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
    log "DOWN: $2"
    push "$1" down "$(echo "$2" | tr '\n' ';' | sed 's/;$//; s/;/; /g')"
  else
    log "UP: $3"
    push "$1" up "$3"
  fi
}

run_once() {
  now="$(date +%s)"
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
