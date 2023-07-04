#!/usr/bin/env bash

# Options
# parameter
# -m --mode=
MODE=production
# parameter
# -e --environment=
CLIENV=
# parameter
# --switch-prefixes=
declare -gA SWITCH_PREFIXES=()
# flag
# -p --inherit-process
declare -gA PROCENV=()
# positional arguments
# $@ file1 dir1 dir2 file2...

# ------------------------------ PROGRAM START ------------------------------ #
trap 'exit 1' 10
declare -g PROC=$$
# Exit script on error
set -o errexit
EXECDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
declare -gA ENV=()

main() {
    parse_args "$@"
    set -- "${POSARGS[@]}"

    load_process_env
    load_cli_env

    # load POSARGS environment
    for f in "$@"; do
        # expand path
        f=$(realpath $f 2>/dev/null)
        if ! [[ -r $f ]]; then
            # if path does not exist or is not readable
            fatal $f does not exist or not readable!
        elif [[ -d $f ]]; then
            # if directory
            load_preset_env $f
        elif [[ -f $f ]]; then
            # if file
            load_file_env $f
        fi
    done
    env_to_stdout
}

# write env to stdout
env_to_stdout() {
    for i in ${!ENV[@]}; do
        echo $i=${ENV[$i]}
    done
}

# load preset environment
load_preset_env() {
   local envdir=$1

   # env presets should not be hidden but
   # if they are they take precedence over
   # in plain sight presets

   # read default preset
   load_file_env $envdir/env
   load_file_env $envdir/.env

   # read $MODE preset
   load_file_env $envdir/env.$MODE
   load_file_env $envdir/.env.$MODE
}

# load file environment
load_file_env() {
    local envfile=$1
    if [[ -s $envfile ]]; then
        while IFS='=' read -r key value; do
            # In case the key is of the form: '$KEY'
            # That is interpreted to mean that the user
            # wants to clone some environemnt variable
            # that is found either in ENV or PROCENV
            if [[ $key =~ ^\$ ]]; then
                value=$key
                key=${key#?}
            fi
            ENV[$(switch_prefix $key)]=$(expand_envar $value)
        done < $envfile
    fi
}

# parent process environment
load_process_env() {
    while IFS='=' read -r key value; do
        PROCENV[$key]=$value
    done < <(cat "/proc/$$/environ" | tr '\0' '\n')
}

# command line parameter --environment
load_cli_env() {
    if [[ -n "${CLIENV:-}" ]]; then
        while IFS='=' read -r key value; do
            # In case the key is of the form: $KEY
            # That is interpreted to mean that the user
            # wants to clone some environemnt variable
            # that is found either in ENV or PROCENV
            if [[ $key =~ ^\$ ]]; then
                value=$key
                key=${key#?}
            fi
            ENV[$(switch_prefix $key)]=$(expand_envar $value)
        done < <(echo "$CLIENV" | tr ';' '\n')
    fi
}

# expand environment variable
expand_envar() {
    local enval=$1
    local -a vars=($(parse_envar $enval))
    
    let i=0
    local key=""
    local value=""
    local expanded=""
    while (( i < ${#vars[@]} )); do
        key=${vars[$i]}
        if [[ $key =~ \{.*\}$ ]]; then
            # index $i references an expandable envar of the form ${envar}
            key=${key#??} # remove ${
            key=${key%?} # remove }
        elif [[ $key =~ ^\$ ]]; then
            # index $i references an expandable envar of the form $envar
            key=${key#?} # remove $
        else
            # index $i does not reference an expandable envar
            expanded+=${key}
            ((i++))
            continue
        fi
        # Fist try and expand the variable from ENV
        value=${ENV[$key]}
        # If value was not expanded try PROCENV
        if [[ -z "${value:-}" ]]; then
            value=${PROCENV[$key]}
        fi
        # If the value remains unexpanded throw an error
        if [[ -z "${value:-}" ]]; then
            fatal "Failed expansion" ${vars[$i]}
        fi
        expanded+=$value
        ((i++))
    done

    echo $expanded
}

# Break down environment variable value into constituent parts
parse_envar() {
    envar=$1
    let i=0
    let y=0
    vars=()
    char=
    let varstart=0

    while (( i < ${#envar} )); do
        char=${envar:$i:1}
        case $char in
            \$ | \})
                if (( varstart )); then
                    vars[$y]+=$char
                    varstart=0
                else
                    vars+=($char)
                    varstart=1
                fi
                if (( i > 0 )); then
                    ((y++))
                fi
                ;;
            *)
                vars[$y]+=$char
                ;;
        esac
        ((i++))
    done
    echo "${vars[*]}"
}

# prefix switch
switch_prefix() {
    local envkey=$1
    while IFS='=' read -r key value; do
        if [[ -z "${key:-}" ]]; then
            envkey=$value$envkey
        elif [[ $envkey =~ $key ]]; then
            envkey=${envkey/$key/$value}
            echo $envkey
            return
        fi
    done < <(echo "$SWITCH_PREFIXES" | tr ';' '\n')
    echo $envkey
}

parse_args() {
    declare -ga POSARGS=()
    while (($# > 0)); do
        case "${1:-}" in
            -p | --inherit-process)
                unset -v PROCENV
                declare -gn PROCENV=ENV
                ;;
            -m | --mode*)
                MODE=$(OPTIONAL=0 parse_param "$@") || shift $?
                ;;
            -e | --environment*)
                CLIENV=$(parse_param "$@") || shift $?
                # remove last semicolon if any
                if [[ "$CLIENV" =~ .*\;$ ]]; then
                    CLIENV="${CLIENV%?}"
                fi
                ;;
            -s | --switch-prefixes*)
                SWITCH_PREFIXES=$(parse_param "$@") || shift $?
                # remove last semicolon if any
                if [[ "$SWITCH_PREFIXES" =~ .*\;$ ]]; then
                    SWITCH_PREFIXES="${SWITCH_PREFIXES%?}"
                fi
                ;;
            --debug)
                DEBUG=0
                ;;
            -h | --help)
                usage
                exit 0
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
