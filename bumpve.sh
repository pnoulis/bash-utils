#!/bin/bash

# bumpve
# Bump up or down, a version following the semantic versioning scheme
# https://semver.org/


# Options
## -------------------------------------- ##
VERSION=
#VERSION="v1.0.0-alpha.1+build.1"
#VERSION="v1.0.0+build.1"
ELEMENT_TARGET=
IDENTIFIER_TARGET=
STITCH=
PREFIX=
VALIDATE=
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
stitchUpperBound=
stitchLowerBound=
declare -A elements
elements=(
    ["core"]=
    ["release"]=
    ["build"]=
)
declare -A targets
# potentially:
# targets=(
#     ["core"]=
#     ["release"]=
#     ["build"]=
# )

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
# element
calculateStitchBounds() {
    [[ -z $STITCH ]] && return 0

    case "$STITCH" in
        i) # only identifier #id
        ;;
        l) # element up to and including identifier # eltoid
        ;;
        e) # element # el
        ;;
        v) # across element boundaries up to and including identifier # vtoid
        ;;
        V) # the whole version # vtov
        ;;
        *)
            stateError
            ;;
    esac
}

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
            { "_date": ["one", "two"] },
            0
        ]
    }'
    echo -n "$schema"
}

# params
# { string } element $1 {core | release | buid}
# { integer } identifier $2 {0, 1, ...}
expandSchemaIdentifier() {
    readSchema | jq -r --arg e "$1" --arg i "$2" '
    .[$e][$i|tonumber]
    | if type == "array" then ["array", .[]] | join(" ")
    elif type == "object" then to_entries[] | ["object", .key, (.value | join(","))] | join(" ")
    elif type == "number" then ["number", .] | join(" ")
    else null end
'
}

# params
# { string } element $1 {core | release | build}
getSchemaElementIndices() {
    readSchema | jq -r --arg e "$1" '.[$e] | [range(0, length)] | join(" ")'
}

# params
# { string } element {core,release,build}
getSchemaElementLength() {
    readSchema | jq -r --arg e "$1" '.[$e] | length'
}

# params
# { string } element $1 {core | release | build}
# { integer } identifier $2 {0 | 1 | 2}

# params
# { string } schema key $1
# { integer } identifier $2
# { any } previous identifier value $3
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

translateBumpArgument() {
    case "$1" in
        M) # major
            echo -n 0
            ;;
        m) # minor
            echo -n 1
            ;;
        p) # patch
            echo -n 2
            ;;
        *)
            stateError
            ;;
    esac
}
while getopts ":hc:r:b:s:pvq" o; do
    case $o in
        c) # core
            targets["core"]=$(translateBumpArgument "$OPTARG")
            ;;
        r) # release
            targets["release"]=$(translateBumpArgument "$OPTARG")
            ;;
        b) # build
            targets["build"]=$(translateBumpArgument "$OPTARG")
            ;;
        s) # stitch
            STITCH="$OPTARG"
            ;;
        p) # prefix
            echo "prefix"
            ;;
        v) # validate
            echo "validate"
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

cat <<EOF
VERSION: ${VERSION}
core target: "${targets[core]}"
release target: "${targets[release]}"
build target: "${targets[build]}"
---------------------------------------------------------------
EOF

# elements["version"]="$(grep -Po "${PREFIX_RE}" <<< "$VERSION")"
elements["core"]="$(grep -Po "${CORE_RE}" <<< "$VERSION")"
elements["release"]="$(grep -Po "\-${RELEASE_RE}\\+" <<< "$VERSION" | sed 's/[-+]//g')"
elements["build"]="$(grep -Po "\\+${BUILD_RE}$" <<< "$VERSION" | sed 's/[+]//g')"

# schema=""
for i in "${!elements[@]}"; do
    IFS="." read -a identifiers <<< "${elements[i]}"
    for y in "$(getSchemaElementIndices $i)"; do
        echo $i : "$y"
    done
done

declare -A lengths
declare -A offsets
lengths["core"]=$(getSchemaElementLength "core")
lengths["release"]=$(getSchemaElementLength "release")
lengths["build"]=$(getSchemaElementLength "build")
lengths["total"]=$((${lengths["core"]} + ${lengths["release"]} + ${lengths["build"]}))
offsets["core"]=0
offsets["release"]=$((${lengths["core"]} - 1))
offsets["build"]=$((${lengths["release"]} + ${offsets["release"]}))
[[ -z $STITCH ]] && {
    case "$STITCH" in
        i) # only identifier #id
        ;;
        l) # element up to and including identifier # eltoid
        ;;
        e) # element # el
        ;;
        v) # across element boundaries up to and including identifier # vtoid
        ;;
        V) # the whole version # vtov
        ;;
        *)
            stateError
            ;;
    esac
}

echo "${lengths[@]}"
echo "${offsets[@]}"

