# =========================
# pkgs.nix
# =========================
# --- PACKAGE MANAGEMENT, SERVICES, HARDWARE SUPPORT ---
# Sets system packages (stable/unstable), hardware, drivers, flatpak, docker, incus, and tailscale.
# -----------------------------------------------------

{ config, pkgs, pkgsUnstable, ... }:

{
  # --- NIX PATH CHANNELS (FOR SHELLS/LEGACY) ---
  nix.nixPath = [ "nixpkgs=${pkgs.path}" "nixos-unstable=${pkgsUnstable.path}" ];

  # --- CORE SYSTEM PACKAGES ---
  environment.systemPackages = with pkgs; [
    vim         # Editor (stable)
    wget        # Downloader
    git         # Version control
    nix-ld      # Run non-Nix binaries
    flatpak     # Flatpak manager
    flathub     # Flathub repo
    incus       # LXD alternative
    docker      # Containers
    mergerfs    # Mergerfs support
    gh          # GitHub CLI
    tldr        # Short manpages
    tailscale   # VPN
    p7zip       # 7z
    tmux        # Terminal multiplexer
    htop        # Resource monitor
    nmon        # Monitor
    systemd     # Service/timer writing
    fish        # Alternative shell
    nushell     # Default shell
    bcachefs-tools  # User‑space utilities for bcachefs
    # Flatpak Wine, see below.
  ];

  # --- UNSTABLE PACKAGE USAGE EXAMPLE ---
  # environment.systemPackages = with pkgsUnstable; [
  #   vim # Uncomment to use unstable vim, if you want latest features.
  # ];

  # --- TAILSCALE VPN SETUP ---
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "accept"; # Accept and ~advertise~ (both) routes (change as needed)
    extraUpFlags = [
      "--authkey" "@${config.age.secrets.tailscaleAuthKey.path}"
      "--accept-routes"
      "--hostname=nixserver"
      "--timeout=120s"
      "--ssh"
      "--ephemeral"
    ];
  };

  # --- FLATPAK & WINE SETUP ---
  services.flatpak.enable = true;
  environment.variables.FLATPAK_ENABLE = "1";
  services.flatpak.extraRemotes = [
    { name = "flathub"; url = "https://flathub.org/repo/flathub.flatpakrepo"; }
  ];

  # --- HARDWARE (AMD RYZEN & RADEON) ---
  hardware.cpu.amd.updateMicrocode = true;
  hardware.opengl.extraPackages = with pkgs; [ amdvlk ];
  services.firmware.linux-firmware.enable = true;

  # --- DOCKER/INCUS NETWORK BRIDGES & STORAGE ---
  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    bridge = "docker0";
    bip = "10.200.200.1/24";
    default-address-pools = [{ base = "10.200.200.0/24"; size = 24; }];
    storage-driver = "overlay2";
  };

  services.incus = {
    enable = true;
    networks = {
      homei = {
        type = "bridge";
        ipv4.address = "10.150.150.1/24";
        dhcp = false;
      };
    };
    storagePools = [
      { name = "default"; driver = "zfs"; source = "tank"; }
    ];
  };
}
