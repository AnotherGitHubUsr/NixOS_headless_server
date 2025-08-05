{ config, pkgs, pkgsUnstable, ... }:

{
  # --- Package channels setup ---
  nix.nixPath = [ "nixpkgs=${pkgs.path}" "nixos-unstable=${pkgsUnstable.path}" ];

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

  # --- Example for using unstable ---
  # environment.systemPackages = with pkgsUnstable; [
  #   vim # Uncomment to use unstable vim, if you want latest features.
  # ];

  # --- Tailscale setup ---
  # What this does: Enables Tailscale VPN with an auth key managed via agenix.
  # The secret for the key must be set in secrets.nix and made available as `config.age.secrets.tailscaleAuthKey.path`.
  # Accepts routes for subnet routing, which can be customized as needed.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both"; # Accept and advertise routes (change to "client", "server", or "none" as needed)
    extraUpFlags = [
      "--authkey" "@${config.age.secrets.tailscaleAuthKey.path}"  # Use agenix-managed authkey
      "--accept-routes"                   # Accept routes from other nodes
      "--hostname=nixserver"
      "--timeout=120s"
      "--ssh"
      "--ephemeral"
    ];
  };


  # --- Flatpak and Wine setup ---
  services.flatpak.enable = true;
  environment.variables.FLATPAK_ENABLE = "1";
  services.flatpak.extraRemotes = [
    { name = "flathub"; url = "https://flathub.org/repo/flathub.flatpakrepo"; }
  ];

  # --- Hardware support (Ryzen & Radeon) ---
  hardware.cpu.amd.updateMicrocode = true;
  hardware.opengl.extraPackages = with pkgs; [ amdvlk ];
  services.firmware.linux-firmware.enable = true;

  # --- Docker/Incus network bridges & storage driver ---
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
