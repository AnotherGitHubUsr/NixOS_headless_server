#!/usr/bin/env bash
# monitoring-smart-short.sh
# Weekly SMART short self-test for ZFS HDDs (wakes up disks)
for d in /dev/sdb; do
  [ -b "$d" ] || continue
  hdparm -w $d
  sleep 3
  smartctl -t short $d
done
