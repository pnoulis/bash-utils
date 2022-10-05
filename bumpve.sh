#!/bin/bash

# bumpve
# Bump up or down, a version following the semantic versioning scheme
# https://semver.org/


# Options
## -------------------------------------- ##
VERSION=
ELEMENT_TARGET=
IDENTIFIER_TARGET=
STITCH=
STITCH_ALL=
LAX=0
QUIET=

function usage {
    cat <<EOF
${0}: [OPTION]... version
-c core
-r release
-b build
-M major
-m minor
-p patch
-s stitch {just up to the current identifier of the current element being bumped}
-S stitch all
-q quiet
-h help
EOF
}

# Utils
# --------------------------------------- ##
# Core[-PreRelease[+Build] | -PreRelease | +Build]
PREFIX_RE="[vV]"
CORE_RE="(?:0\.|[1-9]\d*\.){2}(?:0|[1-9]\d*)"
RELEASE_RE="(?:(?:[-1-9][-0-9]*|[-a-zA-Z]*|0)\.)*(?:[-1-9][-0-9]*|[-a-zA-Z]*|0)"
BUILD_RE="(?:[-a-zA-Z0-9]*\.)*[-a-zA-Z0-9]*"
SEMVER_RE="^${PREFIX_RE}?${CORE_RE}(?:-${RELEASE_RE})?(?:\\+${BUILD_RE})?\$"
DATE_FMT=(
    [0]="%a-%d-%m-%Y"
    [1]="%Y%m%d"
    [2]="%d%m%Y"
    [3]="%a%d%m%Y"
)
elements=

# params
# { string,... } identifiers
function joinTokens {
    local str=""
    local len=$#
    for (( i = 1; i < len; i++ )); do
        [[ "${!i}" ]] && str+="${!i}."
    done
    str+="${!len}"
    echo $str
    return 0
}

function stateError {
    [[ $QUIET ]] && exit 1
    exit 1
}

function readSchema {
    schema='{
        "core": [
            0,
            0,
            0
        ],
        "release": [
            ["alpha", "beta", "rc"],
            0
        ],
        "build": [
            { "_date": 3 },
            0
        ]
    }'
    echo -n "$schema"
}

# params
# { string } element
# { integer } identifier
function expandIdentifier {
    readSchema | jq -r --arg e $1 --arg i $2 '
    .[$e][$i|tonumber] |
    if type == "array" then ["array", .[]] | join(" ")
    elif type == "object" then to_entries[] | flatten | ["object", .[]] | join(" ")
    elif type == "number" then ["number", .] | join(" ")
    else null end
    '
}

# params
# { string } element
function getIdentifierKeys {
    readSchema | jq -r --arg e $1 '.[$e]? | [range(0, length)] | join("\n")'
}

# params
# { string } format string %d%m...
function _date {
    local defaults=(
        [0]="%a-%d-%m-%Y"
        [1]="%Y%m%d"
        [2]="%d%m%Y"
        [3]="%a%d%m%Y"
    )
    if [[ -z "$1" || "$1" -lt ${#defaults[@]} ]]; then
        echo "$(date +"${defaults[$1]}")"
    else
        echo "$(date "$1")"
    fi
}

# params
# { string } schema key
# { integer } identifier
function stitch {
    local patch=()
    while read key; do
        read -a ids <<< "$(expandIdentifier "$1" $key)"
        case "${ids[0]}" in
            array)
                patch[$key]="${ids[1]}"
                ;;
            object)
                patch[$key]=$(eval "${ids[@]:1}")
                ;;
            number)
                patch[$key]="${ids[1]}"
                ;;
            *)
                ;;
        esac
    done <<< "$(getIdentifierKeys "$1")"
    joinTokens "${patch[@]}"
}


# params
# { string } element $1
# { integer } identifier $2
function bumpCore {
    IFS="." read -a tokens <<< "$1"
    local i=0
    local range=${#tokens[@]}

    [[ -n $IDENTIFIER_TARGET ]] && {
        echo "identifier target picked"
        range=$((IDENTIFIER_TARGET++))
        unset IDENTIFIER_TARGET
    }

    for ((i = 0; i <= $range; i++)); do
        echo $i
        (
            [[ -n "${tokens[$i]}" ]] && echo "some"
        ) || (
            [[ -z "${tokens[$i]}" && $STITCH ]] && echo "some"
        ) || stateError
    done

    # [[ -n $IDENTIFIER_TARGET ]] && {
    #     i=$IDENTIFIER_TARGET
    #     ((tokens[i]++))
    #     ((i++))
    # }

    # while [ $i -lt $len ]; do
    #     tokens[i]=0
    #     ((i++))
    # done
    # joinTokens "${tokens[@]}"
    # return 0
}


# params
# { string } element $1
# { boolean } mode $2
function bumpRelease {
    IFS="." read -a tokens <<< "$1"
    local major=("alpha" "beta" "rc")
    local i=


    # [[ -z $IDENTIFIER_TARGET || $STITCH ]] && i=0

    # case $i in
    #     0)
    #         [[ ! ${tokens[0]} && $STITCH ]] && tokens[0]=${major[0]}
    #         ;&
    #     1)
    #         [[ ! ${tokens[1]} && $STITCH ]] && tokens[1]=1
    #         ;;
    #     3)
    #         [[ ! ${tokens[2]} && $STITCH ]] && tokens[2]=0
    #         ;;
    #     *)
    #         stateError
    #         ;;
    # esac


    if [[ -z $IDENTIFIER_TARGET ]]; then # empty
        tokens[0]=${major[0]}
        tokens[1]=1
    elif [[ $IDENTIFIER_TARGET -ge len ]]; then # non empty out of bounds
        stateError
    else # non empty within bounds
        case $IDENTIFIER_TARGET in
            0)
                tokens[0]=${major[$IDENTIFIER_TARGET + 1]}
                unset IDENTIFIER_TARGET
                ;&
            1)
                ((tokens[1]++))
                unset IDENTIFIER_TARGET
                ;;
            *)
                stateError
                ;;
        esac
    fi
    joinTokens "${tokens[@]}"
}

