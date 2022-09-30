#!/bin/bash

# Bumb version

VERSION=
PREFIX=
BUMP=

function usage {
    cat <<EOF
${0}: -option version
-M major
-m minor
-p patch
-h help
EOF
}

function isJSON {
    [[ "$VERSION" =~ \{.*\} ]] && return 0
    return 1
}

function extractVersionJSON {
    VERSION=$(echo "$VERSION" | sed -nE 's/"version":\s*"([vV]?[0-9.]+)"/\1/p')
}

function extractPrefix {
    PREFIX=$(echo "$VERSION" | sed -nE 's/^([^0-9]*)/\1/p')
}

function parse {
    echo "inparse"
    prefix=$(echo )
    IFS="." read -ra VERSION <<< "$VERSION"
    echo ${VERSION[0]}
    # for i in ${VERSION[@]}; do
    #     echo "$i"
    # done
}

while getopts ":hMmpb" o; do
    case $o in
        M) # major
            BUMP=0
            ;;
        m) # minor
            BUMP=1
            ;;
        p) # patch
            BUMP=2
            ;;
        b) # build
            BUMP=3
            ;;
        h)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done
[ $# -lt 2 ] && {
    usage
    exit 1
}
shift $((OPTIND - 1))

# VERSION="$1"
# isJSON && extractVersionJSON
# parse

# exit 0

VERSION="v1.0.0"
echo $VERSION | sed -E 's/([a-z]+)/\1/p'

