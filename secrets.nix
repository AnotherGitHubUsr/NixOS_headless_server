# =========================
# secrets.nix
# =========================
# --- SECRETS & AGE MANAGEMENT ---
# All secrets managed via agenix and systemd. See README for operational notes.
# Ensures secrets exist (dummy if missing), manages permissions.
# --------------------------------

{ config, pkgs, ... }:

let
  # --- SECRETS DIRECTORY AND FILENAMES ---
  secretsDir = ./secrets;

  # --- ALL SECRET FILES (AGE ENCRYPTED) ---
  secretFiles = [
    "github-token.age"
    "traefik-auth.age"
    "cloudflare-api.age"
    "cloudflare-tunnel.age"
    "letsencrypt-acme.age"
    "nixuser-password.hash.age"
    "tailscale-authkey.age"
  ];
in
{
  # --- SYSTEMD: ENSURE SECRETS EXIST BEFORE AGENIX OR SERVICES ---
  systemd.services.ensure-secrets = {
    description = "Ensure age identity and secret files exist before agenix/services";
    wantedBy = [ "multi-user.target" ];
    before = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash /etc/nixos/bash_shells/ensure-secrets.sh";
      RemainAfterExit = true;
      User = "root";
    };
  };

  # --- USER INSTRUCTIONS ---
  # - Your age keypair is stored as ./secrets/key.txt (private) and ./secrets/public.age (public recipient).
  # - BACK UP key.txt securely. Anyone with this file can decrypt your secrets.

  # - To change a secret: echo "newvalue" | age -e -r "$(cat ./secrets/public.age)" -o ./secrets/your-secret.age
  
  # - To change a password hash: echo "newpassword" | openssl passwd -6 -stdin | age -e -r "$(cat ./secrets/public.age)" -o ./secrets/nixuser-password.hash.age
  # - Remove a .age file and `systemctl start ensure-secrets` to auto-recreate with 'missingpassword' (not recommended except for test/dev).

  # --- DECLARED SECRETS FOR AGENIX ---
  age.secrets.github-token = {
    file = ./secrets/github-token.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.traefik-auth = {
    file = ./secrets/traefik-auth.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.cloudflare-api = {
    file = ./secrets/cloudflare-api.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.cloudflare-tunnel = {
    file = ./secrets/cloudflare-tunnel.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.letsencrypt-acme = {
    file = ./secrets/letsencrypt-acme.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.nixuser-password = {
    file = ./secrets/nixuser-password.hash.age;
    mode = "0440";
    owner = "root";
    group = "root";
  };
  age.secrets.tailscale-authkey = {
    file = ./secrets/tailscale-authkey.age;
    mode = "0440";
    owner = "root";
    group = "root";
  };
}
