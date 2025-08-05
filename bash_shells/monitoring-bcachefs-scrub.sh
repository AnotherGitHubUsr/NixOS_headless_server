#!/usr/bin/env bash
# monitoring-bcachefs-scrub.sh
# Weekly bcachefs fsck scrub on /mnt/bcachefs
${pkgs.bcachefs-tools}/bin/bcachefs fsck --scrub /mnt/bcachefs
