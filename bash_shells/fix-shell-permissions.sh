#!/usr/bin/env bash
# =============================================
# fix-shell-permissions.sh
# =============================================
# --- FIX PERMISSIONS ON ALL SHELL SCRIPTS ---
# Called by: configuration.nix (activation script)
# Ensures root ownership, correct exec bits, and world-readable index.
# --------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

sudo chown -R root:root /etc/nixos/bash_shells
sudo chmod 755 /etc/nixos/bash_shells
sudo chmod 750 /etc/nixos/bash_shells/*.sh
sudo chmod 644 /etc/nixos/bash_shells/shell-index.txt

# makes root owner, executable for root, readable for non root-group
