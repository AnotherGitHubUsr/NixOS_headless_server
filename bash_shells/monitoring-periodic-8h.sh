#!/usr/bin/env bash
# ============================================
# monitoring-periodic-8h.sh
# ============================================
# Every 8 hours: Wake up detritus, update AV/crowdsec, append smart/sensors/journal/firewall/logsize to detritus (human readable).
# (No other disks are woken up.)

set -euo pipefail
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/current-system/sw/bin:${PATH}"

LOGDIR="/detritus/periodic-8h"
mkdir -p "$LOGDIR"

# Wake up detritus
hdparm -w /dev/disk/by-label/detritus || true

# Update clamav and crowdsec databases
freshclam | tee -a "$LOGDIR/clamav-update.log"
systemctl reload crowdsec || true
echo "Crowdsec DB updated $(date)" >> "$LOGDIR/crowdsec-update.log"

# Smart health check for detritus
smartctl -a /dev/disk/by-label/detritus | tee -a "$LOGDIR/detritus-smart.log"

# Sensors
echo "===== $(date '+%F %T') =====" >> "$LOGDIR/lmsensors.log"
sensors >> "$LOGDIR/lmsensors.log"

# Journal errors (since last 8h)
echo "===== $(date '+%F %T') =====" >> "$LOGDIR/journal-errors.log"
journalctl --since "-8h" | grep -i error >> "$LOGDIR/journal-errors.log"

# Firewall state
echo "===== $(date '+%F %T') =====" >> "$LOGDIR/firewall.log"
iptables-save >> "$LOGDIR/firewall.log"

# Log sizes
echo "===== $(date '+%F %T') =====" >> "$LOGDIR/logsizes.log"
ls -lh "$LOGDIR" >> "$LOGDIR/logsizes.log"
