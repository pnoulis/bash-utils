str='$one'
str2='one'

let i=0
let y=0
vars=()
char=
let varstart=0

while (( i < ${#str} )); do
    char=${str:$i:1}
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

echo "${vars[@]}"
