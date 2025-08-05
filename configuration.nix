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
}
