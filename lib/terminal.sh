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
        local has_all=false
        local has_skip=false

        while true; do
            multi_select terminal_utilities_options "Select the terminal packages you want to install" "${terminal_tools[@]}" "All" "Skip"

            has_all=false
            has_skip=false
            [[ " ${terminal_utilities_options[*]} " == *" All "* ]] && has_all=true
            [[ " ${terminal_utilities_options[*]} " == *" Skip "* ]] && has_skip=true

            if [[ "$has_all" == true && "$has_skip" == true ]]; then
                echo "\"All\" and \"Skip\" are contradictory - please select again."
                continue
            fi

            break
        done

        [[ "$has_skip" == true ]] && return

        if [[ "$has_all" == true ]]; then
            # "All" was picked, possibly alongside individual tools too.
            # Install the full list once instead of trying to install "All"
            # as a package or installing anything picked alongside it twice.
            terminal_utilities_options=("${terminal_tools[@]}")
        fi
    else
        # Non-manual (opinionated) modes must still install the terminal
        # utilities, since shell_customizations() applies a zsh/bash config
        # that depends on tools like eza, bat, fd, ripgrep, and zoxide.
        terminal_utilities_options=("${terminal_tools[@]}")
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