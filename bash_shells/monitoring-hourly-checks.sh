#!/usr/bin/env bash
# monitoring-hourly-checks.sh
# Runs ZFS disk checks and triggers fsck/zpool scrub at intervals for ZFS pools only.
set -e
mkdir -p /mnt/data/logs
for d in /dev/sdb; do  # Extend this list as needed to match your ZFS HDDs.
  [ -b "$d" ] || continue
  NAME=$(basename $d)
  HOURS=$(smartctl -A $d | awk "/Power_On_Hours/ {print \$10}")
  BASEFILE="/mnt/data/logs/${NAME}_base_hours"
  BASE=$(cat "$BASEFILE" 2>/dev/null || echo $HOURS)
  DELTA=$(($HOURS - $BASE))
  if [ $((DELTA % 1000)) -eq 0 ]; then zpool scrub hddpool; fi
  if [ $((DELTA % 2000)) -eq 0 ]; then hdparm -w $d; sleep 3; smartctl -t long $d; fi
  echo $BASE > "$BASEFILE"
done
