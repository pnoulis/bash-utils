#!/bin/bash

declare -A lengths
declare -A offsets

getSize() {
}
getOffset() {
}
# params
# { string } element $1
# { integer } identifer $2
getIndex() {

}
getElement() {
}

while getopts "crbMmps:" o; do
    case "$o" in
        c)
            target["element"]="core"
        ;;
        r)
            target["element"]="release"
        ;;
        b)
            target["element"]="build"
        ;;
        M)
            target["identifier"]=0
        ;;
        m)
            target["identifier"]=1
        ;;
        p)
            target["identifier"]=2
        ;;
        *)
        ;;
    esac
done
