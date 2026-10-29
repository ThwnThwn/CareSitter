#!/bin/sh
set -eu

[ "$(id -u)" -eq 0 ] || {
    echo 'Run this script with sudo on the OCI Ubuntu host.' >&2
    exit 1
}

swap_file=${CARESITTER_SWAP_FILE:-/swapfile}
swap_size_mb=${CARESITTER_SWAP_SIZE_MB:-4096}
case "$swap_file" in
    /*) ;;
    *) echo 'CARESITTER_SWAP_FILE must be an absolute path.' >&2; exit 1 ;;
esac
case "$swap_size_mb" in
    ''|*[!0-9]*) echo 'CARESITTER_SWAP_SIZE_MB must be an integer.' >&2; exit 1 ;;
esac
[ "$swap_size_mb" -ge 2048 ] && [ "$swap_size_mb" -le 8192 ] || {
    echo 'CARESITTER_SWAP_SIZE_MB must stay between 2048 and 8192.' >&2
    exit 1
}

if swapon --noheadings --show=NAME | grep -Fx -- "$swap_file" >/dev/null 2>&1; then
    echo "Swap is already active at $swap_file."
else
    [ ! -L "$swap_file" ] || { echo "Refusing symlink swap path: $swap_file" >&2; exit 1; }
    if [ -e "$swap_file" ]; then
        echo "Refusing to overwrite existing inactive path: $swap_file" >&2
        exit 1
    fi
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l "${swap_size_mb}M" "$swap_file"
    else
        dd if=/dev/zero of="$swap_file" bs=1M count="$swap_size_mb" status=progress
    fi
    chmod 600 "$swap_file"
    mkswap "$swap_file" >/dev/null
    swapon "$swap_file"
fi

fstab_line="$swap_file none swap sw 0 0"
grep -Fqx -- "$fstab_line" /etc/fstab || printf '%s\n' "$fstab_line" >> /etc/fstab
printf '%s\n' 'vm.swappiness=10' 'vm.vfs_cache_pressure=50' > /etc/sysctl.d/99-caresitter-low-memory.conf
sysctl --system >/dev/null

echo 'Low-memory host swap is ready:'
free -h
