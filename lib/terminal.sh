terminal_text_editor_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        multi_select tte_options "${terminal_text_editors[@]}" "Skip"
        [[ " ${tte_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${tte_options[@]}"
}

terminal_emulator_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        multi_select terminal_options "${terminals[@]}" "Skip"
        [[ " ${terminal_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${terminal_options[@]}"
}