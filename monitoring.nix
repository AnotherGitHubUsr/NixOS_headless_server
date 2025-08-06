# =========================
# monitoring.nix
# =========================
# --- MONITORING: SMART, HEALTH, SENSORS, LOGGING, AV ---
# See each timer/service section for detailed job description.
# -------------------------------------------

{ config, pkgs, ... }:

let
  # Devices (for scripts to use)
  rootDevice = "/dev/disk/by-label/weatherwax"; # system SSD
  detritusDevice = "/dev/disk/by-label/detritus"; # main ZFS storage
  # Add further device labels if needed

in
{
  # --- SYSTEM ON-HOURS TRACKING (WEATHERWAX) ---
  # - Tracks total "on hours" since setup (persistent, git-tracked)
  # - 950h: triggers fsck/scrub/clamav full scan
  # - 2000h: triggers staggered long SMART test (all local, non-iscsi)
  # - Writes state/logs to detritus

  systemd.services.weatherwax-onhours-check = {
    description = "Track on-hours for weatherwax SSD, trigger periodic full checks";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-onhours-check.sh";
  };
  systemd.timers.weatherwax-onhours-check = {
    enable = true;
    timerConfig = {
      OnCalendar = "hourly";
      Unit = "weatherwax-onhours-check.service";
    };
  };

  # --- 8-HOURLY HEALTH/SENSOR/SMART/AV LOGGING (DETRITUS ONLY) ---
  systemd.services.periodic-health-logs = {
    description = "Every 8h: wake detritus, update AV, crowdsec, log smart/sensors/journal/firewall/logsize to detritus";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-periodic-8h.sh";
  };
  systemd.timers.periodic-health-logs = {
    enable = true;
    timerConfig = {
      OnCalendar = "0/8:00";
      Unit = "periodic-health-logs.service";
    };
  };

  # --- MONDAY 10:30 AM: SMART SHORT TEST ALL DRIVES ---
  systemd.services.smart-monday-all = {
    description = "Every Monday 10:30: wake all drives, run short SMART, log to detritus, clamav quick scan";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/monitoring-monday-smart.sh";
  };
  systemd.timers.smart-monday-all = {
    enable = true;
    timerConfig = {
      OnCalendar = "Mon 10:30";
      Unit = "smart-monday-all.service";
    };
  };

}
