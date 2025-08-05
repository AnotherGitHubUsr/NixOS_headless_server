{
  description = "Flake for NixOS headless server (with disko, agenix, stable/unstable pkgs)";

  # --- Inputs: Repos/Flakes this flake depends on ---
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";          # Stable channel for system/core packages
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # Unstable channel for opt-in bleeding edge pkgs
    disko.url = "github:nix-community/disko";                  # Declarative partitioning
    agenix.url = "github:ryantm/agenix";                       # Encrypted secrets mgmt
    flake-utils.url = "github:numtide/flake-utils";            # Utility helpers for multi-system output
  };

  # --- Outputs: Define what this flake provides for each system ---
  outputs = { self, nixpkgs, nixpkgs-unstable, disko, agenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # Imports both stable and unstable channels for this arch (x86_64-linux)
        pkgs = import nixpkgs { inherit system; };
        pkgsUnstable = import nixpkgs-unstable { inherit system; };
      in
      {
        # Exposes your NixOS config as 'nixosConfigurations.nixserver'
        nixosConfigurations.nixserver = pkgs.lib.nixosSystem {
          system = "x86_64-linux";    # Target architecture
          specialArgs = { inherit pkgs pkgsUnstable agenix; }; # Pass pkgs, pkgsUnstable, agenix to modules for flexibility
          modules = [
            ./configuration.nix         # Main NixOS config
            disko.nixosModules.disko    # Enables declarative disk setup
            agenix.nixosModules.default # Enables secret management
            # Add more config modules as needed (e.g. pkgs.nix, disk.nix, users.nix)
          ];
        };
      }
    );
}

