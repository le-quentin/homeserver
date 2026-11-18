#!/bin/zsh
# The backups leave out the paths listed in `exclude` (homelab_app_backups, see roles/homelab-app) and
# nothing else. Runs the backup scripts rendered from the real playbooks, with the restic version of
# the role, on fake volumes and local repositories.
# Runs on the controller only (needs docker): nothing connects to the hosts nor to the real backups.

SCRIPT_DIR="${0:A:h}"
cd "$SCRIPT_DIR/.." # ansible.cfg is read from the current directory

set -e
export BACKUP_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$BACKUP_TEST_DIR"' EXIT
export BACKUP_TEST_APPS="lidarr jellyfin z2m navidrome"
export REAL_DOCKER="$(command -v docker)"
export RESTIC_IMAGE="$(sed -n 's/^homelab_restic_image: "\(.*\)"$/\1/p' roles/homelab-app/defaults/main.yml)"
failures=0
mkdir -p "$BACKUP_TEST_DIR/"{bin,repos,volumes,scripts}

ansible-playbook test/check_backup_excludes.yaml > "$BACKUP_TEST_DIR/render.log" 2>&1 \
  || { cat "$BACKUP_TEST_DIR/render.log"; echo "FAIL: rendering the backup scripts"; exit 1; }

# Fake docker: the containers of the apps do not exist, and restic runs from its upstream image on a
# directory of $BACKUP_TEST_DIR/volumes (instead of a docker volume) and a local repository (instead of R2).

cat > "$BACKUP_TEST_DIR/bin/docker" <<'FAKE'
#!/bin/sh
[ "$1" = run ] || exit 0 # ps, stop, start
shift
data_mount=""
while [ "$1" != "homelab-restic-rclone:latest" ]; do
  case "$2" in *:/data:ro) data_mount="-v $BACKUP_TEST_DIR/volumes/${2%%:*}:/data:ro" ;; esac
  shift
done
shift
repository="$BACKUP_TEST_DIR/repos/$(echo "$RESTIC_REPOSITORY" | tr -c 'a-z0-9\n-' '_')"
mkdir -p "$repository"
# shellcheck disable=SC2086 # data_mount is two arguments, or none
exec "$REAL_DOCKER" run --rm --user "$(id -u):$(id -g)" $data_mount -v "$repository:/repo" \
  -e RESTIC_REPOSITORY=/repo -e RESTIC_PASSWORD -e RESTIC_HOST -e RESTIC_CACHE_DIR=/tmp/cache \
  "$RESTIC_IMAGE" "$@"
FAKE
chmod +x "$BACKUP_TEST_DIR/bin/docker"
restic() { RESTIC_REPOSITORY="rclone:test:/backups/$1" RESTIC_PASSWORD=test "$BACKUP_TEST_DIR/bin/docker" run homelab-restic-rclone:latest "${@:2}"; }

# Usage: volume <app> <volume> <file>...
volume() {
  for file in "${@:3}"; do
    mkdir -p "$BACKUP_TEST_DIR/volumes/$1-$2/${file:h}"
    echo "content of $file" > "$BACKUP_TEST_DIR/volumes/$1-$2/$file"
  done
}

# Usage: check_backup <app> <volume> <"kept" files> -- <"left out" files>
check_backup() {
  local app="$1" volume="$2" expected=kept
  shift 2
  echo "== $app/$volume"
  restic "$app/$volume" init > /dev/null
  if ! PATH="$BACKUP_TEST_DIR/bin:$PATH" "$BACKUP_TEST_DIR/scripts/$app-$volume.sh" > "$BACKUP_TEST_DIR/backup.log" 2>&1; then
    cat "$BACKUP_TEST_DIR/backup.log"
    echo "FAIL: the backup script of $app/$volume failed"
    failures=$((failures + 1))
    return
  fi
  restic "$app/$volume" ls latest > "$BACKUP_TEST_DIR/snapshot"
  for file; do
    if [ "$file" = "--" ]; then expected="left out"; continue; fi
    if grep -qxF "/data/$file" "$BACKUP_TEST_DIR/snapshot"; then actual=kept; else actual="left out"; fi
    if [ "$actual" = "$expected" ]; then
      echo "OK: $file $actual"
    else
      echo "FAIL: $file is $actual, expected $expected"
      failures=$((failures + 1))
    fi
  done
  if [ ! -s "$BACKUP_TEST_DIR/stats/$app/$volume-stats.json" ]; then
    echo "FAIL: no repository statistics written for the backup summary"
    failures=$((failures + 1))
  fi
}

# A directory named like an excluded one is kept when it is not at the root of the volume
volume lidarr config lidarr.db config.xml plugins/TypNull/plugin.dll plugins/TypNull/logs/kept.txt \
  MediaCover/297/poster.jpg MediaCover/Albums/12/cover.jpg Backups/scheduled/lidarr_backup.zip logs/lidarr.txt
check_backup lidarr config lidarr.db config.xml plugins/TypNull/plugin.dll plugins/TypNull/logs/kept.txt \
  -- MediaCover/297/poster.jpg MediaCover/Albums/12/cover.jpg Backups/scheduled/lidarr_backup.zip logs/lidarr.txt

volume jellyfin config config/system.xml data/jellyfin.db data/subtitles/a.srt data/metadata/kept.txt \
  "plugins/Open Subtitles_23.0.0.0/meta.json" metadata/People/A/actor.jpg metadata/library/ab/poster.jpg log/log_20261117.log
check_backup jellyfin config config/system.xml data/jellyfin.db data/subtitles/a.srt data/metadata/kept.txt \
  "plugins/Open Subtitles_23.0.0.0/meta.json" -- metadata/People/A/actor.jpg metadata/library/ab/poster.jpg log/log_20261117.log

volume z2m data configuration.yaml devices.yaml database.db coordinator_backup.json state.json log/2026-01-15.05-45-11/log.log
check_backup z2m data configuration.yaml devices.yaml database.db coordinator_backup.json state.json \
  -- log/2026-01-15.05-45-11/log.log

# The other volume of an app with an exclusion, and an app without any: everything is kept
volume z2m mqtt-data mosquitto.db log/mosquitto.log
check_backup z2m mqtt-data mosquitto.db log/mosquitto.log
volume navidrome data navidrome.db cache/images/a.jpg logs/navidrome.log
check_backup navidrome data navidrome.db cache/images/a.jpg logs/navidrome.log

if [ "$failures" -gt 0 ]; then
  echo "FAIL: $failures backup exclusion check(s) failed"
  exit 1
fi
echo "OK: backups leave out the excluded paths only"
