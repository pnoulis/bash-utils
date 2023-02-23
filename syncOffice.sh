#!/bin/bash
# Author: Pavlos Noulis
# Start Date: <2023-02-23 Wed>

readonly program="$(basename $0)"
usage() {
    cat <<EOF
    ${program}

    Script to make sure I keep my office git repository synchronized accross
    workstations.

    The script should be automated using crontab.

    It should run shortly after:
       1. I depart for WORK from HOME
       2. I depart for HOME from WORK

    Example crontab rule:
    check man crontab.5

    run crontab -e
    m h dom mon dow (minute hour day-of-month month day-of-week)

    // run syncOffice at 17:30 each day
    30 17 * * * /home/pnoul/bin/syncOffice.sh >> /tmp/cron.log 2>&1
    
EOF
}

readonly SRCDIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

main() {
    if [ -n "${SRCDIR-}" ]; then
        cd "${SRCDIR}"
    else
        fatal "Could not cd into '${SRCDIR}'"
    fi
    parse_args "$@"
    office=$(find "${HOME}" -name office -type d)

    if [[ -z "${office}" ]]; then
        fatal 'Could not locate office'
    elif  ! ( isGitDir "${office}" ); then
        fatal "${office} is not a git repository"
    elif ( isGitClean "${office}" ) && ( gitNoUnpushedCommits "${office}"); then
        log "${office} already clean and synced!"
        exit 0
    fi

    log "${office} is dirty"
    cd "${office}"
    git add . || fatal "Automated commit failed at -> git add ."
    automated_commit_message="${program}: [AUTOMATED_COMMIT] $(date "+%A_%d_%B_%Y_%k:%M")"
    git commit -m "${automated_commit_message}" || fatal "Automated commit failed at -> git commit -m"
    git push 2>/dev/null || fatal "Failed to push to origin; not tracking"
    log "${office} synced"
}

isGitDir() {
    # input validation
    ## 1. one parameter has been provided
    [[ $# -eq 0 ]] && {
        echo isGitDir: Wrong number of arguments
        exit 1
    }

    ## 2. that paremeter is not an empty string
    [ -z "$1" ] && {
        echo isGitDir: Null string
        exit 1
    }

    # make sure:
    ## 1. is a path
    ## 2. all nodes exist
    ## 3. expand path
    {
        local tpath=$(realpath -qe "$1")
    } || {
        echo isGitDir: "$1": No such file or directory
        exit 1
    }

    # check cwd is a git repo
    pushd "$tpath" > /dev/null
    {
        git status >& /dev/null
    } || {
        echo isGitDir: "$tpath": Not a git repository
        exit 1
    }
    popd > /dev/null
    return 0
}

function isGitClean() {
    # input validation
    ## 1. one parameter has been provided
    [[ $# -eq 0 ]] && {
        echo isGitClean: Wrong number of arguments
        exit 1
    }

    ## 2. that paremeter is not an empty string
    [ -z "$1" ] && {
        echo isGitClean: Null string
        exit 1
    }

    # make sure:
    ## 1. is a path
    ## 2. all nodes exist
    ## 3. expand path
    {
        local tpath=$(realpath -qe "$1")
    } || {
        echo isGitClean: "$1": No such file or directory
        exit 1
    }


    # check
    pushd "$tpath" > /dev/null
    ## 1. provided argument is a path repository
    {
        git status >& /dev/null
    } || {
        echo isGitClean: "$tpath": Not a git repository
        exit 1
    }
    ## 2. working directory is clean
    [ -n "$(git status --porcelain)" ] && {
        exit 1
    }
    popd > /dev/null

    return 0
}

# 
#  @return {integer} 0 or 1
#   0 - no unpushed commits
#   1 - error or pushed commits
# 
gitNoUnpushedCommits() {
    # input validation
    ## 1. one parameter has been provided
    [[ $# -eq 0 ]] && {
        echo gitNoUnpushedCommits: Wrong number of arguments
        exit 1
    }

    ## 2. that paremeter is not an empty string
    [ -z "$1" ] && {
        echo gitNoUnpushedCommits: Null string
        exit 1
    }

    # make sure:
    ## 1. is a path
    ## 2. all nodes exist
    ## 3. expand path
    {
        local tpath=$(realpath -qe "$1")
    } || {
        echo gitNoUnpushedCommits: "$1": No such file or directory
        exit 1
    }


    # check
    pushd "$tpath" > /dev/null
    ## 1. provided argument is a git repository
    {
        git status >& /dev/null
    } || {
        echo gitNoUnpushedCommits: "$tpath": Not a git repository
        exit 1
    }

    [[ "$(git status --short --branch --porcelain)" =~ ahead[[:space:]][0-9]+ ]] && {
        echo gitNoUnpushedCommits: "$tpath": Unpushed commits
        exit 1
    }
    popd >/dev/null

    return 0
}

parse_args() {
    declare -g SHIFTER
    SHIFTER=$(mktemp)

    while (($# > 0)); do
        case "$1" in
        --dev | -d)
            DEV=0
            ;;
        --help | -help | --h | -h)
            usage
            exit 1
            ;;
        -[a-zA-Z][a-zA-Z]*)
            local i="$1"
            shift
            for i in $(echo "$i" | grep -o '[a-zA-Z]'); do
                set -- "-$i" "$@"
            done
            continue
            ;;
        --)
            shift
            args+=("$@")
            break
            ;;
        -[a-zA-Z]* | --[a-zA-Z]*)
            error "Unrecognized argument $1"
            exit 1
            ;;
        *)
            args+=("$1")
            ;;
        esac
        shift $(($(cat $SHIFTER) + 1))
        echo 0 >$SHIFTER
    done

    rm $SHIFTER && unset SHIFTER
    return 0
}

# @param {Array<string>} $1..$n - command line arguments
parse_param() {
    local param arg

    if [[ "$1" =~ .*=.* ]]; then
        param="${1%%=*}"
        arg="${1#*=}"
    elif [[ "${2-}" =~ ^[^-].+ ]]; then
        param="$1"
        arg="$2"
        echo 1 >$SHIFTER
    fi

    if [ ! "${arg-}" ] && [ ! "${OPTIONAL-}" ]; then
        error "${param-$1} requires an argument"
        exit 1
    fi
    echo "${arg-}"
    return 0
}

staterr() {
    local -a args=()
    local quit usage message
    exec 1>&2

    while [ $# -gt 0 ]; do
        case "$1" in
            -s) # silent
                exec 2>/dev/nulll
                shift
                ;;
            -q) # quit
                quit=0
                shift
                ;;
            -u) # usage
                usage=0
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    message="$(basename $0): ${args[@]}"
    [ -n "${message-}" ] && printf "%s\n" "${message}"
    [ -n "${usage-}" ] && printf "%s\n" "${message}"
    [ -n "${quit-}" ] && exit 1
    return 0
}

fatal() {
    staterr -q "$@"
}

error() {
    staterr -q "$@"
}

warn() {
    staterr "$@"
}

log() {
    printf "%s: $@\n" "$(basename $0)"
}


# Program start
# --------------------------------------------------
main "$@"
