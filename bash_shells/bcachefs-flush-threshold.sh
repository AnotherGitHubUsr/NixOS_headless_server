#!/usr/bin/env bash
# =============================================
# bcachefs-flush-threshold.sh
# =============================================
# --- FLUSH BCACHEFS WRITEBACK CACHE IF OVER 150 GiB ---
# Called by: disk.nix (systemd.services.bcachefs-flush-threshold)
# Checks dirty writeback size, flushes if over threshold.
# ------------------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin" # for NixOS system packages, including bcachefs-tools

# --- CONFIGURATION ---
MOUNT="/mnt/watch"  # bcachefs pool mountpoint

# --- CHECK DIRTY WRITEBACK BYTES ---
DIRTY_BYTES=$(cat /sys/fs/bcachefs/$(basename "$(findmnt -no SOURCE $MOUNT | cut -d':' -f1)")/writeback_dirty 2>/dev/null | awk '{print $1}')

LIMIT=$((150 * 1024 * 1024 * 1024))  # 150 GiB

if [ -z "${DIRTY_BYTES}" ]; then
  echo "Could not determine bcachefs dirty writeback size."
  exit 1
fi

if [ "${DIRTY_BYTES}" -ge "${LIMIT}" ]; then
  echo "bcachefs writeback cache is above 150 GiB (${DIRTY_BYTES} bytes); flushing..."
  bcachefs fsck --flush "${MOUNT}"
else
  echo "bcachefs writeback cache is below threshold."
fi
