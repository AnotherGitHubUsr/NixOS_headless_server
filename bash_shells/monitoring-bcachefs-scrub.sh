#!/usr/bin/env bash
# =============================================
# monitoring-bcachefs-scrub.sh
# =============================================
# --- WEEKLY BCACHEFS SCRUB ---
# Called by: monitoring.nix (systemd.services.bcachefs-scrub)
# Runs fsck --scrub on /mnt/watch bcachefs pool.
# --------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

bcachefs fsck --scrub /mnt/watch
