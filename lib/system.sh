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

prepare_pacman() {
    local PACMAN_CONF="/etc/pacman.conf"
    echo "Configuring pacman..."

    sudo sed -i 's/^#\(ILoveCandy\)/\1/' "$PACMAN_CONF"
    sudo sed -i 's/^#\(ParallelDownloads\s*=\s*\).*/\110/' "$PACMAN_CONF"

    echo "pacman.conf updated."
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
    declare mode
    single_select mode "Manual" "GNOME + gaming" "GNOME, no gaming" "KDE Plasma + gaming" "KDE Plasma, no gaming" "Exit"
    choices[chosen_mode]=$mode
    [[ "${choices[chosen_mode]}" == "Exit" ]] && exit 0

    terminal_options=(kitty)
    choices[terminal_utilities]=true
    tte_options=(micro)
    choices[shell]=zsh
    choices[shell_customization]=true
    choices[wine_install]=true
    choices[printer_support]="Yes"
    choices[gaming_packages]=true

    case ${choices[chosen_mode]} in
        "GNOME + gaming") choices[desktop]="Gnome"; choices[gaming_packages]=true; terminal_options=(gnome-console) ;;
        "GNOME, no gaming") choices[desktop]="Gnome"; choices[gaming_packages]=false; terminal_options=(gnome-console) ;;
        "KDE Plasma + gaming") choices[desktop]="KDE Plasma"; choices[gaming_packages]=true; terminal_options=(konsole) ;;
        "KDE Plasma, no gaming") choices[desktop]="KDE Plasma"; choices[gaming_packages]=false; terminal_options=(konsole) ;;
    esac
}

choose_de() {
    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Choose Your Desktop Environment"
        declare desktop_choice
        single_select desktop_choice "Gnome" "KDE Plasma" "Exit"
        choices[desktop]=$desktop_choice
    fi

    case ${choices[desktop]} in
        "Gnome")
            echo "Installing GNOME..."
            install_pacman "${gnome_core[@]}" "${gnome_config[@]}" "${gnome_files[@]}" "${gnome_gvfs[@]}" "${gnome_apps[@]}" || { echo "GNOME installation failed."; exit 1; }
            ;;
        "KDE Plasma")
            echo "Installing KDE Plasma..."
            install_pacman "${kde_core[@]}" "${kde_visual[@]}" "${kde_hardware[@]}" "${kde_files[@]}" "${kde_apps[@]}" || { echo "KDE installation failed."; exit 1; }
            ;;
        "Exit")
            exit 0
            ;;
    esac

    if systemctl is-enabled gdm &>/dev/null || systemctl is-enabled plasma-login-manager &>/dev/null; then
        echo "A display manager is already enabled. Skipping."
    else
        case ${choices[desktop]} in
            "Gnome")       sudo systemctl enable gdm                  && echo "Enabled GDM." ;;
            "KDE Plasma")  sudo systemctl enable plasma-login-manager && echo "Enabled Plasma Login Manager." ;;
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

    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        echo "Do you want to install printer support?"
        declare printer_choice
        single_select printer_choice "Yes" "No"
        choices[printer_support]=$printer_choice
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
        "Yes")
            install_pacman "${printer[@]}"
            sudo systemctl enable --now cups.socket
            sudo systemctl enable --now avahi-daemon.service
            sudo sed -i.bak '/^hosts:/c\hosts: files mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns myhostname' /etc/nsswitch.conf
            sudo usermod -aG lp,sys,wheel "$USER"
            ;;
        "No")
            echo "Skipping printer support."
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
    sudo tee -a /etc/pacman.conf > /dev/null <<'EOF'
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
    sudo pacman -Syu --noconfirm
}