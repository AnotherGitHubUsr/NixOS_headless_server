# =========================
# configuration.nix
# =========================
# --- SYSTEM CONFIGURATION ENTRYPOINT ---
# Imports all modular .nix configs. For module description see index.txt.
# Also adds core activation scripts (fix-perms, gitops).
# ---------------------------------------

{ config, pkgs, pkgsUnstable, agenix, ... }:

{
  # --- MODULE IMPORTS ---
  imports = [
    ./users.nix
    ./disk.nix
    ./pkgs.nix
    ./network.nix
    ./security.nix
    ./monitoring.nix
    ./secrets.nix
    ./kernel.nix
    ./discworld-names.nix
  ];

  # --- SHELL SCRIPT PERMISSIONS FIX (run early!) ---
  system.activationScripts."00-fix-bash-shell-perms" = ''
    #!/usr/bin/env bash
    /etc/nixos/bash_shells/fix-shell-permissions.sh
  '';

  # --- GITOPS: AUTOCOMMIT AND PUSH (was gitops.nix, now inline) ---
  # After every rebuild, auto-commit and push config changes to GitHub with version bumping.
  system.activationScripts.gitops = ''
    ${pkgs.bash}/bin/bash /etc/nixos/bash_shells/gitops.sh
  '';

  mainRelease = "0";    # Sets mainRelease version as used in gitops.sh
}
