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

    sof_firmware_setup
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

    nvidia_early_kms_setup
}

sof_firmware_setup() {
    local needs_sof=false
    local reasons=()

    if lspci | grep -qi "multimedia audio\|audio device\|signal processing"; then
        local audio_pci
        audio_pci=$(lspci | grep -i "multimedia audio\|audio device\|signal processing")
        if echo "$audio_pci" | grep -qi "intel"; then
            needs_sof=true
            reasons+=("Intel audio DSP detectado via lspci")
        fi
    fi

    if dmesg 2>/dev/null | grep -qi "sof\|sound open firmware\|failed to load.*firmware"; then
        needs_sof=true
        reasons+=("Firmware de áudio ausente detectado no dmesg")
    fi

    if [[ -d /proc/asound ]]; then
        if grep -rqi "HDA-Intel\|sof\|skl\|apl\|kbl\|cfl\|cnl\|cml\|tgl\|adl\|rpl\|mtl\|lnl" \
            /proc/asound/*/codec* 2>/dev/null || \
           grep -rqi "tgl\|adl\|rpl\|mtl\|lnl\|skl\|kbl\|cml" \
            /proc/asound/*/id 2>/dev/null; then
            needs_sof=true
            reasons+=("Codec HDA Intel compatível com SOF detectado em /proc/asound")
        fi
    fi

    if lsmod | grep -qi "^snd_sof\|^snd_hda_intel\|^snd_soc"; then
        needs_sof=true
        reasons+=("Módulo de áudio SOF/HDA Intel ativo no kernel")
    fi

    if [[ "$needs_sof" == true ]]; then
        echo "sof-firmware pode ser necessário neste hardware:"
        for reason in "${reasons[@]}"; do
            echo "  - $reason"
        done
        echo "Instalando sof-firmware..."
        install_pacman sof-firmware
    else
        echo "sof-firmware não é necessário para este hardware. Pulando."
    fi
}

nvidia_early_kms_setup() {
    local MKINITCPIO_CONF="/etc/mkinitcpio.conf"

    local nvidia_modules=("nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm")

    local current_modules
    current_modules=$(grep -oP '(?<=^MODULES=\()[^)]*' "$MKINITCPIO_CONF")

    local modules_to_add=()
    for mod in "${nvidia_modules[@]}"; do
        if [[ ! " $current_modules " =~ " $mod " ]]; then
            modules_to_add+=("$mod")
        fi
    done

    if [[ ${#modules_to_add[@]} -eq 0 ]]; then
        echo "Early KMS da NVIDIA já configurado no mkinitcpio. Pulando."
        return 0
    fi

    local new_modules="${current_modules} ${modules_to_add[*]}"
    new_modules="${new_modules# }"

    sudo sed -i "s|^MODULES=([^)]*)|MODULES=($new_modules)|" "$MKINITCPIO_CONF"
    echo "Módulos NVIDIA adicionados ao mkinitcpio: ${modules_to_add[*]}"

    echo "Regenerando initramfs..."
    sudo mkinitcpio -P
    echo "Initramfs regenerado com sucesso."
}