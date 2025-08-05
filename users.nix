{ config, pkgs, agenix, ... }:

let
  # Get hashed password from agenix. Generate it: `openssl passwd -6`, encrypt it with agenix.
  nixuserPasswordFile = "/run/agenix/nixuser-password.hash";
  # Try to fetch GitHub SSH keys, fallback to local fallback if unreachable.
  githubKeyUrl = "https://github.com/AnotherGitHubUsr.keys";
  localFallbackKeys = builtins.readFile ./secrets/nixuser.authorized_keys.fallback;
  fetchGithubKeys = builtins.tryEval (builtins.fetchurl { url = githubKeyUrl; sha256 = null; });
  authorizedKeys = if fetchGithubKeys.success then builtins.readFile fetchGithubKeys.value else localFallbackKeys;
in
{
  users.users.nixuser = {
    isNormalUser = true;
    description = "main server user";
    home = "/home/nixuser";
    extraGroups = [ "wheel" "docker" "incus" ];
    shell = pkgs.nushell;
    hashedPasswordFile = nixuserPasswordFile;
    # Passwordless sudo for this user - remove for better security
    sudo = { extraRules = [ { users = [ "nixuser" ]; commands = [ "ALL" ]; nopasswd = true; } ]; };
    openssh.authorizedKeys.keys = builtins.split "\n" authorizedKeys;
  };
  # If nushell causes trouble, switch to bash by uncommenting:
  # users.users.nixuser.shell = pkgs.bash;

  users.users.root.hashedPassword = "*"; # Root login disabled.
}
