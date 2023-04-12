#!/usr/bin/env bash

SRCDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)

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

    inotifywait --recursive \
                --monitor \
                --event modify,move,create,delete \
                --excludei "\.git|build|dist|tmp" \
                -q \
                "${WATCHFILE}" \
                | while read change; do
        exec ${ONCHANGE}
        done
}

die() {
    exec 1>&2
    echo "$@"
    exit 1
}

main "$@"
