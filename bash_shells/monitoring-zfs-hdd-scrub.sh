#!/usr/bin/env bash
# monitoring-zfs-hdd-scrub.sh
# Weekly ZFS scrub: wakes up disks, then runs zpool scrub
for d in /dev/sdb; do
  [ -b "$d" ] || continue
  hdparm -w $d
  sleep 3
done
zpool scrub hddpool
