declare -gA ENV=()

parse_envar() {
    local envar=$1
    local -a parsed=()
    let lenparsed=0
    let LOOKING_FOR_SS=1
    let LOOKING_FOR_SE=0
    let ESCAPING=0

    while [[ -n "${envar:-}" ]]; do
        char=${envar:0:1}
        envar=${envar#?}
        case $char in
            \\)
                if [[ "${envar:0:1}" == "$" ]]; then
                    ESCAPING=1
                    continue
                fi
                ;;
            \{)
                if (( LOOKING_FOR_SE )); then
                    # part of special token
                    continue
                fi
                ;;
            \$ | \})
                if (( ESCAPING == 1 )); then
                    ((++ESCAPING))
                elif (( ESCAPING == 2 )); then
                    ESCAPING=0
                    LOOKING_FOR_SS=1
                    if (( ${#parsed[lenparsed]} >= 1 )); then
                        parsed[lenparsed++]="literal=${parsed[lenparsed]}$char"
                    fi
                    continue
                elif (( LOOKING_FOR_SS )); then
                    LOOKING_FOR_SS=0
                    LOOKING_FOR_SE=1
                    if (( ${#parsed[lenparsed]} >= 1 )); then
                        parsed[lenparsed++]="literal=${parsed[lenparsed]}"
                    fi
                    continue
                elif (( LOOKING_FOR_SE )); then
                    LOOKING_FOR_SS=1
                    LOOKING_FOR_SE=0
                    parsed[lenparsed++]="expand=${parsed[lenparsed]}"
                    continue
                fi
                ;;
            *)
                ;;
        esac

        parsed[lenparsed]+=$char

        # END OF ENVAR
        if [[ -z "${envar:-}" ]]; then
            if (( LOOKING_FOR_SS )); then
                parsed[lenparsed++]="literal=${parsed[lenparsed]}"
            fi

            if (( LOOKING_FOR_SE )); then
                parsed[lenparsed++]="expand=${parsed[lenparsed]}"
            fi
        fi

    done
    echo "${parsed[@]}"
}

# expand environment variable
expand_envar() {
    local envar=$1
    local expanded=''
    local tmp=''

    while IFS='=' read -r action value; do
        case "${action:-}" in
            expand)
                # Fist try and expand the variable from ENV
                tmp=${ENV[$value]}
                # If value was not expanded try PROCENV
                if [[ -z "${tmp:-}" ]]; then
                    tmp=${PROCENV[$value]}
                fi
                # If the value remains unexpanded throw an error
                if [[ -z "${tmp:-}" ]]; then
                    fatal 'Failed expansion for' "$value" 'in' "$envar"
                else
                    expanded+="$tmp"
                fi
                ;;
            literal)
                expanded+="$value"
                ;;
            *)
                if [[ -z "${action:-}" && -n "${value:-}" ]]; then
                    fatal 'Failed expansion for' "$value" 'in' "$envar"
                fi
                ;;
        esac
    done < <(parse_envar "$envar" | tr ' ' '\n')

    echo "$expanded"
}

ENV["MQTT_PORT"]=8080


parse_envar 'MQTT_LOGIN_ROOT_URL=${MQTT_PROTOCOL}://${MQTT_LOGIN_ROOT_USERNAME}:${MQTT_LOGIN_ROOT_PASSWORD}@${MQTT_HOST}:${MQTT_PORT}'
