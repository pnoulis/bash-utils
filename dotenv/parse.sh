#!/usr/bin/env bash

shopt -s extglob

strip_punct() {
    echo "$(echo $1 | sed s/[$\{\}\\]//gi)"
}

parse_env() {
    local envar=$1
    local -a parsed=()
    local char=''
    let lenparsed=0

    while [[ -n "${envar:-}" ]]; do
        char=${envar:0:1}
        envar=${envar#?}

        parsed[lenparsed]+=$char

        if [[ -z "${envar:-}" ]]; then
            # EOS = End Of String
            parsed[lenparsed]+='EOS'
        fi

        echo "${parsed[lenparsed]}"
        case "${parsed[lenparsed]}" in
            # $one$
            \$+([[:alnum:]_/-])\$)
                echo 'matches $one$'
                parsed[lenparsed++]="expand=$(strip_punct ${parsed[lenparsed]})"
                parsed[lenparsed]='$'
                ;;
            # ${one}
            \$\{+([[:alnum:]_/:-])\})
                echo 'maches ${one}'
                parsed[lenparsed++]="expand=$(strip_punct ${parsed[lenparsed]})"
                ;;
            # punct$
            +([:/_-])\$)
                echo 'matches punct'
                parsed[lenparsed++]="literal=${parsed[lenparsed]%?}"
                parsed[lenparsed]='$'
                ;;
            # one$
            +([[:alnum:]_/-])[a-zA-Z]*([[:alnum:]_/:-])\$)
                echo 'matches one$'
                parsed[lenparsed++]="literal=$(strip_punct ${parsed[lenparsed]})"
                parsed[lenparsed]='$'
                ;;
            # one\$
            +([[:alnum:]_/-])[a-zA-Z]*([[:alnum:]_/:-])\\\$)
                echo 'matches one\$'
                parsed[lenparsed++]="literal=$(strip_punct ${parsed[lenparsed]})"
                parsed[lenparsed]='\$'
                ;;
            # \$one$
            \\\$+([[:alnum:]_/:-])\$)
                echo 'matches \$one$'
                parsed[lenparsed++]="literal=${parsed[lenparsed]#?}"
                parsed[lenparsed]='$'
                ;;
            # \${one}
            \\\$\{+([[:alnum:]_/:-])\})
                echo 'matches \${one}'
                parsed[lenparsed++]="literal=${parsed[lenparsed]#?}"
                ;;
            # \$..EOS
            \\\$*EOS)
                echo 'maches \$..EOS'
                parsed[lenparsed]="${parsed[lenparsed]#?}"
                parsed[lenparsed++]="literal=${parsed[lenparsed]%???}"
                ;;
            # $oneEOS
            # ${one}EOS
            \$?(\{)*EOS)
                echo 'matches $oneEOS'
                parsed[lenparsed++]="expand=$(strip_punct ${parsed[lenparsed]%???})"
                ;;
            # oneEOS
            [[:alnum:][:punct:]]*EOS)
                echo 'matches *EOS'
                parsed[lenparsed++]="literal=$(strip_punct ${parsed[lenparsed]%???})"
                ;;
            *)
                continue
                ;;
        esac
    done
    echo "${parsed[@]}"
}

 # Returns an array of strings each of the form
# action=value
# the action part specifies how the value should be interpreted.
# Available actions are:
# 1. expand
# 2. exec
# 3. literal



parse_env '${BACKEND_PROTOCOL}://${BACKEND_HOST}:${BACKEND_PORT}\'
