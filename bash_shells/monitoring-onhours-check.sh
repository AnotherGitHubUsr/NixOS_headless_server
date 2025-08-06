#!/usr/bin/env bash
# ============================================
# monitoring-onhours-check.sh
# ============================================
# Tracks "on-hours" for weatherwax, triggers full fsck/scrub/clamav scan (every 950h) and staggered SMART long test (every 2000h)
# Persists "base" file, which is git-tracked and only created if not present.

set -euo pipefail
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/current-system/sw/bin:${PATH}"

ROOTDEV="/dev/disk/by-label/weatherwax"
BASEFILE="/etc/nixos/onhours-base.txt"
STATEFILE="/etc/nixos/onhours-state.txt"
LOGDIR="/detritus/onhours-logs"
mkdir -p "$LOGDIR"

# Only create base file if it does NOT exist (persistent)
if [ ! -f "$BASEFILE" ]; then
  HOURS=$(smartctl -A "$ROOTDEV" | awk '/Power_On_Hours/ {print $10}')
  echo "$HOURS" > "$BASEFILE"
  git add "$BASEFILE"
  git commit -m "Set on-hours base at first boot: $HOURS"
fi

BASE=$(cat "$BASEFILE")
CUR=$(smartctl -A "$ROOTDEV" | awk '/Power_On_Hours/ {print $10}')
DELTA=$((CUR - BASE))

echo "On-hours since setup: $DELTA" > "$STATEFILE"
date >> "$STATEFILE"

# --- 950h: fsck/scrub all, full clamav scan ---
if (( DELTA > 0 && DELTA % 950 == 0 )); then
  echo "Triggering 950h maintenance..." >> "$STATEFILE"
  for d in /dev/disk/by-label/*; do
    if [ -b "$d" ]; then
      FSTYPE=$(lsblk -ndo FSTYPE "$d" | head -n1)
      case "$FSTYPE" in
        ext4) echo "Running fsck on $d" | tee -a "$STATEFILE"; fsck -n "$d" | tee -a "$LOGDIR/fsck-$(basename "$d").log" ;;
        xfs)  echo "Running xfs_repair on $d" | tee -a "$STATEFILE"; xfs_repair -n "$d" | tee -a "$LOGDIR/xfs-$(basename "$d").log" ;;
        zfs)  echo "Running zpool scrub on $d" | tee -a "$STATEFILE"; zpool scrub "$(basename "$d")" | tee -a "$LOGDIR/zfs-$(basename "$d").log" ;;
        bcachefs) echo "Running bcachefs fsck on $d" | tee -a "$STATEFILE"; bcachefs fsck "$d" | tee -a "$LOGDIR/bcachefs-$(basename "$d").log" ;;
        *) echo "Unknown FS $FSTYPE for $d, skipping" ;;
      esac
    fi
  done
  echo "Running full ClamAV scan of all partitions..." | tee -a "$STATEFILE"
  clamscan -r --bell --log="$LOGDIR/clamav-full-$(date +%s).log" /
fi

# --- 2000h: staggered SMART long test (all local, non-iscsi) ---
if (( DELTA > 0 && DELTA % 2000 == 0 )); then
  echo "Triggering 2000h long SMART test on all local non-iscsi drives..." >> "$STATEFILE"
  for d in /dev/sd* /dev/nvme*; do
    if [ -b "$d" ]; then
      udevadm info --query=property --name="$d" | grep -q ID_BUS=iscsi && continue
      echo "Starting long SMART test on $d" | tee -a "$STATEFILE"
      smartctl -t long "$d"
      sleep 120 # stagger start by 2 min per disk
    fi
  done
fi

# Save a human-readable summary
echo "Current: $CUR, Base: $BASE, Delta: $DELTA" > "$LOGDIR/summary.txt"
date >> "$LOGDIR/summary.txt"
