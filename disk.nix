{ config, pkgs, ... }:

let
  # --- Disk naming for safety, expansion, and documentation ---
  ssdDiskNames = [
    "Weatherwax"    # /dev/sda, system SSD, root
    "Littlebottom"  # /dev/nvme0n1, SSD, bcachefs cache
    "Carrot"        # /dev/nvme1n1, SSD, bcachefs cache (also used for metadata/journal)
    "Vimes"         # /dev/nvme2n1, SSD, bcachefs cache
    "Angua"         # /dev/nvme3n1, SSD, bcachefs cache
  ];
  hddDiskNames = [
    "Detritus"      # /dev/sdb, XFS only (was ZFS)
    # "Bluejohn"    # /dev/sdc, (optional XFS future, was ZFS)
    # "Carborundum" # /dev/sdd, (optional XFS future, was ZFS)
  ];
  futureDiskNames = [
    "Glod" "Gaspode" "Dibbler" "Twoflower" "Rincewind"
    "Cohen" "Susan" "Luggage" "Teatime" "VonLipwig"
    "Otto" "William" "Nobby" "Sybil" "Ridcully" "Ponder"
    "Librarian" "Magrat" "Nanny" "Carborundum" "Bluejohn" "Brick"
    "Lu-Tze" "Igor" "MrsCake" "Vetinary" "Drumknott"
    "LadySybil" "AdoraBelle" "Sally" "MissDearheart"
    "LordVetinary" "Colon" "RobbAnybody" "Cripslock" "DeWorde"
  ];
  allDiscworldDiskNames = ssdDiskNames ++ hddDiskNames ++ futureDiskNames;
