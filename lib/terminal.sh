terminal_text_editor_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Select the terminal text editors you want to install"
        multi_select tte_options "${terminal_text_editors[@]}" "Skip"
        [[ " ${tte_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${tte_options[@]}"
}

terminal_emulator_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Select the terminals you want to install"
        multi_select terminal_options "${terminals[@]}" "Skip"
        [[ " ${terminal_options[*]} " == *" Skip "* ]] && return
    fi

    install_pacman "${terminal_options[@]}"
    if [[ " ${terminal_options[*]} " == *" ghostty "* ]] && [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want my ghostty customization?"
        single_select custom_ghostty "Yes" "No"
        case $custom_ghostty in
            "Yes") cp -r configs/ghostty ~/.config/
        esac
    fi
}

terminal_utilities_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Select the terminal packages you want to install"
        multi_select terminal_utilities_options "${terminal_tools[@]}" "Skip"
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
        echo "Do you want to install Zsh?"
        single_select zsh_choice "Yes" "No"
        [[ "$zsh_choice" == "No" ]] &&  return 0
        choices[shell]=zsh
    fi

    install_pacman "${zsh_plugins[@]}"
    chsh -s "$(which zsh)"
}

shell_customizations() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want my shell customizations? (The fastfetch config will only be applied to ghostty or kitty)"
        single_select shell_c "Yes" "No"
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