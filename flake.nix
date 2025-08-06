# =========================================
# flake.nix
# =========================================
# --- ENTRYPOINT FLAKE FOR NIXOS HEADLESS SERVER ---
# Provides all system, version, and module pins for reproducibility.
# Uses both stable and unstable Nixpkgs, disko for partitioning, agenix for secrets.
# --------------------------------------------------

{
  description = "Flake for NixOS headless server (with disko, agenix, stable/unstable pkgs)";

  # --- Flake Inputs: Define all source channels and tools
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";                 # Stable channel for system/core packages
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";     # Unstable channel for opt-in bleeding edge pkgs
    disko.url = "github:nix-community/disko";                         # Declarative partitioning (Disko module)
    agenix.url = "github:ryantm/agenix";                              # Encrypted secrets management (agenix)
    flake-utils.url = "github:numtide/flake-utils";                   # Utility helpers for multi-system output
  };

  # --- Outputs: Build the configuration set
  outputs = { self, nixpkgs, nixpkgs-unstable, disko, agenix, ... }: {
    nixosConfigurations = {
      nixserver = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          pkgsUnstable = import nixpkgs-unstable { system = "x86_64-linux"; };
          agenix = agenix;
        };
        modules = [
          ./configuration.nix          # Main config imports (all modular .nix)
          disko.nixosModules.disko     # Disko module (partition layout)
          agenix.nixosModules.default  # Age/agenix secrets module
        ];
      };
    };
  };
}