in
{
  # --- Disk layout for system and expansion ---
  disko = {
    devices = {
      disk = {
        Weatherwax = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = [
              {
                name = "boot";
                start = "1MiB";
                end = "512MiB";
                type = "ef00"; # UEFI boot partition
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  # add options = [ ... ] if needed
                };
              }
              {
                name = "root";
                start = "512MiB";
                end = "100%";
                type = "8300"; # Linux root
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                  options = [ "noatime" ];
                };
              }
              # Example new swap partition (commented out, enable as needed)
              #{
              #  name = "swap";
              #  start = "100%";
              #  end = "120%"; # Adjust size as desired
              #  type = "8200";
              #  content = {
              #    type = "swap";
              #    randomEncryption = false;
              #  };
              #}
            ];
          };
        };
        Detritus = {
          device = "/dev/sdb";
          type = "disk";
          content = {
            type = "gpt";
            partitions = [
              {
                name = "data";
                start = "1MiB";
                end = "100%";
                type = "8300"; # XFS data partition (was ZFS)
                content = {
                  type = "filesystem";
                  format = "xfs";
                  mountpoint = "/mnt/detritus";
                  options = [ "noatime" ];
                };
              }
            ];
          };
        };
        # Future XFS expansion drives (add here as needed):
        # Bluejohn = { ... };
        # Carborundum = { ... };
        Littlebottom = { device = "/dev/nvme0n1"; type = "disk"; };
        Carrot       = { device = "/dev/nvme1n1"; type = "disk"; };
        Vimes        = { device = "/dev/nvme2n1"; type = "disk"; };
        Angua        = { device = "/dev/nvme3n1"; type = "disk"; };
      };
    };
  };

  # --- iSCSI configuration for NAS block devices ---
  # What this does: Connects at boot, handles multipath and timeouts for reliability.
  services.open-iscsi = {
    enable = true;
    initiatorName = "iqn.2024-08.nixserver:iscsi";
    portals = [ "10.250.250.250" ];
    autoLogin = true;
    extraConfig = ''
      node.startup = automatic
      node.session.timeo.replacement_timeout = 180
      node.session.initial_login_retry_max = 20
      node.session.auth.authmethod = CHAP
      node.conn[0].timeo.noop_out_interval = 10
      node.conn[0].timeo.noop_out_timeout = 120
      node.session.nr_sessions = 2
    '';
  };

  # --- bcachefs media pool ---
  # What this does: SSDs and iSCSI HDDs form a unified bcachefs pool. Writeback cache set to 200 GiB.
  # Write cache is flushed to disk daily at 11am, or if >80% full.
  fileSystems."/mnt/bcachefs" = {
    # Below, change the name/ip/path to the iSCSI devices as needed
    device = "/dev/nvme0n1:/dev/nvme1n1:/dev/nvme2n1:/dev/nvme3n1:/dev/disk/by-path/ip-10.250.250.250:iscsi-0-0-0-0-lun-0:/dev/disk/by-path/ip-10.250.250.250:iscsi-0-0-0-1-lun-0";
    fsType = "bcachefs";
    options = [
      "discard=async"                   # Enable async TRIM for SSDs.
      "foreground_target=/dev/nvme1n1"  # Use Carrot for metadata/journal for fast recovery.
      # "background_promote"             # Optionally prefill SSD cache with hot data.
      "writeback"                       # Enable write cache for performance.
      "writeback_max_size=214748364800" # Limit writeback cache to 200 GiB.
      "errors=remount-ro"               # Remount as read-only on error for safety.
      "recovery_readonly"               # Try mounting read-only after failure.
      # "compression=zstd"               # Not needed for media files.
      "readahead=16384"                 # 8 MiB readahead for optimal large file streaming.
    ];
  };

  # --- bcachefs flush automation ---
  # Flush all cached writes at 11am daily to reduce data loss risk.
  systemd.services.bcachefs-flush = {
    description = "Flush bcachefs write cache to disk";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/bcachefs-flush.sh";
    };
  };
  systemd.timers.bcachefs-flush = {
    enable = true;
    timerConfig = {
      OnCalendar = "11:00";
      Persistent = true;
      Unit = "bcachefs-flush.service";
    };
  };

  # Flush if writeback cache is >80% full. Checks every 15 minutes.
  systemd.services.bcachefs-flush-threshold = {
    description = "Flush bcachefs write cache if above 80% full";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/bcachefs-flush-threshold.sh";
    };
  };
  systemd.timers.bcachefs-flush-threshold = {
    enable = true;
    timerConfig = {
      OnCalendar = "*/15:00";
      Persistent = true;
      Unit = "bcachefs-flush-threshold.service";
    };
  };

  # --- Discworld disk name enforcement for disko safety ---
  # What this does: Prevents accidental formatting of disks without Discworld names.
  system.activationScripts."00-check-discworld-disknames" = ''
    ${pkgs.bash}/bin/bash /etc/nixos/bash_shells/check-discworld-disknames.sh
  '';

  # --- Storage map generation for operator visibility ---
  # What this does: Documents device, label, size, FS, UUIDs/partuuids for all known block devices.
  system.activationScripts."01-generate-storage-map" = ''
    (
      echo "# Dynamic Disk Map (auto-generated)"
      echo "# Device   Label         Size      FSType    UUID                                 PARTUUID"
      for dev in /dev/sd* /dev/nvme* /dev/disk/by-path/ip-*; do
        [ -b "$dev" ] || continue
        label=$(lsblk -ndo LABEL "$dev" | head -n1)
        size=$(lsblk -ndo SIZE "$dev" | head -n1)
        fstype=$(lsblk -ndo FSTYPE "$dev" | head -n1)
        uuid=$(blkid -s UUID -o value "$dev" 2>/dev/null || echo "-")
        partuuid=$(blkid -s PARTUUID -o value "$dev" 2>/dev/null || echo "-")
        printf "%-50s %-13s %-9s %-8s %-36s %-36s\n" "$dev" "$label" "$size" "$fstype" "$uuid" "$partuuid"
        for part in $(lsblk -lnpo NAME "$dev" | tail -n +2); do
          label=$(lsblk -ndo LABEL "$part" | head -n1)
          size=$(lsblk -ndo SIZE "$part" | head -n1)
          fstype=$(lsblk -ndo FSTYPE "$part" | head -n1)
          uuid=$(blkid -s UUID -o value "$part" 2>/dev/null || echo "-")
          partuuid=$(blkid -s PARTUUID -o value "$part" 2>/dev/null || echo "-")
          printf "  %-48s %-13s %-9s %-8s %-36s %-36s\n" "$part" "$label" "$size" "$fstype" "$uuid" "$partuuid"
        done
      done
    ) > /etc/nixos/storage-map.txt
  '';

  # Example swap partition (commented out, enable if needed)
  # Weatherwax disk above: uncomment the partition and this NixOS swap config:
  # swapDevices = [
  #   { device = "/dev/disk/by-partlabel/swap"; }
  # ];

}
