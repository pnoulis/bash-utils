#!/bin/bash

declare -a length
declare -a offset
declare -a elements
bumpTarget=0

main() {
    length[0]=$(getSchemaElementLength "core")
    length[1]=$(getSchemaElementLength "release")
    length[2]=$(getSchemaElementLength "build")
    length[3]=-1 # stitch length
    length[4]=$((${length[0]} + ${length[1]} + ${length[2]}))
    offset[0]=0
    offset[1]=$((${length[0]}))
    offset[2]=$((${offset[1]} + ${length[1]}))
    offset[3]=-1 # stitch offset

    while getopts "crbMmps:" o; do
        case "$o" in
            c)
                bumpTarget=$((${offset[0]} + bumpTarget))
                ;;
            r)
                bumpTarget=$((${offset[1]} + bumpTarget))
                ;;
            b)
                bumpTarget=$((${offset[2]} + bumpTarget))
                ;;
            M)
                bumpTarget=$((0 + bumpTarget))
                ;;
            m)
                bumpTarget=$((1 + bumpTarget))
                ;;
            p)
                bumpTarget=$((2 + bumpTarget))
                ;;
            s)
                IFS=':' read offset[3] length[3] <<<$OPTARG
                [ -z ${length[3]} ] && length[3]=${offset[3]}
                offset[3]=$(getIndex $(decodeClarg ${offset[3]:0:1}) $(decodeClarg ${offset[3]:1:1}))
                length[3]=$(getIndex $(decodeClarg ${length[3]:0:1}) $(decodeClarg ${length[3]:1:1}))
                [[ ${length[3]} -lt ${offset[3]} ]] && stateError
                ;;
            *)
                ;;
        esac
    done

    echoState
    elements[0]="$(grep -Po "${CORE_RE}" <<< "$VERSION")"
    elements[1]="$(grep -Po "\-${RELEASE_RE}\\+" <<< "$VERSION" | sed 's/[-+]//g')"
    elements[2]="$(grep -Po "\\+${BUILD_RE}$" <<< "$VERSION" | sed 's/[+]//g')"

    for i in "${!elements[@]}"; do
        IFS='.' read major minor patch <<< "${elements[i]}"
        for y in $(getSchemaElementIndices $(decodeClarg $i)); do
            y=$(getIndex $i $y)
            if [ -z ]
            if [ -n "$(shouldStitch $y)" ]; then
                echo "its not empty"
            else
                echo "its empty"
            fi
        done
    done
}

echoState() {
    echo bumptarget: $bumpTarget
    echo offset_core: ${offset[0]} offset_release: ${offset[1]} offset_build: ${offset[2]}
    echo stitch offset: ${offset[3]} stitch length: ${length[3]}
}
# param
# { string } message
stateError() {
    echo "error"
}
# params
# { any } a command line argument $1 {c | r | b | M | m | p | 0 | 1 | 2}
decodeClarg() {
    case $1 in
        c)
            echo -n 0
            ;;
        r)
            echo -n 1
            ;;
        b)
            echo -n 2
            ;;
        M)
            echo -n 0
            ;;
        m)
            echo -n 1
            ;;
        p)
            echo -n 2
            ;;
        0)
            echo -n 'core'
            ;;
        1)
            echo -n 'release'
            ;;
        2)
            echo -n 'build'
            ;;
        *)
            stateError
            ;;
    esac
}

readSchema() {
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
# { string } element {core,release,build}
getSchemaElementLength() {
    readSchema | jq -r --arg e "$1" '.[$e] | length'
}

# params
# { string } element $1 {core | release | build}
getSchemaElementIndices() {
    readSchema | jq -r --arg e "$1" '.[$e] | [range(0, length)] | join(" ")'
}

# params
# { string } element $1 {core | release | build}
getLength() {
    [[ ${#length[@]} -eq 0 ]] && {
        length["core"]=$(getSchemaElementLength "core")
        length["release"]=$(getSchemaElementLength "release")
        length["build"]=$(getSchemaElementLength "build")
        length["total"]=$((${length["core"]} + ${length["release"]} + ${length["build"]}))
    }
}

# params
# { integer } element $1 [0 = core | 1 = release | 2 = build]
# { integer } identifer $2 [0 = major | 1 = minor | 2 = patch]
getIndex() {
    echo $((${offset[$1]} + $2))
    return 0
}

# params
# { integer } element $1 [0 = core | 1 = release | 2 = build]
# { integer } identifier $2 [0 = major | 1 = minor | 2 = patch]
shouldStitch() {
    if [[ $1 -ge ${offset[3]} && $1 -le ${length[3]} ]]; then
        printf "%s" 'true'
    else
        printf "%s" ''
    fi
    return 0
}

# getElement() {
# }

main "$@"
