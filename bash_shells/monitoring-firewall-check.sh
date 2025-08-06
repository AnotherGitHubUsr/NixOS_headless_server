#!/usr/bin/env bash
# =============================================
# monitoring-firewall-check.sh
# =============================================
# --- DUMP IPTABLES STATE AT BOOT & EVERY 50H ---
# Called by: monitoring.nix (systemd.services.firewall-check)
# Logs firewall state to persistent log file.
# --------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

mkdir -p /mnt/data/logs
echo "===== $(date '+%F %T') =====" >> /mnt/data/logs/firewall.check
iptables-save >> /mnt/data/logs/firewall.check
