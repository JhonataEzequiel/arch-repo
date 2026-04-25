multi_select() {
    local -n _result=$1
    shift
    local question="$1"
    shift
    local options=("$@")
    local selected=()
    local cursor=0
    local key seq

    for (( i=0; i<${#options[@]}; i++ )); do
        selected+=(false)
    done

    _draw_multi() {
        local i
        [[ -n "$question" ]] && printf "%s\n" "$question"
        for (( i=0; i<${#options[@]}; i++ )); do
            local mark="[ ]"
            [[ "${selected[$i]}" == true ]] && mark="[x]"
            if [[ $i -eq $cursor ]]; then
                printf "\e[7m  %s %s\e[0m\n" "$mark" "${options[$i]}"
            else
                printf "  %s %s\n" "$mark" "${options[$i]}"
            fi
        done
        printf "\n  [space] select/deselect   [enter] confirm   [up/down] navigate\n"
    }

    _clear_multi() {
        local lines=$(( ${#options[@]} + 2 ))
        [[ -n "$question" ]] && lines=$(( lines + 1 ))
        local i
        for (( i=0; i<lines; i++ )); do
            printf "\e[1A\e[2K"
        done
    }

    printf "\e[?25l"
    _draw_multi

    while true; do
        IFS= read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            read -rsn1 -t 0.1 seq
            if [[ $seq == '[' ]]; then
                read -rsn1 -t 0.1 seq
                case $seq in
                    'A')
                        if [[ $cursor -gt 0 ]]; then
                            cursor=$(( cursor - 1 ))
                        fi
                        ;;
                    'B')
                        if [[ $cursor -lt $(( ${#options[@]} - 1 )) ]]; then
                            cursor=$(( cursor + 1 ))
                        fi
                        ;;
                esac
            fi
        elif [[ $key == ' ' ]]; then
            if [[ "${selected[$cursor]}" == true ]]; then
                selected[$cursor]=false
            else
                selected[$cursor]=true
            fi
        elif [[ $key == '' ]]; then
            break
        fi

        _clear_multi
        _draw_multi
    done

    printf "\e[?25h"

    _result=()
    for (( i=0; i<${#options[@]}; i++ )); do
        [[ "${selected[$i]}" == true ]] && _result+=("${options[$i]}")
    done

    unset -f _draw_multi _clear_multi
}

single_select() {
    local -n _result=$1
    shift
    local question="$1"
    shift
    local options=("$@")
    local cursor=0
    local key seq

    _draw_single() {
        local i
        [[ -n "$question" ]] && printf "%s\n" "$question"
        for (( i=0; i<${#options[@]}; i++ )); do
            if [[ $i -eq $cursor ]]; then
                printf "\e[7m  %s\e[0m\n" "${options[$i]}"
            else
                printf "  %s\n" "${options[$i]}"
            fi
        done
        printf "\n  [enter] confirm   [up/down] navigate\n"
    }

    _clear_single() {
        local lines=$(( ${#options[@]} + 2 ))
        [[ -n "$question" ]] && lines=$(( lines + 1 ))
        local i
        for (( i=0; i<lines; i++ )); do
            printf "\e[1A\e[2K"
        done
    }

    printf "\e[?25l"
    _draw_single

    while true; do
        IFS= read -rsn1 key

        if [[ $key == $'\x1b' ]]; then
            read -rsn1 -t 0.1 seq
            if [[ $seq == '[' ]]; then
                read -rsn1 -t 0.1 seq
                case $seq in
                    'A')
                        if [[ $cursor -gt 0 ]]; then
                            cursor=$(( cursor - 1 ))
                        fi
                        ;;
                    'B')
                        if [[ $cursor -lt $(( ${#options[@]} - 1 )) ]]; then
                            cursor=$(( cursor + 1 ))
                        fi
                        ;;
                esac
            fi
        elif [[ $key == '' ]]; then
            break
        fi

        _clear_single
        _draw_single
    done

    printf "\e[?25h"
    _result="${options[$cursor]}"

    unset -f _draw_single _clear_single
}
