# =========================
# disk.nix
# =========================
# --- DISK SETUP, PARTITIONS, MOUNTS, SYSTEMD ---
# Declarative disks with Discworld labels, iSCSI, and bcache/mergerfs/ZFS logic.
# Also manages all storage-related systemd units and activation scripts.
# -----------------------------------------------

  # iSCSI configuration: These devices come from your NAS and must be discovered at boot.
  # Instructions:
  #   1. On your NAS, export block devices (LUNs) via iSCSI.
  #   2. On this host, after services.open-iscsi is enabled and running, check device paths with:
  #        ls -l /dev/disk/by-path/ | grep iscsi
  #      Example output:
  #        /dev/disk/by-path/ip-10.250.250.250:iscsi-0-0-0-0-lun-0 -> ../../sdX
  #   3. Add those device paths to the bcachefs pool below

{ config, pkgs, ... }:

{
  # --- ISCSI SETUP ---
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

  # --- DISKO SPEC: DISK PARTITIONS AND LABELS ---
  disko.devices = {
    disk = {
      weatherwax = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              start = "1MiB";
              end = "512MiB";
              type = "ef00";
              content = {
                type = "filesystem";
                format = "vfat";
                label = "boot";
                mountpoint = "/boot";
              };
            };
            root = {
              start = "512MiB";
              end = "100%";
              type = "8300";
              content = {
                type = "filesystem";
                format = "ext4";
                label = "weatherwax";
                mountpoint = "/";
              };
            };
          };
        };
      };
      detritus = {
        device = "/dev/sdb";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            data = {
              start = "1MiB";
              end = "100%";
              type = "8300";
              content = {
                type = "filesystem";
                format = "xfs";
                label = "detritus";
                mountpoint = "/detritus";
              };
            };
            # --- SWAP PARTITION (UNCOMMENT TO ENABLE, but... maybe not on HDD, eh?) ---
            # swap = {
            #   start = "100%";
            #   end = "10824MiB";
            #   type = "8200";
            #   content = {
            #     type = "swap";
            #     randomEncryption = true;
            #     label = "swap";
            #   };
            # };
          };
        };
      };

      # --- TEMPLATE: ADDITIONAL HDD (EXAMPLE) ---
      # bluejohn = {
      #   device = "/dev/sdc";
      #   type = "disk";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       data = {
      #         start = "1MiB";
      #         end = "100%";
      #         type = "8300";
      #         content = {
      #           type = "filesystem";
      #           format = "xfs";
      #           label = "bluejohn";
      #           mountpoint = "/bluejohn";
      #         };
      #       };
      #     };
      #   };
      # };

      littlebottom = { device = "/dev/nvme0n1"; type = "disk"; };
      carrot       = { device = "/dev/nvme1n1"; type = "disk"; };
      vimes        = { device = "/dev/nvme2n1"; type = "disk"; };
      angua        = { device = "/dev/nvme3n1"; type = "disk"; };
    };
  };

  # --- FILESYSTEMS (LABELS, MOUNTPOINTS, OPTIONS) ---
  fileSystems."/" = {
    device = "/dev/disk/by-label/weatherwax";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  fileSystems."/detritus" = {
    device = "/dev/disk/by-label/detritus";
    fsType = "xfs";
  };

  # --- BCACHEFS POOL: ALWAYS MOUNTED AT /mnt/watch ---
  fileSystems."/mnt/watch" = {
    device = "/dev/disk/by-label/watch";
    fsType = "bcachefs";
    options = [
      "discard=async"
      "foreground_target=/dev/disk/by-label/carrot"
      "writeback"
      "errors=remount-ro"
      "recovery_readonly"
      "readahead=16384"
    ];
  };

  # --- SYSTEMD: FLUSH BCACHEFS WRITEBACK CACHE DAILY ---
  systemd.services.bcachefs-flush = {
    description = "Flush bcachefs writeback cache to disk";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/nixos/bash_shells/bcachefs-flush.sh";
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

  # --- SYSTEMD: FLUSH BCACHEFS IF USAGE > 150 GiB (EVERY 15 MIN) ---
  systemd.services.bcachefs-flush-threshold = {
    description = "Flush bcachefs writeback cache if above 150 GiB";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/nixos/bash_shells/bcachefs-flush-threshold.sh";
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

  # --- SYSTEMD: UPDATE DISCWORLD NAMES (DISK LABELS) EVERY NIGHT ---
  systemd.services.update-discworld-names = {
    description = "Update discworld-names.nix according to current disk state";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/etc/nixos/update-discworld-names.sh";
    };
  };
  systemd.timers.update-discworld-names = {
    enable = true;
    timerConfig = {
      OnCalendar = "03:00";
      Persistent = true;
      Unit = "update-discworld-names.service";
    };
  };

  # --- STORAGE MAP GENERATION (AUTO-GENERATED DOCUMENTATION) ---
  # Documents all block devices, labels, sizes, UUIDs.
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
