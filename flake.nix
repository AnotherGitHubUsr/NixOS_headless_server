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


  # This exposes nixosConfigurations.nixserver at the top level of outputs.
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
          ./configuration.nix
          disko.nixosModules.disko
          agenix.nixosModules.default
          # add more...
        ];
      };
    };
  };


}

