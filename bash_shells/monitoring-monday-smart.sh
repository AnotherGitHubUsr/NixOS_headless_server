#!/usr/bin/env bash
# ============================================
# monitoring-monday-smart.sh
# ============================================
# Every Monday 10:30: Wake all drives (including iSCSI if possible), run short SMART test, log to detritus,
# ClamAV: quick scan of high-risk files, output only infected.

set -euo pipefail
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/current-system/sw/bin:${PATH}"

LOGDIR="/detritus/monday-10-30"
mkdir -p "$LOGDIR"

# List all block devices, including iSCSI
ALL_BLOCKS=$(lsblk -dno NAME | grep -E '^(sd|nvme|vd|xvd|hd|sd[a-z]+|nvme[0-9]+n[0-9]+|vd[a-z]+|xvd[a-z]+|hd[a-z]+)')

for d in $ALL_BLOCKS; do
  DEV="/dev/$d"
  [ -b "$DEV" ] || continue
  hdparm -w "$DEV" || true
  sleep 3
  smartctl -t short "$DEV"
  echo "SMART short test triggered for $DEV at $(date)" >> "$LOGDIR/smart-monday.log"
  smartctl -a "$DEV" >> "$LOGDIR/smart-$d.log"
done

# ClamAV: quick scan of high-risk files
find / -type f \( -name '*.exe' -o -name '*.dll' -o -name '*.scr' -o -name '*.bat' -o -name '*.doc' -o -name '*.docx' -o -name '*.xls' -o -name '*.xlsx' -o -name '*.js' -o -name '*.ps1' \) 2>/dev/null | \
  xargs clamscan --infected --no-summary | tee -a "$LOGDIR/clamav-monday-infected.log"
