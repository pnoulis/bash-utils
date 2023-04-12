#!/usr/bin/env bash

SRCDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
EXECDIR=$(pwd)

# Positional parameters
WATCHFILE=
ONCHANGE=

main() {
    command -v inotifywait 2>&1>/dev/null
    (( $? > 0 )) && die "inotifywait not found"

    WATCHFILE="$(realpath -eq -- "$1")"
    if [[ -z "${WATCHFILE:-}" ]]; then
        die "Missing \$WATCHFILE"
    fi

    ONCHANGE="$2"

    local basename="${WATCHFILE##*/}"
    local -A exclude=()
    exclude["git"]="${basename}/\.git"
    exclude["build"]="${basename}/build"
    exclude["dist"]="${basename}/dist"
    exclude["node_modules"]="${basename}/node_modules"
    exclude["tests"]="${basename}/tests?"
    exclude["docs"]="${basename}/docs?"
    exclude["tmp"]="${basename}/tmp"
    local regexExclude=$(echo "${exclude[@]}" | tr [[:space:]] '\|' | sed 's/.$//')

    inotifywait --recursive \
                --monitor \
                --event modify,move,create,delete \
                --excludei "$regexExclude" \
                "${WATCHFILE}" \
                | while read change; do
        echo "$change"
        done
}

die() {
    exec 1>&2
    echo "$@"
    exit 1
}

main "$@"
