detect_gpus() {
    video_graphics=()

    local pci_info
    pci_info=$(lspci | grep -i "vga\|3d\|display")

    echo "$pci_info" | grep -qi "intel"                        && video_graphics+=("Intel")
    echo "$pci_info" | grep -qi "amd\|radeon\|advanced micro"  && video_graphics+=("AMD")
    echo "$pci_info" | grep -qi "nvidia"                       && video_graphics+=("Nvidia")

    if [[ ${#video_graphics[@]} -eq 0 ]]; then
        echo "WARNING: No GPU detected via lspci. Skipping driver installation."
    else
        echo "Detected GPU(s): ${video_graphics[*]}"
    fi
}

install_drivers() {
    detect_gpus
    [[ ${#video_graphics[@]} -eq 0 ]] && return 0

    echo "Installing drivers..."
    install_pacman "${base_drivers[@]}"

    for gpu in "${video_graphics[@]}"; do
        case $gpu in
            "Intel")
                echo "Installing Intel drivers..."
                install_pacman "${intel_drivers[@]}"
                ;;
            "AMD")
                echo "Installing AMD drivers..."
                install_pacman "${amd_drivers[@]}"
                ;;
            "Nvidia")
                echo "Installing Nvidia drivers..."
                install_pacman "${nvidia_drivers[@]}" "${nvidia_common_utils[@]}"
                nvidia_configure
                ;;
        esac
    done
}

nvidia_configure() {
    local conf_file="/etc/modprobe.d/nvidia.conf"
    local conf_line="options nvidia_drm modeset=1"

    if grep -qF "$conf_line" "$conf_file" 2>/dev/null; then
        echo "nvidia.conf already configured, skipping."
    else
        echo "$conf_line" | sudo tee -a "$conf_file" > /dev/null
        echo "nvidia.conf written."
    fi
}