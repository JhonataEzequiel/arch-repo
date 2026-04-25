grub_theme_selection() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare grub_theme
        single_select grub_theme "What theme do you want for GRUB?" \
            "Lain (credits: https://github.com/uiriansan)" \
            "Tela (credits: https://github.com/vinceliuice/grub2-themes)" \
            "Stylish (credits: https://github.com/vinceliuice/grub2-themes)" \
            "Vimix (credits: https://github.com/vinceliuice/grub2-themes)" \
            "WhiteSur (credits: https://github.com/vinceliuice/grub2-themes)" \
            "Fallout (credits: https://github.com/shvchk/fallout-grub-theme)" \
            "No"
        choices[grub_theme]=$grub_theme
    fi

    case "${choices[grub_theme]}" in
        Lain*)
            git clone --depth=1 https://github.com/uiriansan/LainGrubTheme
            cd LainGrubTheme
            ./install.sh && ./patch_entries.sh
            cd ..
            rm -rf LainGrubTheme
            ;;
        Tela*|Stylish*|Vimix*|WhiteSur*)
            git clone https://github.com/vinceliuice/grub2-themes.git
            cd grub2-themes
            chmod +x install.sh

            local RESOLUTION="1080p"
            if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
                declare resolution_choice
                single_select resolution_choice "What's your display resolution?" "1080p" "2k" "4k" "ultrawide" "ultrawide2k" "none"
                RESOLUTION=$resolution_choice
            fi

            case "${choices[grub_theme]}" in
                Tela*)    sudo ./install.sh -t tela     -s "$RESOLUTION" ;;
                Stylish*) sudo ./install.sh -t stylish  -s "$RESOLUTION" ;;
                Vimix*)   sudo ./install.sh -t vimix    -s "$RESOLUTION" ;;
                WhiteSur*)sudo ./install.sh -t whitesur -s "$RESOLUTION" ;;
            esac
            cd ..
            rm -rf grub2-themes
            ;;
        Fallout*)
            git clone https://github.com/shvchk/fallout-grub-theme.git
            cd fallout-grub-theme
            chmod +x install.sh
            ./install.sh
            cd ..
            rm -rf fallout-grub-theme
            ;;
        No)
            echo "Skipping GRUB theme."
            ;;
    esac
}

grub_setup() {
    if ! command -v grub-mkconfig &>/dev/null && ! command -v grub-install &>/dev/null; then
        echo "GRUB is not installed. Skipping grub setup."
        return 0
    fi

    echo "Installing GRUB packages..."
    install_pacman "${grub_packages[@]}"

    grub_theme_selection

    local GRUB_CONF="/etc/default/grub"

    echo "Configuring GRUB..."

    sudo sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' "$GRUB_CONF"

    if grep -q '^GRUB_SAVEDEFAULT=' "$GRUB_CONF"; then
        sudo sed -i 's/^GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' "$GRUB_CONF"
    elif grep -q '^#GRUB_SAVEDEFAULT=' "$GRUB_CONF"; then
        sudo sed -i 's/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=true/' "$GRUB_CONF"
    else
        echo "GRUB_SAVEDEFAULT=true" | sudo tee -a "$GRUB_CONF" > /dev/null
    fi

    if grep -q '^GRUB_DISABLE_OS_PROBER=' "$GRUB_CONF"; then
        sudo sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_CONF"
    elif grep -q '^#GRUB_DISABLE_OS_PROBER=' "$GRUB_CONF"; then
        sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$GRUB_CONF"
    else
        echo "GRUB_DISABLE_OS_PROBER=false" | sudo tee -a "$GRUB_CONF" > /dev/null
    fi

    echo "GRUB configuration updated."

    sudo grub-mkconfig -o /boot/grub/grub.cfg
    sudo update-grub
}
