mirrors_prereqs=(
    reflector curl
)

base_packages=(
    wget pacman-contrib ufw python python-pip ufw openssh ntfs-3g linux-headers ibus flatpak pciutils base-devel dconf
)

extraction_packages=(
    unzip unrar 7zip tar zip
)

audio=(
    pipewire pipewire-pulse pipewire-alsa lib32-pipewire pipewire-audio pipewire-v4l2 wireplumber
)

bluetooth=(
    bluez bluez-utils
)

printer=(
    cups cups-filters ghostscript gsfonts avahi nss-mdns
)

rendering=(
    imagemagick ffmpeg poppler gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav x264 x265 libvpx aom dav1d rav1e svt-av1 libfdk-aac faad2 lame libmad opus flac mkvtoolnix-cli
)

fonts=(
    noto-fonts-cjk noto-fonts adobe-source-code-pro-fonts noto-fonts-emoji otf-font-awesome ttf-droid ttf-fira-code ttf-jetbrains-mono-nerd ttf-font-awesome ttf-cascadia-mono-nerd ttf-cascadia-code-nerd ttf-ms-fonts
)

terminals=(
    gnome-console ptyxis konsole alacritty ghostty kitty
)

#Desktop Environments

#Gnome
gnome_core=(
    gdm gnome-shell gnome-session gnome-settings-daemon xdg-desktop-portal-gnome gnome-menus xdg-user-dirs-gtk
)

gnome_config=(
    gnome-control-center gnome-tweaks adwaita-icon-theme gnome-themes-extra gnome-keyring
)

gnome_files=(
    nautilus nautilus-python gnome-disk-utility baobab
)

gnome_gvfs=(
    gvfs
)

gnome_apps=(
    gnome-text-editor papers loupe showtime decibels gnome-calculator mission-center fragments
)

gnome_extra=(
    extension-manager gapless gradia numix-folders-git numix-circle-icon-theme-git
)

gnome_gvfs_extra=(
    gvfs-afc gvfs-mtp gvfs-nfs gvfs-smb gvfs-wsdd gvfs-dnssd gvfs-gphoto2 gvfs-onedrive gvfs-goa
)

#KDE
kde_core=(
    plasma-desktop plasma-workspace systemsettings plasma-login-manager xdg-user-dirs xdg-desktop-portal-kde plasma-wayland-protocols
)

kde_visual=(
    breeze-icons kde-gtk-config kinfocenter kdeplasma-addons
)

kde_hardware=(
    plasma-nm plasma-pa powerdevil kscreen bluedevil kwalletmanager
)

kde_files=(
    dolphin dolphin-plugins ark partitionmanager filelight
)

kde_apps=(
    kate kcalc okular spectacle gwenview haruna elisa qbittorrent plasma-systemmonitor
)

#Drivers
base_drivers=(
    mesa mesa-utils
)

intel_drivers=(
    intel-media-driver libva-intel-driver vulkan-intel
)

amd_drivers=(
    libva-mesa-driver vulkan-radeon
)

nvidia_drivers=(
    nvidia-open-dkms
)

nvidia_common_utils=(
    nvidia-utils nvidia-prime nvidia-settings lib32-nvidia-utils lib32-opencl-nvidia opencl-nvidia libvdpau libxnvctrl vulkan-icd-loader lib32-vulkan-icd-loader egl-gbm egl-x11
)

#Other Apps
terminal_tools=(
    dysk tealdeer btop fastfetch bat fd eza fzf zoxide ripgrep yazi wl-clipboard resvg
)

browsers=(
    firefox brave-bin zen-browser-bin vivaldi google-chrome floorp librewolf chromium firedragon waterfox-bin qutebrowser
)

terminal_text_editors=(
    nano vim micro neovim
)

zsh_and_plugins=(
    zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions
)

wine_and_dependencies=(
    wine-staging winetricks giflib libpng libldap gnutls mpg123 openal v4l-utils libpulse alsa-plugins alsa-lib libjpeg-turbo libxcomposite libxinerama ncurses opencl-icd-loader libxslt libva gtk3 gst-plugins-base-libs vulkan-icd-loader
)

gaming=(
    heroic-games-launcher-bin mangohud vkd3d glfw mangojuice wqy-zenhei jdk21-openjdk steam
)

timeshift_config=(
    cronie timeshift 
)

extra=(
    upscayl-desktop-git parsec-bin
    obsidian pokemon-colorscripts-git gimp kdenlive
    audacity komikku raider bottles gearlever
    flatseal switcheroo spotify-launcher 
    obs-studio discord libreoffice-still
    octopi vscodium
)

grub_packages=(
    grub grub-btrfs os-prober inotify-tools update-grub
)

#Package management helpers

install_pacman() {
    sudo pacman -S --needed --noconfirm "$@"
}

install_yay() {
    yay -S --needed --noconfirm "$@"
}

install_flatpak() {
    flatpak install -y --noninteractive flathub "$@"
}

remove_pacman() {
    sudo pacman -R --noconfirm "$@"
}

remove_yay() {
    yay -R --noconfirm "$@"
}

remove_flatpak() {
    flatpak remove -y --noninteractive "$@"
}
