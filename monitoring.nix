{ config, pkgs, ... }:

let
  zfsHdds = [
    "/dev/sdb"     # Detritus: ZFS, part of hddpool
    # "/dev/sdc"   # Bluejohn: ZFS, add if/when present
    # "/dev/sdd"   # Carborundum: ZFS, add if/when present
  ];

  bcachefsDevices = [
    "/dev/nvme0n1" # Littlebottom, bcachefs
    "/dev/nvme1n1" # Carrot, bcachefs
    "/dev/nvme2n1" # Vimes, bcachefs
    "/dev/nvme3n1" # Angua, bcachefs
    # ...plus iSCSI disks (by-path), always as part of bcachefs pool
  ];

  # Function: run command only for a set of devices, with rationale
  runForDisks = disks: command: ''
    for d in ${toString disks}; do
      [ -b "$d" ] && ${command}
    done
  '';
in
{
  # -------- Hourly on-hours check for local ZFS disks only --------
  # What this does: Monitors power-on hours and triggers SMART/fsck/zpool scrub at intervals for ZFS pools only.
  systemd.services.hourlyChecks = {
    description = "Checks ZFS disk on-hours, triggers fsck/zpool scrub at thresholds (excluding iSCSI and bcachefs-only SSDs)";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-hourly-checks.sh";
  };
  systemd.timers.hourlyChecks = {
    enable = true;
    timerConfig = { OnCalendar = "hourly"; Unit = "hourlyChecks.service"; };
  };

  # -------- Weekly SMART short test (all ZFS disks, wakes up if needed) --------
  # What this does: Runs SMART short self-test on all ZFS HDDs, waking up disks if spun down.
  systemd.services.smart-short = {
    description = "Weekly SMART short self-test for ZFS HDDs (wakes up disks)";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-smart-short.sh";
  };
  systemd.timers.smart-short = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 03:00"; Persistent = true; Unit = "smart-short.service"; };
  };

  # -------- bcachefs scrub/health check (bcachefs pool only) --------
  # What this does: Weekly full bcachefs scrub on /mnt/bcachefs, never on ZFS disks.
  systemd.services.bcachefs-scrub = {
    description = "bcachefs scrub (fsck --scrub) on /mnt/bcachefs only";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-bcachefs-scrub.sh";
  };
  systemd.timers.bcachefs-scrub = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 02:15"; Persistent = true; Unit = "bcachefs-scrub.service"; };
  };

  # -------- ZFS scrub (hddpool only) --------
  # What this does: Weekly ZFS scrub of hddpool; bcachefs devices are never scrubbed with zpool.
  systemd.services.zfs-hdd-scrub = {
    description = "Weekly ZFS scrub of hddpool (Detritus/Bluejohn only)";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-zfs-hdd-scrub.sh";
  };
  systemd.timers.zfs-hdd-scrub = {
    enable = true;
    timerConfig = { OnCalendar = "Sun 05:00"; Persistent = true; Unit = "zfs-hdd-scrub.service"; };
  };

  # -------- Weekly hardware/log/AV/firewall audit --------
  # What this does: Collects and archives logs, hardware errors, AV scan, and firewall state.
  systemd.services.weeklyHealth = {
    description = "Weekly hardware/log/AV/firewall audit";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-weekly-health.sh";
  };
  systemd.timers.weeklyHealth = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 09:00"; Unit = "weeklyHealth.service"; };
  };

  # -------- Firewall rules test after reboot and every 50h --------
  # What this does: Dumps current iptables state to logs at boot and every 50 hours.
  systemd.services.firewall-check = {
    description = "Firewall rules check after reboot and every 50h";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-firewall-check.sh";
  };
  systemd.timers.firewall-check-boot = {
    enable = true;
    timerConfig = { OnBootSec = "5min"; Unit = "firewall-check.service"; };
  };
  systemd.timers.firewall-check-interval = {
    enable = true;
    timerConfig = { OnUnitActiveSec = "50h"; Unit = "firewall-check.service"; };
  };
}
