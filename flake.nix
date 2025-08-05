{
  description = "Flake for NixOS server";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    agenix.url = "github:ryantm/agenix";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, nixpkgs-unstable, disko, agenix, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsUnstable = import nixpkgs-unstable { inherit system; };
      in
      {
        nixosConfigurations.nixserver = pkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit pkgs pkgsUnstable agenix; };
          modules = [
            ./configuration.nix
            disko.nixosModules.disko
            agenix.nixosModules.default
          ];
        };
      }
    );
}
