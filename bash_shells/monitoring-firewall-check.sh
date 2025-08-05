#!/usr/bin/env bash
# monitoring-firewall-check.sh
# Dumps current iptables state to logs at boot and every 50 hours.
mkdir -p /mnt/data/logs
echo "===== $(date '+%F %T') =====" >> /mnt/data/logs/firewall.check
iptables-save >> /mnt/data/logs/firewall.check
