# Imports all .nix files. For detailed comments: index.txt

{ config, pkgs, ... }:

{
  imports = [
    ./users.nix
    ./disk.nix
    ./pkgs.nix
    ./network.nix
    ./security.nix
    ./monitoring.nix
    ./gitops.nix
    ./secrets.nix
    ./kernel.nix
  ];
  
  # Ensures correct permissions on shell scripts before systemd and other services rely on them.
  system.activationScripts."00-fix-bash-shell-perms" = ''
    #!/usr/bin/env bash
    /etc/nixos/bash_shells/fix-shell-permissions.sh
  '';
}
