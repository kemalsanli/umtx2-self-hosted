#!/bin/sh
# Prepare the content under $REPO_DIR, start crond in the background, then
# hand off PID 1 to nginx.
#
# Content state machine:
#   .git present              -> try fetch+reset; fall back to existing on failure
#   no .git but doc root file -> serve pre-bundled content as-is (offline bundle)
#   empty                     -> must clone; fails fast if offline
set -eu

: "${REPO_URL:?REPO_URL is required}"
: "${REPO_REF:?REPO_REF is required}"
: "${REPO_DIR:?REPO_DIR is required}"
: "${DOC_ROOT_SUBPATH:?DOC_ROOT_SUBPATH is required}"

log() { printf '[entrypoint] %s\n' "$*"; }

DOC_ROOT="$REPO_DIR/$DOC_ROOT_SUBPATH"
LOCK_FILE=/var/lock/umtx2-update.lock

if [ -d "$REPO_DIR/.git" ]; then
    log "$REPO_DIR is a git checkout, attempting fetch from $REPO_REF"
    # Serialize fetch+reset under one lock so the cron-driven update.sh and
    # a manual exec can never race and tear up the shallow clone mid-flight.
    {
        if flock -n 9; then
            if git -C "$REPO_DIR" fetch --depth 1 origin "$REPO_REF" 2>&1; then
                git -C "$REPO_DIR" reset --hard "origin/$REPO_REF"
            else
                log "WARN: fetch failed (offline?), continuing with current content"
            fi
        else
            log "WARN: another update in progress, continuing with current content"
        fi
    } 9>"$LOCK_FILE"
elif [ -f "$DOC_ROOT/index.html" ]; then
    log "$REPO_DIR has bundled content without .git, serving as-is"
elif [ -n "$(ls -A "$REPO_DIR" 2>/dev/null)" ]; then
    log "ERROR: $REPO_DIR has files but neither .git nor $DOC_ROOT_SUBPATH/index.html"
    log "  -> looks like a half-populated volume. Remove its contents to force a fresh clone,"
    log "     or place a complete upstream checkout (with .git OR with $DOC_ROOT_SUBPATH/index.html)."
    exit 1
else
    log "$REPO_DIR is empty, cloning $REPO_URL ($REPO_REF)"
    if ! git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$REPO_DIR"; then
        log "ERROR: clone failed — check REPO_URL ($REPO_URL) and REPO_REF ($REPO_REF), and network"
        exit 1
    fi
fi

if [ ! -f "$DOC_ROOT/index.html" ]; then
    log "ERROR: $DOC_ROOT/index.html missing after setup — wrong REPO_REF or DOC_ROOT_SUBPATH?"
    exit 1
fi

log "doc root resolved: $DOC_ROOT"
log "starting crond (logs to /var/log/cron.log)"
crond -b -L /var/log/cron.log

log "handing off to nginx"
exec nginx -g 'daemon off;'