function bumpBuild {
    IFS="." read -a tokens <<< "$1"
    local major=$(date +${DATE_FMT[3]})
    tokens[0]="$major"
    tokens[1]=1

    [[ $IDENTIFIER_TARGET -gt 0 ]] && {
        ((tokens[1]++))
    }

    joinTokens "${tokens[@]}"
    return 0
}

# params
# { string } semver element $1
# { integer } semver element type $2 CORE | RELEASE | BUILD
function bump {
    case "$2" in
        1) # CORE
            bumpCore "$1"
            ;;
        2) # RELEASE
            bumpRelease "$1"
            ;;
        3) # BUILD
            bumpBuild "$1"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

while getopts ":hcrbMmpsSq" o; do
    case $o in
        c) # core
            ELEMENT_TARGET=0
            ;;
        r) # release
            ELEMENT_TARGET=1
            ;;
        b) # build
            ELEMENT_TARGET=2
            ;;
        M) # major
            IDENTIFIER_TARGET=0
            ;;
        m) # minor
            IDENTIFIER_TARGET=1
            ;;
        p) # patch
            IDENTIFIER_TARGET=2
            ;;
        s) # stitch
            STITCH=0
            # completes missing parts if any of a semver according to provided
            # release and build schemes
            ;;
        S) # stitch all
            STITCH_ALL=0
            ;;
        l) # lax
            LAX=0
            ;;
        q) # quiet
            QUIET=0
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage > /dev/stderr
            exit 1
            ;;
    esac
done

shift $((OPTIND - 1))

#VERSION="v1.0.0-alpha.1+build.1"
# VERSION="v1.0.0+build.1"
VERSION=

# Where +1 offsets the prefix at elements[0]
((ELEMENT_TARGET++))
echo "VERSION: ${VERSION}"
echo "ELEMENT TARGET: ${ELEMENT_TARGET}"
echo "IDENTIFIER TARGET: ${IDENTIFIER_TARGET}"
echo -----------------------------

elements=(
    [0]="$(grep -Po "${PREFIX_RE}" <<< "$VERSION")"
    [1]="$(grep -Po "${CORE_RE}" <<< "$VERSION")"
    [2]="$(grep -Po "\-${RELEASE_RE}\\+" <<< "$VERSION" | sed 's/[-+]//g')"
    [3]="$(grep -Po "\\+${BUILD_RE}$" <<< "$VERSION" | sed 's/[+]//g')"
)

[[ $STITCH_ALL ]] && {
    unset STITCH
    [[ -z "${elements[1]}" ]] && {
        elements[1]=$(stitch "core")
    }
    [[ -z "${elements[2]}" ]] && {
        elements[2]=$(stitch "release")
    }
    [[ -z "${elements[3]}" ]] && {
        elements[3]=$(stitch "build")
    }
}
joinTokens "${elements[@]}"
bumpCore "${elements[$ELEMENT_TARGET]}"

# case $ELEMENT_TARGET in
#     0)
#         bumpCore "${elements[$ELEMENT_TARGET]}"
#         ;&
#     1)
#         bumpRelease "${elements[$ELEMENT_TARGET]}"
#         ;&
#     2)
#         bumpBuild "${elements[$ELEMENT_TARGET]}"
#         ;&
#     *)
#         stateError
#         ;;
# esac

# echo "${elements[@]}"

# elements[$ELEMENT_TARGET]=$(bump "${elements[ELEMENT_TARGET]}" $ELEMENT_TARGET)
# unset IDENTIFIER_TARGET
# ((ELEMENT_TARGET++))

# while [ $ELEMENT_TARGET -le 3 ]; do
#     echo $ELEMENT_TARGET
#     elements[$ELEMENT_TARGET]=$(bump "${elements[$ELEMENT_TARGET]}" $ELEMENT_TARGET)
#     ((ELEMENT_TARGET++))
# done

# VERSION="${elements[0]}${elements[1]}-${elements[2]}+${elements[3]}"
# echo "$VERSION"
