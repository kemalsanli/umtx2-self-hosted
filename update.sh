#!/bin/sh
# Pull the latest commits from upstream. Run by crond; safe to invoke manually.
# Best-effort: if there's nothing to update (no .git, no network), exits 0
# rather than killing the container.
set -eu

: "${REPO_DIR:=/srv/umtx2}"
: "${REPO_REF:=main}"

LOG_PREFIX="[update $(date '+%Y-%m-%dT%H:%M:%S%z')]"
log() { printf '%s %s\n' "$LOG_PREFIX" "$*"; }

if [ ! -d "$REPO_DIR/.git" ]; then
    log "$REPO_DIR is not a git checkout (offline bundle?), skipping"
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
