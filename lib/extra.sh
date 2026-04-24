configure_extra_setup() {
    cronie_and_timeshift_setup
    [[ "${choices[desktop]}" == "Gnome" ]] && gnome_extra_setup
    extra_apps
    browser_selection
}

cronie_and_timeshift_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want to install Timeshift? (btrfs backup tool)"
        single_select time_choice "Yes" "No"
        choices[timeshift_choice]=$time_choice
    fi

    case "${choices[timeshift_choice]}" in
        "Yes"|true)
            install_pacman "${timeshift_config[@]}"
            sudo systemctl enable --now cronie.service
            ;;
        "No"|false)
            echo "Timeshift Skipped"
            ;;
    esac
}

gnome_extra_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want some extra gnome configuration?"
        single_select gnome_choice "Yes" "No"
        choices[gnome_extra_choice]=$gnome_choice
    fi

    case "${choices[gnome_extra_choice]}" in
        "Yes"|true)
            gsettings set org.gnome.mutter check-alive-timeout 0
            install_pacman "${gnome_gvfs_extra[@]}"
            install_yay "${gnome_extra[@]}"
    esac
}

extra_apps() {
    declare -a extra_choices
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Choose which extra packages you want to install"
        multi_select extra_choices "${extra[@]}" "None"
        [[ " ${extra_choices[*]} " == *" None "* ]] && return
        install_yay "${extra_choices[@]}"
    else
        install_yay "${extra[@]}"
    fi
}

browser_selection() {
    declare -a browser_choices
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Select which browsers you wish to install"
        multi_select browser_choices "${browsers[@]}" "None"
        [[ " ${browser_choices[*]} " == *" None "* ]] && return
        install_yay "${browser_choices[@]}"
    else
        install_yay "${choices[browser_choice]}"
    fi
}