terminal_text_editor_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        multi_select tte_options "Select the terminal text editors you want to install" "${terminal_text_editors[@]}" "Skip"
        [[ " ${tte_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${tte_options[@]}"
}

terminal_emulator_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        multi_select terminal_options "Select the terminals you want to install" "${terminals[@]}" "Skip"
        [[ " ${terminal_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${terminal_options[@]}"
    if [[ " ${terminal_options[*]} " == *" ghostty "* ]] && [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare custom_ghostty
        single_select custom_ghostty "Do you want my ghostty customization?" "Yes" "No"
        case $custom_ghostty in
            "Yes") cp -r configs/ghostty ~/.config/
        esac
    fi
}

terminal_utilities_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        multi_select terminal_utilities_options "Select the terminal packages you want to install" "${terminal_tools[@]}" "Skip"
        [[ " ${terminal_utilities_options[*]} " == *" Skip "* ]] && return
    else
        return
    fi

    install_pacman "${terminal_utilities_options[@]}"
    if [[ " ${terminal_utilities_options[*]} " == *" tealdeer "* ]]; then
        tldr --update
    fi
    if [[ " ${terminal_utilities_options[*]} " == *" yazi "* ]]; then
        cp -r configs/yazi ~/.config/
    fi
}

install_zsh() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare zsh_choice
        single_select zsh_choice "Do you want to install Zsh?" "Yes" "No"
        [[ "$zsh_choice" == "No" ]] && return 0
        choices[shell]=zsh
    fi

    install_pacman "${zsh_and_plugins[@]}"
    chsh -s "$(which zsh)"
}

shell_customizations() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare shell_c
        single_select shell_c "Do you want my shell customizations? (The fastfetch config will only be applied to ghostty or kitty)" "Yes" "No"
        choices[shell_customization]=$shell_c
    fi

    case ${choices[shell_customization]} in
        "Yes"|true)
            curl -sS https://starship.rs/install.sh | sh -s -- --yes

            if [[ "${choices[shell]}" == "zsh" ]]; then
                cp configs/zsh ~/.zshrc
            else
                cp configs/bashrc ~/.bashrc
            fi

            if [[ " ${terminal_options[*]} " == *" ghostty "* ]] || [[ " ${terminal_options[*]} " == *" kitty "* ]]; then
                cp -r configs/fastfetch ~/.config/
                echo "Fastfetch config applied. To enable it, uncomment the fastfetch line in ~/.zshrc or ~/.bashrc."
            fi
            ;;
        "No"|false)
            echo "Skipping shell customizations."
            ;;
    esac
}
