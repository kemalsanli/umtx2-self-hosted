#!/bin/sh
# Pull the latest commits from upstream. Run by crond; safe to invoke manually.
# Best-effort: if there's nothing to update (no .git, no network), exits 0
# rather than killing the container. Serialized via flock so a manual exec
# can't race with a scheduled run and corrupt the shallow clone.
set -eu

: "${REPO_DIR:=/srv/umtx2}"
: "${REPO_REF:=main}"
LOCK_FILE=/var/lock/umtx2-update.lock

LOG_PREFIX="[update $(date '+%Y-%m-%dT%H:%M:%S%z')]"
log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }

if [ ! -d "$REPO_DIR/.git" ]; then
    log "$REPO_DIR is not a git checkout (offline bundle?), skipping"
    exit 0
fi

# Serialize fetch+reset via a non-blocking flock. If another update is
# already running, log and exit 0 — don't surface a spurious cron error.
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    log "another update is in progress, skipping"
    exit 0
fi

BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD)
if ! git -C "$REPO_DIR" fetch --depth 1 origin "$REPO_REF" 2>&1; then
    log "WARN: fetch failed (offline?), skipping update"
    exit 0
fi
git -C "$REPO_DIR" reset --hard "origin/$REPO_REF" 2>&1
AFTER=$(git -C "$REPO_DIR" rev-parse HEAD)

if [ "$BEFORE" = "$AFTER" ]; then
    log "no change ($BEFORE)"
else
    log "$BEFORE -> $AFTER"
fi
