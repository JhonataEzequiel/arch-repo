configure_swap() {
    local target_size="8g"
    local swap_subvol_mount="/swap"
    local swapfile="${swap_subvol_mount}/swapfile"

    # Check if there's already an active swapfile
    # NOTE: `grep -v zram` returns exit status 1 when there is no non-zram
    # swap active (e.g. on a fresh install). With `pipefail` that failure
    # propagates out of the pipeline, and with `set -e` it kills the whole
    # script right here - before this function prints anything. `|| true`
    # keeps "no match" from being treated as an error.
    local existing
    existing=$(swapon --show=NAME --noheadings 2>/dev/null | grep -v zram | head -n1 || true)

    if [[ -n "$existing" ]]; then
        local current_size_bytes
        current_size_bytes=$(swapon --show=SIZE --noheadings --bytes 2>/dev/null | grep -v zram | head -n1 || true)
        local target_bytes=$(( 8 * 1024 * 1024 * 1024 ))

        if [[ "$current_size_bytes" -eq "$target_bytes" ]]; then
            echo "Swap already configured at 8G (${existing}). Nothing to do."
            return 0
        fi

        echo "Existing swap detected at ${existing} ($(( current_size_bytes / 1024 / 1024 ))MB). Recreating at 8G..."
        sudo swapoff "$existing"

        # Only remove the underlying path if it is actually a regular file.
        # If the existing swap lives on a partition (e.g. /dev/sdaX or a
        # block device under /dev/mapper), never rm it - that would delete
        # a device node, not swap data.
        if [[ -f "$existing" ]]; then
            sudo rm -f "$existing"
        else
            echo "NOTE: ${existing} appears to be a block device, not a file. Leaving it untouched; only disabling it as swap."
        fi

        # Remove old fstab entry to avoid duplicates
        sudo sed -i "\|${existing}|d" /etc/fstab
    fi

    # Not every install has an @swap subvolume out of the box - the
    # archinstall default layout only creates @, @home, @var and @log.
    # If it's missing, we create it ourselves instead of bailing out.
    # If it is not mounted, we attempt to find/create and mount it.
    if ! mountpoint -q "$swap_subvol_mount"; then
        echo "WARNING: ${swap_subvol_mount} is not mounted."

        # findmnt on a mounted subvolume prints something like
        # "/dev/nvme0n1p2[/@]" - strip the "[/@]" part to get the raw
        # block device, since that's what we need to mount subvolid=5.
        local root_dev_raw root_dev
        root_dev_raw=$(findmnt -n -o SOURCE /)
        root_dev="${root_dev_raw%%\[*}"

        if ! sudo btrfs subvolume list / 2>/dev/null | grep -q "@swap"; then
            echo "No @swap btrfs subvolume found. Creating one..."

            # @ and its siblings (@home, @var, @log) live under the
            # filesystem's top-level subvolume (subvolid=5), which isn't
            # reachable from inside / (mounted as @). Mount it temporarily
            # to create @swap alongside them.
            local tmp_mount
            tmp_mount=$(mktemp -d)
            sudo mount -o subvolid=5 "$root_dev" "$tmp_mount"
            sudo btrfs subvolume create "${tmp_mount}/@swap"
            sudo umount "$tmp_mount"
            rmdir "$tmp_mount"
            echo "@swap subvolume created."
        fi

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

    # Use half of total RAM for zram, capped at 8G.
    # IMPORTANT: zram-generator.conf's zram-size is a numeric expression in
    # MB (it's evaluated with a variable called `ram`, e.g. "ram / 2" or
    # "min(ram / 2, 4096)") - it does NOT accept human-readable suffixes
    # like "7G". Writing "7G" makes the generator's parser fail, causing
    # systemd-zram-setup@zram0.service to error out with "control process
    # exited with error code".
    local zram_size_mb
    if [[ $total_ram_gb -le 4 ]]; then
        zram_size_mb=$(( total_ram_gb * 1024 ))
    elif [[ $total_ram_gb -le 16 ]]; then
        zram_size_mb=$(( (total_ram_gb / 2) * 1024 ))
    else
        zram_size_mb=8192
    fi

    echo "Detected ${total_ram_gb}GB RAM. Setting zram size to ${zram_size_mb}MB."

    sudo tee /etc/systemd/zram-generator.conf > /dev/null <<EOF
[zram0]
zram-size = ${zram_size_mb}
compression-algorithm = zstd
swap-priority = 100
EOF

    sudo systemctl daemon-reload
    # Use restart instead of start so a re-run picks up a changed zram size
    # even if the service is already active from a previous run.
    sudo systemctl restart systemd-zram-setup@zram0.service

    if swapon --show | grep -q zram; then
        echo "zram configured and active (size: ${zram_size_mb}MB, priority: 100)."
    else
        echo "WARNING: zram device may not have activated. Check: swapon --show"
    fi
}

ram_setup() {
    local do_swap=false
    local do_zram=false

    if [[ "${choices[chosen_mode]}" == "Manual" ]]; then
        declare ram_choice
        single_select ram_choice "Do you want to apply Zram + Swap?" "Yes" "No"

        case "$ram_choice" in
            "Yes") do_zram=true; do_swap=true ;;
            "No")  echo "Skipping RAM/swap configuration."; return 0 ;;
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

    # swappiness: low value since we always pair zram with a disk-backed
    # swap file here, so we want to avoid disk I/O until necessary.
    local swappiness_value=10
    echo "vm.swappiness=${swappiness_value}" | sudo tee /etc/sysctl.d/99-swap.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-swap.conf

    echo "RAM configuration complete."
    echo "Current swap devices:"
    swapon --show
}
