{ config, pkgs, ... }:

let
  # Directory containing the secret files
  secretsDir = ./secrets;

  # List of all secret files to check or create
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
  # systemd oneshot: Ensures age identity and all secrets exist before agenix/service start
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

  # --- DECLARED SECRETS ---
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
