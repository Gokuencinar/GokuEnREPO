#!/bin/bash
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
DATA=/usr/libexec/roothidepatcherfix
STATE=/var/lib/roothidepatcherfix
APP=/Applications/Patcher.app
HELPER_LINK=../../usr/libexec/roothidepatcherfix/rpath_dedup.awk
. "$DATA/manifest"
hash() { sha256sum "$1" | cut -d ' ' -f1; }
message() { printf 'RootHidePatcher FIX: %s\n' "$*"; }
case "${1:-}" in
apply)
    if [ ! -f "$APP/patch.sh" ]; then
        message 'Patcher is not installed; no files changed.'
        exit 0
    fi
    current=$(hash "$APP/patch.sh")
    if [ "$current" != "$BASE_SHA256" ] && [ "$current" != "$FIXED_SHA256" ]; then
        previous=$(cat "$STATE/installed.sha256" 2>/dev/null || true)
        if [ -z "$previous" ] || [ "$current" != "$previous" ] || [ ! -f "$STATE/patch.sh.original" ] || [ "$(hash "$STATE/patch.sh.original")" != "$BASE_SHA256" ]; then
            message 'Unrecognized patch.sh; preserved without changes.'
            if [ "${2:-}" = triggered ]; then
                mkdir -p "$STATE"
                printf 'unsupported\n' > "$STATE/status"
                exit 0
            fi
            exit 1
        fi
    fi
    if [ -e "$APP/rpath_dedup.awk" ] || [ -L "$APP/rpath_dedup.awk" ]; then
        if [ ! -L "$APP/rpath_dedup.awk" ] || [ "$(readlink "$APP/rpath_dedup.awk")" != "$HELPER_LINK" ]; then
            message 'An existing helper belongs to another installation; preserved.'
            exit 1
        fi
    fi
    mkdir -p "$STATE"
    chmod 755 "$STATE"
    if [ ! -f "$STATE/patch.sh.original" ]; then
        if [ "$current" != "$BASE_SHA256" ]; then
            message 'Original backup is missing; refusing to replace the script.'
            exit 1
        fi
        cp -p "$APP/patch.sh" "$STATE/patch.sh.original"
    fi
    if [ "$(hash "$STATE/patch.sh.original")" != "$BASE_SHA256" ]; then
        message 'Original backup checksum differs; no files changed.'
        exit 1
    fi
    temporary=$(mktemp "$APP/.patch.sh.fix.XXXXXX")
    trap 'rm -f "$temporary"' EXIT
    RH_FIX_FUNCTIONS="$DATA/functions.sh" LC_ALL=C awk -f "$DATA/insert.awk" "$STATE/patch.sh.original" > "$temporary"
    /bin/bash -n "$temporary"
    if [ "$(hash "$temporary")" != "$FIXED_SHA256" ]; then
        message 'Generated script checksum differs; no files changed.'
        exit 1
    fi
    if [ "$(hash "$DATA/rpath_dedup.awk")" != "$HELPER_SHA256" ]; then
        message 'Helper checksum differs; no files changed.'
        exit 1
    fi
    chmod 755 "$temporary"
    chown root:wheel "$temporary"
    if [ ! -L "$APP/rpath_dedup.awk" ]; then
        ln -s "$HELPER_LINK" "$APP/rpath_dedup.awk"
    fi
    mv -f "$temporary" "$APP/patch.sh"
    trap - EXIT
    printf '%s\n' "$FIXED_SHA256" > "$STATE/installed.sha256"
    printf 'active\n' > "$STATE/status"
    message 'Active. Final LC_RPATH entries are deduplicated before signing.'
    ;;
restore)
    current=$(hash "$APP/patch.sh" 2>/dev/null || true)
    previous=$(cat "$STATE/installed.sha256" 2>/dev/null || true)
    if [ -n "$current" ] && { [ "$current" = "$FIXED_SHA256" ] || { [ -n "$previous" ] && [ "$current" = "$previous" ]; }; }; then
        if [ ! -f "$STATE/patch.sh.original" ] || [ "$(hash "$STATE/patch.sh.original")" != "$BASE_SHA256" ]; then
            message 'Original backup unavailable; removal stopped to preserve the working script.'
            exit 1
        fi
        temporary=$(mktemp "$APP/.patch.sh.restore.XXXXXX")
        trap 'rm -f "$temporary"' EXIT
        cp -p "$STATE/patch.sh.original" "$temporary"
        mv -f "$temporary" "$APP/patch.sh"
        trap - EXIT
        message 'Original patch.sh restored.'
    elif [ -n "$current" ] && [ "$current" != "$BASE_SHA256" ]; then
        message 'Patcher changed since installation; its script was preserved.'
        # Preserve a standalone helper when a custom script still uses ours.
        if grep -q 'dedup_rpaths' "$APP/patch.sh" && [ -L "$APP/rpath_dedup.awk" ] && [ "$(readlink "$APP/rpath_dedup.awk")" = "$HELPER_LINK" ]; then
            temporary=$(mktemp "$APP/.rpath_dedup.saved.XXXXXX")
            cp "$DATA/rpath_dedup.awk" "$temporary"
            chmod 644 "$temporary"
            mv -f "$temporary" "$APP/rpath_dedup.awk"
        fi
    fi
    if [ -L "$APP/rpath_dedup.awk" ] && [ "$(readlink "$APP/rpath_dedup.awk")" = "$HELPER_LINK" ]; then
        rm -f "$APP/rpath_dedup.awk"
    fi
    mkdir -p "$STATE"
    printf 'inactive\n' > "$STATE/status"
    ;;
status)
    if [ -f "$APP/patch.sh" ] && [ "$(hash "$APP/patch.sh")" = "$FIXED_SHA256" ] && [ -f "$APP/rpath_dedup.awk" ] && [ "$(hash "$APP/rpath_dedup.awk")" = "$HELPER_SHA256" ]; then
        message active
    else
        message inactive
        exit 1
    fi
    ;;
*) message 'Usage: manage.sh apply [triggered] | restore | status'; exit 1 ;;
esac
