wine_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want to install Wine?"
        single_select wine_choice "Yes" "No"
        choices[wine_install]=$wine_choice
    fi

    case ${choices[wine_install]} in
        "Yes"|true)
            echo "Installing Wine and dependencies..."
            install_pacman "${wine_and_dependencies[@]}"
            ;;
        "No"|false)
            echo "Skipping Wine installation."
            ;;
    esac
}

gaming_setup() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want to install gaming packages?"
        single_select gaming_choice "Yes" "No"
        choices[gaming_packages]=$gaming_choice
    fi

    case ${choices[gaming_packages]} in
        "Yes"|true)
            echo "Installing gaming packages..."
            echo "vm.max_map_count = 2147483642" | sudo tee /etc/sysctl.d/80-gamecompatibility.conf
            install_yay "${gaming[@]}"
            ;;
        "No"|false)
            echo "Skipping gaming packages."
            ;;
    esac
}