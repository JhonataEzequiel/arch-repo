configure_swap() {
    local target_size="8g"
    local swap_subvol_mount="/swap"
    local swapfile="${swap_subvol_mount}/swapfile"

    # Check if there's already an active swapfile
    local existing
    existing=$(swapon --show=NAME --noheadings 2>/dev/null | grep -v zram | head -n1)

    if [[ -n "$existing" ]]; then
        local current_size_bytes
        current_size_bytes=$(swapon --show=SIZE --noheadings --bytes 2>/dev/null | grep -v zram | head -n1)
        local target_bytes=$(( 8 * 1024 * 1024 * 1024 ))

        if [[ "$current_size_bytes" -eq "$target_bytes" ]]; then
            echo "Swap already configured at 8G (${existing}). Nothing to do."
            return 0
        fi

        echo "Existing swap detected at ${existing} ($(( current_size_bytes / 1024 / 1024 ))MB). Recreating at 8G..."
        sudo swapoff "$existing"
        sudo rm -f "$existing"

        # Remove old fstab entry to avoid duplicates
        sudo sed -i "\|${existing}|d" /etc/fstab
    fi

    # The @swap subvolume must already exist and be mounted at /swap.
    # This is expected from the base Arch btrfs install layout.
    # If it is not mounted, we attempt to find and mount it.
    if ! mountpoint -q "$swap_subvol_mount"; then
        echo "WARNING: ${swap_subvol_mount} is not mounted."
        echo "Looking for an @swap btrfs subvolume to mount..."

        local root_dev
        root_dev=$(findmnt -n -o SOURCE /)

        if sudo btrfs subvolume list / 2>/dev/null | grep -q "@swap"; then
            sudo mkdir -p "$swap_subvol_mount"
            sudo mount -o subvol=@swap "$root_dev" "$swap_subvol_mount"
            echo "Mounted @swap subvolume at ${swap_subvol_mount}."

            # Persist the mount in fstab if not already there
            if ! grep -q "@swap" /etc/fstab; then
                local root_uuid
                root_uuid=$(findmnt -n -o UUID /)
                echo "UUID=${root_uuid} ${swap_subvol_mount} btrfs subvol=@swap,nodatacow,nodatasum 0 0" \
                    | sudo tee -a /etc/fstab > /dev/null
                echo "Added @swap mount to /etc/fstab."
            fi
        else
            echo "ERROR: No @swap btrfs subvolume found."
            echo "Please create one manually with: btrfs subvolume create @swap"
            echo "Then mount it at ${swap_subvol_mount} and re-run."
            return 1
        fi
    fi

    echo "Creating btrfs swapfile at ${swapfile} (${target_size})..."
    sudo btrfs filesystem mkswapfile --size "$target_size" "$swapfile"
    sudo swapon "$swapfile"

    if ! grep -qF "$swapfile" /etc/fstab; then
        echo "${swapfile} none swap defaults,pri=10 0 0" | sudo tee -a /etc/fstab > /dev/null
        echo "Added ${swapfile} to /etc/fstab."
    fi

    echo "Swap configured successfully."
}

configure_zram() {
    echo "Configuring zram..."
    install_pacman zram-generator

    local total_ram_kb
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_ram_gb=$(( total_ram_kb / 1024 / 1024 ))

    # Use half of total RAM for zram, capped at 8G
    local zram_size
    if [[ $total_ram_gb -le 4 ]]; then
        zram_size="${total_ram_gb}G"
    elif [[ $total_ram_gb -le 16 ]]; then
        zram_size="$(( total_ram_gb / 2 ))G"
    else
        zram_size="8G"
    fi

    echo "Detected ${total_ram_gb}GB RAM. Setting zram size to ${zram_size}."

    sudo mkdir -p /etc/systemd/zram-generator.conf.d
    sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ${zram_size}
compression-algorithm = zstd
swap-priority = 100
EOF

    sudo systemctl daemon-reload
    sudo systemctl start systemd-zram-setup@zram0.service

    if swapon --show | grep -q zram; then
        echo "zram configured and active (size: ${zram_size}, priority: 100)."
    else
        echo "WARNING: zram device may not have activated. Check: swapon --show"
    fi
}

ram_setup() {
    local do_swap=false
    local do_zram=false

    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare ram_choice
        single_select ram_choice "How do you want to configure RAM/swap?" \
            "zram only" \
            "Swap file only (8GB)" \
            "Both zram + swap file (8GB)" \
            "Skip"

        case "$ram_choice" in
            "zram only")               do_zram=true ;;
            "Swap file only (8GB)")    do_swap=true ;;
            "Both zram + swap file (8GB)") do_zram=true; do_swap=true ;;
            "Skip") echo "Skipping RAM/swap configuration."; return 0 ;;
        esac
    else
        do_zram=true
        do_swap=true
    fi

    if [[ "$do_swap" == true ]]; then
        configure_swap
    fi

    if [[ "$do_zram" == true ]]; then
        configure_zram
    fi

    # swappiness: zram alone benefits from a higher value (kernel uses compressed RAM freely);
    # swap-only or both benefit from a low value (avoid disk I/O until necessary).
    local swappiness_value=10
    [[ "$do_zram" == true && "$do_swap" == false ]] && swappiness_value=60
    echo "vm.swappiness=${swappiness_value}" | sudo tee /etc/sysctl.d/99-swap.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-swap.conf

    echo "RAM configuration complete."
    echo "Current swap devices:"
    swapon --show
}
