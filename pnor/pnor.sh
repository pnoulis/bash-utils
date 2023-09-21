#!/usr/bin/env bash

usage() {
    cat <<EOF
${0} Normalizes filenames according to unix syntax, community
     conventions and my own preferences.


Filename syntax

A filename does not impose any constraints as to its syntax. Meaning that
a filename may contain punctuation, numbers and letters. However, free as one
is, some conventions do exist.

Filename conventions

There is not a single universally accepted standard defining the syntax of
filenames. However the global community of programmers has created a set
guidelines. Most communities bend those guidelines a litte to adjust to their
needs, constraints or ease of use.

1. The syntax of filenames should be limited to these symbols:
   a-z A-Z 0-9 . - _

2. They should not be overly long

3. lowercase should be prefered over uppercase.
EOF
    exit 0
}

set -o pipefail -o errexit
trap 'exit 1' 10
PID=$$

tempf=$(mktemp)
tempd=$(mktemp --directory)

# Standard filename syntax convention
# Posix character classes
# [[:alnum:]] a-zA-Z0-9
# Filename regular expression
FRE=[^[:alnum:]._-]
# [[:space:]] spaces, tabs, newlines
# Spaces Regular Expression
FSPACE_RE=[[:space:]]+

declare -gA FILENAMES=()


main() {
    parse_args "$@"
    set -- "${POSARGS[@]}"
    if [[ -p /dev/stdin ]]; then
        # scripts is part of a pipeline
        while read -r -d $'\n' filename; do
            [[ -z "${filename:-}" ]] && continue
            FILENAMES["$filename"]=$(normalize "$filename")
        done < /dev/stdin
    else
        # script is not part of a pipeline
        while IFS= read -r -d $'\0' filename; do
            FILENAMES["$filename"]=$(normalize "$filename")
        done < <(find . -mindepth 1 -printf "%f\0")
    fi
    for key in "${!FILENAMES[@]}"; do
        echo "to move " "$key"
        [[ -n "${PREFIX:-}" ]] && mkdir -p $PREFIX 2>/dev/null
        local path=${PREFIX:+$PREFIX/}"${FILENAMES[$key]}"
        mv "$key" "$path"
    done
}

debug() {
    for key in "${!FILENAMES[@]}"; do
        printf "%s\n%s\n" "$key" "${FILENAMES[$key]}"
    done
}

# main-pipe() {
#     while read -r -d $'\n' filename; do
#         [[ -z "${filename:-}" ]] && continue
#         FILENAMES["$filename"]=$(normalize "$filename")
#     done < /dev/stdin
# }

# main-tty() {
#     cd $(dirname "${BASH_SOURCE[0]}")
#     parse_args "$@"
#     set -- "${POSARGS[@]}"
#     while IFS= read -r -d $'\0' filename; do
#         FILENAMES["$filename"]=$(normalize "$filename")
#     done < <(find . -mindepth 1 -printf "%f\0")
# }

normalize() {
    # First sed removes spaces and translates them to a single hyphen.
    # Second sed removes most punctuation considered special characters.
    # Third sed strips leading or tailing characters that are not a-zA-Z0-9
    echo "$1" \
        | sed -E "s/[[:space:]]+/-/g" \
        | sed -E "s/[^[:alnum:]._-]//g" \
        | sed -E "s/^[^[:alnum:]]|[^[:alnum:]]$//g"
}

parse_args() {
    declare -ga POSARGS=()
    while (($# > 0)); do
        case "${1:-}" in
            --prefix*)
                PREFIX="$(OPTIONAL=0 parse_param "$@")" || shift $?
                ;;
            --debug)
                DEBUG=0
                ;;
            -h | --help)
                usage
                ;;
            -[a-zA-Z][a-zA-Z]*)
                local i="${1:-}"
                shift
                for i in $(echo "$i" | grep -o '[a-zA-Z]'); do
                    set -- "-$i" "$@"
                done
                continue
                ;;
            --)
                shift
                POSARGS+=("$@")
                ;;
            -[a-zA-Z]* | --[a-zA-Z]*)
                fatal "Unrecognized argument ${1:-}"
                ;;
            *)
                POSARGS+=("${1:-}")
                ;;
        esac
        shift
    done
}

parse_param() {
    local param arg
    local -i toshift=0

    if (($# == 0)); then
        return $toshift
    elif [[ "$1" =~ .*=.* ]]; then
        param="${1%%=*}"
        arg="${1#*=}"
    elif [[ "${2-}" =~ ^[^-].+ ]]; then
        param="$1"
        arg="$2"
        ((toshift++))
    fi

    if [[ -z "${arg-}" && ! "${OPTIONAL-}" ]]; then
        fatal "${param:-$1} requires an argument"
    fi

    echo "${arg:-}"
    return $toshift
}

fatal() {
    echo "$@" >&2
    kill -10 $PROC
    exit 1
}

main "$@"
