check_prerequisites() {
    if [[ ! -f /etc/arch-release ]]; then
        echo "Error: This script is designed for Arch Linux only."
        exit 1
    fi
    install_pacman git
    for cmd in pacman sudo; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: $cmd is not installed."
            exit 1
        fi
    done
}

update_mirrors() {
    echo "Updating mirrorlist for faster downloads..."
    install_pacman "${mirrors_prereqs[@]}"

    sudo reflector --sort rate --latest 20 --protocol https --save /etc/pacman.d/mirrorlist
    echo "Mirrorlist updated."
    sudo pacman -Syy --noconfirm
}

set_variables() {
    echo "Choose your installation method:"
    echo "1) Manual (choose everything yourself)"
    echo "2) GNOME + gaming"
    echo "3) GNOME, no gaming"
    echo "4) KDE Plasma + gaming"
    echo "5) KDE Plasma, no gaming"
    echo "6) Exit"
    read -p "Enter 1-6: " mode

    choices[chosen_mode]=$mode

    if [[ ! "${choices[chosen_mode]}" =~ ^[1-6]$ ]]; then
        echo "Invalid input."
        exit 1
    fi

    [[ "${choices[chosen_mode]}" == "6" ]] && exit 0

    choices[terminal]=kitty
    choices[terminal_utilities]=true
    choices[terminal_text_editor]=micro
    choices[shell]=zsh
    choices[shell_customization]=true
    choices[wine_install]=true
    choices[printer_support]=1
    choices[gaming_packages]=true

    case ${choices[chosen_mode]} in
        2) choices[desktop]=1; choices[gaming_packages]=true; choices[terminal]=gnome-console ;;
        3) choices[desktop]=1; choices[gaming_packages]=false; choices[terminal]=gnome-console ;;
        4) choices[desktop]=2; choices[gaming_packages]=true; choices[terminal]=konsole ;;
        5) choices[desktop]=2; choices[gaming_packages]=false; choices[terminal]=konsole ;;
    esac
}

choose_de() {
    while true; do
        if [[ "${choices[chosen_mode]}" == "1" ]]; then
            echo "Choose your Desktop Environment:"
            echo "1) GNOME"
            echo "2) KDE Plasma"
            echo "3) Exit"
            read -p "Enter 1-3 [2]: " choiceDE
            choices[desktop]=${choiceDE:-2}
        fi

        case ${choices[desktop]} in
            1)
                echo "Installing GNOME..."
                install_pacman "${gnome_core[@]}" "${gnome_config[@]}" "${gnome_files[@]}" "${gnome_gvfs[@]}" "${gnome_apps[@]}" && break || { echo "GNOME installation failed."; exit 1; }
                ;;
            2)
                echo "Installing KDE Plasma..."
                install_pacman "${kde_core[@]}" "${kde_visual[@]}" "${kde_hardware[@]}" "${kde_files[@]}" "${kde_apps[@]}" && break || { echo "KDE installation failed."; exit 1; }
                ;;
            3)
                echo "Exiting."
                exit 0
                ;;
            *)
                echo "Invalid Choice. Please Enter 1-3"
                ;;
        esac
    done

    if systemctl is-enabled gdm &>/dev/null || systemctl is-enabled plasma-login-manager &>/dev/null; then
        echo "A display manager is already enabled. Skipping."
    else
        case ${choices[desktop]} in
            1) sudo systemctl enable gdm                   && echo "Enabled GDM." ;;
            2) sudo systemctl enable plasma-login-manager  && echo "Enabled Plasma Login Manager." ;;
        esac
    fi
}

install_basic_features() {
    install_pacman "${base_packages[@]}"
    sudo systemctl enable paccache.timer
    sudo systemctl enable --now ufw.service

    install_pacman "${audio[@]}"
    install_pacman "${rendering[@]}"

    bluetooth_setup

    if [[ "${choices[chosen_mode]}" == "1" ]]; then
        echo "Do you want to install printer support?"
        echo "1) Yes  2) No"
        read -p "Enter 1-2: " choicePRIN
        choices[printer_support]=$choicePRIN
    fi

    printer_setup
    fcitx5_setup
    aur_setup
}

bluetooth_setup() {
    if lsmod | grep -qi bluetooth; then
        install_pacman "${bluetooth[@]}"
        sudo systemctl enable --now bluetooth.service
    fi
}

printer_setup() {
    case ${choices[printer_support]} in
        1)
            install_pacman "${printer[@]}"
            sudo systemctl enable --now cups.socket
            sudo systemctl enable --now avahi-daemon.service
            sudo sed -i.bak '/^hosts:/c\hosts: files mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns myhostname' /etc/nsswitch.conf
            sudo usermod -aG lp,sys,wheel "$USER"
            ;;
    esac
}

fcitx5_setup() {
    local ENV_FILE="/etc/environment"
    local env_vars=(
        "GTK_IM_MODULE=fcitx"
        "QT_IM_MODULE=fcitx"
        "XMODIFIERS=@im=fcitx"
    )
    for var in "${env_vars[@]}"; do
        grep -qF "$var" "$ENV_FILE" || echo "$var" | sudo tee -a "$ENV_FILE" > /dev/null
    done
    echo "Fcitx5 environment variables written to ${ENV_FILE}."
}

aur_setup() {
    if ! command -v yay &>/dev/null; then
        local go_preinstalled=false
        pacman -Qs go &>/dev/null && go_preinstalled=true

        install_pacman go
        echo "Installing yay..."
        git clone https://aur.archlinux.org/yay.git
        (cd yay && makepkg -si --noconfirm)
        rm -rf yay

        [[ "$go_preinstalled" == false ]] && remove_pacman go
    else
        echo "yay is already installed."
    fi

    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    sudo tee -a /etc/pacman.conf > /dev/null <<- 'EOF'
    [chaotic-aur]
    Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    sudo pacman -Syu --noconfirm
}