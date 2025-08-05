{ config, pkgs, ... }:

let
  # Match your disk.nix layout:
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
    serviceConfig.ExecStart = pkgs.writeShellScript "hourlyChecks" ''
      set -e
      mkdir -p /mnt/data/logs
      for d in ${toString zfsHdds}; do
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
    '';
  };
  systemd.timers.hourlyChecks = {
    enable = true;
    timerConfig = { OnCalendar = "hourly"; Unit = "hourlyChecks.service"; };
  };

  # -------- Weekly SMART short test (all ZFS disks, wakes up if needed) --------
  # What this does: Runs SMART short self-test on all ZFS HDDs, waking up disks if spun down.
  systemd.services.smart-short = {
    description = "Weekly SMART short self-test for ZFS HDDs (wakes up disks)";
    serviceConfig.ExecStart = runForDisks zfsHdds "hdparm -w \$d; sleep 3; smartctl -t short \$d";
  };
  systemd.timers.smart-short = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 03:00"; Persistent = true; Unit = "smart-short.service"; };
  };

  # -------- bcachefs scrub/health check (bcachefs pool only) --------
  # What this does: Weekly full bcachefs scrub on /mnt/bcachefs, never on ZFS disks.
  systemd.services.bcachefs-scrub = {
    description = "bcachefs scrub (fsck --scrub) on /mnt/bcachefs only";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bcachefs-tools}/bin/bcachefs fsck --scrub /mnt/bcachefs";
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.bcachefs-scrub = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 02:15"; Persistent = true; Unit = "bcachefs-scrub.service"; };
  };

  # -------- ZFS scrub (hddpool only) --------
  # What this does: Weekly ZFS scrub of hddpool; bcachefs devices are never scrubbed with zpool.
  systemd.services.zfs-hdd-scrub = {
    description = "Weekly ZFS scrub of hddpool (Detritus/Bluejohn only)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = runForDisks zfsHdds "hdparm -w \$d; sleep 3"; # Wake disks
      ExecStartPost = "zpool scrub hddpool";                    # Run ZFS scrub
      Nice = 15;
      IOSchedulingClass = "idle";
    };
  };
  systemd.timers.zfs-hdd-scrub = {
    enable = true;
    timerConfig = { OnCalendar = "Sun 05:00"; Persistent = true; Unit = "zfs-hdd-scrub.service"; };
  };

  # -------- Weekly hardware/log/AV/firewall audit --------
  # What this does: Collects and archives logs, hardware errors, AV scan, and firewall state.
  systemd.services.weeklyHealth = {
    description = "Weekly hardware/log/AV/firewall audit";
    serviceConfig.ExecStart = pkgs.writeShellScript "weeklyHealth" ''
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
    '';
  };
  systemd.timers.weeklyHealth = {
    enable = true;
    timerConfig = { OnCalendar = "Mon 09:00"; Unit = "weeklyHealth.service"; };
  };

  # -------- Firewall rules test after reboot and every 50h --------
  # What this does: Dumps current iptables state to logs at boot and every 50 hours.
  systemd.services.firewall-check = {
    description = "Firewall rules check after reboot and every 50h";
    serviceConfig.ExecStart = pkgs.writeShellScript "firewall-check" ''
      mkdir -p /mnt/data/logs
      echo "===== $(date '+%F %T') =====" >> /mnt/data/logs/firewall.check
      iptables-save >> /mnt/data/logs/firewall.check
    '';
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
















































{
  # Bcache write-cache flush every 24h at 11am.
  # To change the schedule, adjust 'OnCalendar'.
  #   For weekly:    OnCalendar = "Sun 11:00";
  #   For bidaily:   OnCalendar = "Mon,Wed,Fri 11:00";
  systemd.timers.bcacheFlush = {
    enable = true;
    timerConfig = { OnCalendar = "11:00"; Unit = "bcacheFlush.service"; };
  };
  systemd.services.bcacheFlush = {
    description = "Flush bcache write cache daily at 11am";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash -c 'echo 1 > /sys/block/bcache*/bcache/flush_write_cache'";
  };

  # Bcache write cache flush if more than 100GB dirty data is in the cache.
  # what this does: Checks all bcache devices; if any have >100GB dirty data, flushes the write cache immediately.
  # This is triggered by a separate systemd timer below (default: checks every hour).
  systemd.timers.bcacheFlushOnThreshold = {
    enable = true;
    timerConfig = { OnUnitActiveSec = "1h"; Unit = "bcacheFlushOnThreshold.service"; };
  };
  systemd.services.bcacheFlushOnThreshold = {
    description = "Flush bcache write cache if dirty data exceeds 100GB";
    # The script parses 'dirty_data' for each bcache device and flushes if >100GB (107374182400 bytes)
    serviceConfig.ExecStart = pkgs.writeShellScript "bcache-flush-on-threshold.sh" ''
      # Find all bcache devices and check dirty_data
      for d in /sys/block/bcache*/bcache; do
        [ -d "$d" ] || continue
        dirty_bytes=$(cat "$d"/dirty_data 2>/dev/null | awk '{print $1}')
        # dirty_data may report in bytes (no suffix)
        if [ "$dirty_bytes" -ge 107374182400 ]; then
          echo "Flushing $d (dirty_data: $dirty_bytes bytes > 100GB)"
          echo 1 > "$d/flush_write_cache"
        fi
      done
    '';
  };
}


  # Firewall rules test after reboot and every 50h
  systemd.timers.firewallTest = {
    enable = true;
    timerConfig = { OnBootSec = "15min"; OnUnitActiveSec = "50h"; Unit = "firewallTest.service"; };
  };
  systemd.services.firewallTest = {
    description = "Test /30 subnet firewall rules";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash -c 'iptables -L | grep 10.250.250.249 | tee /mnt/data/logs/firewall_subnet.log'";
  };



  # (Commented) Notification bots (write your own and store tokens with agenix)
  # systemd.services.gotifyBot = {
  #   enable = false;
  #   script = "/usr/local/bin/gotify-bot.sh";
  #   wantedBy = [ "multi-user.target" ];
  # };
  # systemd.services.telegramBot = {
  #   enable = false;
  #   script = "/usr/local/bin/telegram-bot.sh";
  #   wantedBy = [ "multi-user.target" ];
  # };
}
