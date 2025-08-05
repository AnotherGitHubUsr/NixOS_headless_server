#!/usr/bin/env bash
# monitoring-weekly-health.sh
# Collects logs, hardware errors, AV scan, and firewall state
set -e
mkdir -p /mnt/data/logs
DATE="===== $(date '+%F %T') ====="

echo "$DATE" >> /mnt/data/logs/dmesg.weekly
dmesg >> /mnt/data/logs/dmesg.weekly

echo "$DATE" >> /mnt/data/logs/lmsensors.weekly
sensors >> /mnt/data/logs/lmsensors.weekly

echo "$DATE" >> /mnt/data/logs/journal.errors
journalctl --since "-1w" | grep -i error >> /mnt/data/logs/journal.errors

echo "$DATE" >> /mnt/data/logs/clamscan.weekly
clamscan -r / >> /mnt/data/logs/clamscan.weekly

echo "$DATE" >> /mnt/data/logs/auth.fail
grep -i fail /var/log/auth.log >> /mnt/data/logs/auth.fail

echo "$DATE" >> /mnt/data/logs/firewall.weekly
iptables-save >> /mnt/data/logs/firewall.weekly

echo "$DATE" >> /mnt/data/logs/logsizes.weekly
ls -lh /mnt/data/logs >> /mnt/data/logs/logsizes.weekly
