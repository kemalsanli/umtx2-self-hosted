#!/bin/sh
# Initial clone (or skip if volume already has the repo), then start the cron
# daemon in the background and hand off PID 1 to nginx.
set -eu

: "${REPO_URL:?REPO_URL is required}"
: "${REPO_REF:?REPO_REF is required}"
: "${REPO_DIR:?REPO_DIR is required}"
: "${DOC_ROOT_SUBPATH:?DOC_ROOT_SUBPATH is required}"

log() { printf '[entrypoint] %s\n' "$*"; }

if [ ! -d "$REPO_DIR/.git" ]; then
    log "cloning $REPO_URL ($REPO_REF) into $REPO_DIR"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"
else
    log "$REPO_DIR already populated, pulling latest"
    git -C "$REPO_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$REPO_DIR" reset --hard "origin/$REPO_REF"
fi

DOC_ROOT="$REPO_DIR/$DOC_ROOT_SUBPATH"
if [ ! -f "$DOC_ROOT/index.html" ]; then
    log "ERROR: $DOC_ROOT/index.html missing after clone — wrong REPO_REF or DOC_ROOT_SUBPATH?"
    exit 1
fi

log "doc root resolved: $DOC_ROOT"
log "starting crond (logs to /var/log/cron.log)"
crond -b -L /var/log/cron.log

log "handing off to nginx"
exec nginx -g 'daemon off;'
