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
    "Detritus"      # /dev/sdb, ZFS only
    # "Bluejohn"    # /dev/sdc, (optional ZFS future)
    # "Carborundum" # /dev/sdd, (optional ZFS future)
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
  # --- Disk layout for system and expansion (Disko syntax) ---
  disko = {
    devices = {
      disk = {
        Weatherwax = {
          device = "/dev/sda";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              boot = {  # UEFI boot partition
                start = "1MiB";
                end = "512MiB";
                type = "ef00";
              };
              root = {  # System root partition
                start = "512MiB";
                end = "100%";
                type = "8300";
              };
              # swap = {                      # Example swap partition (DISABLED: uncomment to enable)
              #   start = "100% - 8GiB";      # Last 8GiB of disk (adjust size as needed)
              #   end = "100%";
              #   type = "8200";              # Linux swap type
              # };
            };
          };
        };
        Detritus = {
          device = "/dev/sdb";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              data = {  # ZFS data partition
                start = "1MiB";
                end = "100%";
                type = "8300";
              };
            };
          };
        };
        # Future ZFS expansion drives:
        # Bluejohn = { ... };
        # Carborundum = { ... };
        Littlebottom = { device = "/dev/nvme0n1"; type = "disk"; };
        Carrot       = { device = "/dev/nvme1n1"; type = "disk"; };
        Vimes        = { device = "/dev/nvme2n1"; type = "disk"; };
        Angua        = { device = "/dev/nvme3n1"; type = "disk"; };
      };
      # (No more zfs here! ZFS moved to disko.zpools)
    };

    # --- ZFS pool for Detritus (and future expansion) ---
    zpools = {
      hddpool = {
        # Reference the *partition*, not the raw disk (i.e., /dev/sdb1, not /dev/sdb)
        devices = [ "/dev/sdb1" ]; # Only Detritus (future: expand this list)
        options = {
          version = "2.3.3";
        };
        # You can add more ZFS pool options here, e.g. mountpoint, features, etc.
      };
    };
  };

  # iSCSI configuration: These devices come from your NAS and must be discovered at boot.
  # Instructions:
  #   1. On your NAS, export block devices (LUNs) via iSCSI.
  #   2. On this host, after `services.open-iscsi` is enabled and running, check device paths with:
  #        ls -l /dev/disk/by-path/ | grep iscsi
  #      Example output:
  #        /dev/disk/by-path/ip-10.250.250.250:iscsi-0-0-0-0-lun-0 -> ../../sdX
  #   3. Add those device paths to the bcachefs pool below.

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
}
