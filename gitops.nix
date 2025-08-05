{ config, pkgs, ... }:

let
  mainRelease = "0";
in
{
  # Now simply call the .sh script using bash
  system.activationScripts.gitops = ''
    ${pkgs.bash}/bin/bash /etc/nixos/bash_shells/gitops.sh
  '';
}


# this should now probably just be called somewhere else but I's a temporary/permanent situation