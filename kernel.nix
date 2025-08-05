{ pkgs, ... }: 

{
  # --- Kernel selection ---
  # Pin to kernel 6.12 for stability. Rationale: Avoids breakage from newer, untested kernels.
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # To use the latest available kernel (may break ZFS, bcache, bcachefs):
  # boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Kernel Modules ---
  # Add ZFS and block-level bcache support.
  # openzfs_2_3_3 is a recommended stable version.
  # bcache is the original block-device cache layer.
  boot.extraModulePackages = with pkgs.linuxPackages_6_12; [
    openzfs_2_3_3
    # bcache
    # openzfs_latest         # Option: try latest ZFS module for newer kernels.
    # bcachefs_1_5           # Option: use bcachefs filesystem (uncomment to enable).
    # bcachefs_latest        # Option: always use latest bcachefs (if available in Nixpkgs).
    # bcachefs               # Generic bcachefs module, if defined in your Nixpkgs channel.
  ];

  # --- Kernel parameters ---
  # Custom flags for storage and virtualization.
  boot.kernelParams = [
    "zfs.force=1"                  # Allows ZFS to run on newer/unsupported kernels.
    "bcache.allow_across_disks=1"  # bcache: allow one SSD to cache multiple HDDs.
    "amd_iommu=on"                 # Enables AMD IOMMU (for PCI passthrough, VMs).
    "iommu=pt"                     # Pass-through mode for IOMMU (performance).
    # Add other kernel params here.
  ];

  # --- Notes ---
  # - Only use both bcache and bcachefs if testing/migrating between them.
  # - For experimental/unstable modules, be sure to test on non-critical systems first.
  # - If your Nixpkgs channel does not have a recent bcachefs module,
  #   consider using an overlay or building the module manually:
  #   https://github.com/koverstreet/bcachefs
}
