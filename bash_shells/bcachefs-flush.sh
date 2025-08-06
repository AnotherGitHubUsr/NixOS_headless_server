#!/usr/bin/env bash
# =============================================
# bcachefs-flush.sh
# =============================================
# --- FLUSHES ALL DIRTY WRITEBACK CACHE ---
# Called by: disk.nix (systemd.services.bcachefs-flush)
# Flushes bcachefs pool at /mnt/watch to persistent storage.
# -----------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

MOUNT="/mnt/watch"

if mountpoint -q "$MOUNT"; then
  bcachefs fsck --flush "$MOUNT"
else
  echo "ERROR: $MOUNT is not mounted; cannot flush."
  exit 1
fi
