# Local fix: normalize final LC_RPATH entries independently in every slice.
# Run after all path rewrites and before signing; keep the first occurrence.
RPATH_DEDUP="$(dirname "$(realpath "$0")")/rpath_dedup.awk"
if [ ! -r "$RPATH_DEDUP" ]; then
    $ECHO "*** Missing rpath_dedup helper: $RPATH_DEDUP"
    exit 1
fi

dedup_rpaths() {
    local temporary
    temporary=$(mktemp "$1.rpath.XXXXXX") || return 1
    if ! RH_RPATH_INPUT="$1" LC_ALL=C awk -f "$RPATH_DEDUP" > "$temporary"; then
        rm -f "$temporary"
        return 1
    fi
    if ! cat "$temporary" > "$1"; then
        rm -f "$temporary"
        return 1
    fi
    rm -f "$temporary"
}

