multi_select() {
    local -n _result=$1
    shift
    local options=("$@")
    local selected=()
    local cursor=0
    local key

    for (( i=0; i<${#options[@]}; i++ )); do
        selected+=(false)
    done

    tput civis

    # Initial draw
    for (( i=0; i<${#options[@]}; i++ )); do
        if [[ "${selected[$i]}" == true ]]; then
            local mark="[x]"
        else
            local mark="[ ]"
        fi
        if [[ $i -eq $cursor ]]; then
            echo -e "\e[7m  $mark ${options[$i]}\e[0m"
        else
            echo "  $mark ${options[$i]}"
        fi
    done
    echo ""
    echo "  [space] select/deselect   [enter] confirm   [↑↓] navigate"

    while true; do
        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case $key in
                '[A') (( cursor > 0 )) && (( cursor-- )) ;;
                '[B') (( cursor < ${#options[@]} - 1 )) && (( cursor++ )) ;;
            esac
        elif [[ $key == ' ' ]]; then
            if [[ "${selected[$cursor]}" == true ]]; then
                selected[$cursor]=false
            else
                selected[$cursor]=true
            fi
        elif [[ $key == '' ]]; then
            break
        fi

        # Redraw
        tput cuu $(( ${#options[@]} + 2 ))
        for (( i=0; i<${#options[@]}; i++ )); do
            tput el
            if [[ "${selected[$i]}" == true ]]; then
                local mark="[x]"
            else
                local mark="[ ]"
            fi
            if [[ $i -eq $cursor ]]; then
                echo -e "\e[7m  $mark ${options[$i]}\e[0m"
            else
                echo "  $mark ${options[$i]}"
            fi
        done
        echo ""
        tput el
        echo "  [space] select/deselect   [enter] confirm   [↑↓] navigate"
    done

    tput cnorm
    _result=()
    for (( i=0; i<${#options[@]}; i++ )); do
        [[ "${selected[$i]}" == true ]] && _result+=("${options[$i]}")
    done
}

single_select() {
    local -n _result=$1
    shift
    local options=("$@")
    local cursor=0
    local key

    tput civis

    # Initial draw
    for (( i=0; i<${#options[@]}; i++ )); do
        if [[ $i -eq $cursor ]]; then
            echo -e "\e[7m  ${options[$i]}\e[0m"
        else
            echo "  ${options[$i]}"
        fi
    done
    echo ""
    echo "  [enter] confirm   [↑↓] navigate"

    while true; do
        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.1 key
            case $key in
                '[A') (( cursor > 0 )) && (( cursor-- )) ;;
                '[B') (( cursor < ${#options[@]} - 1 )) && (( cursor++ )) ;;
            esac
        elif [[ $key == '' ]]; then
            break
        fi

        # Redraw
        tput cuu $(( ${#options[@]} + 2 ))
        for (( i=0; i<${#options[@]}; i++ )); do
            tput el
            if [[ $i -eq $cursor ]]; then
                echo -e "\e[7m  ${options[$i]}\e[0m"
            else
                echo "  ${options[$i]}"
            fi
        done
        echo ""
        tput el
        echo "  [enter] confirm   [↑↓] navigate"
    done

    tput cnorm
    _result="${options[$cursor]}"
}