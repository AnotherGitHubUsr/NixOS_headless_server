# =========================
# users.nix
# =========================
# --- USER ACCOUNTS, SUDO, SHELL, AUTH KEYS, PASSWORDS ---
# User and SSH setup. Password from agenix, fallback pubkey.
# ---------------------------------------------------------

{ config, pkgs, agenix, ... }:

let
  # --- GET HASHED PASSWORD FROM AGENIX ---
  nixuserPasswordFile = "/run/agenix/nixuser-password.hash";

  # --- GITHUB SSH KEYS WITH FALLBACK ---
  githubKeyUrl = "https://github.com/AnotherGitHubUsr.keys";
  localFallbackKeys = builtins.readFile ./secrets/nixuser.authorized_keys.fallback;
  fetchGithubKeys = builtins.tryEval (builtins.fetchurl { url = githubKeyUrl; sha256 = null; });
  authorizedKeys = if fetchGithubKeys.success then builtins.readFile fetchGithubKeys.value else localFallbackKeys;
in
{
  # --- MAIN USER ---
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

  # --- DISABLE ROOT LOGIN ---
  users.users.root.hashedPassword = "*";
}
