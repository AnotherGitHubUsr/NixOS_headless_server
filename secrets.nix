{ config, pkgs, ... }:

let
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

  ensureSecretsScript = pkgs.writeShellScript "ensure-secrets.sh" ''
    set -eu

    # --- Ensure age identity exists ---
    AGE_KEY_FILE="${secretsDir}/key.txt"
    AGE_RECIPIENT_FILE="${secretsDir}/public.age"

    # If neither key nor public recipient exists, generate a new age keypair
    if [ ! -f "$AGE_KEY_FILE" ] && [ ! -f "$AGE_RECIPIENT_FILE" ]; then
      echo "No age key or public recipient found, generating new age identity in $AGE_KEY_FILE"
      mkdir -p "${secretsDir}"
      age-keygen -o "$AGE_KEY_FILE"
      age-keygen -y "$AGE_KEY_FILE" > "$AGE_RECIPIENT_FILE"
      chmod 0400 "$AGE_KEY_FILE"
      chmod 0444 "$AGE_RECIPIENT_FILE"
      echo "A new age identity was generated. BACK UP $AGE_KEY_FILE securely! Anyone with $AGE_KEY_FILE can decrypt your secrets."
    fi

    # Prefer using the private key, but if only public recipient, use that
    if [ -f "$AGE_KEY_FILE" ]; then
      AGE_RECIPIENT_OPT="-i $AGE_KEY_FILE"
    else
      AGE_RECIPIENT_OPT="-r $(cat $AGE_RECIPIENT_FILE)"
    fi

    # --- Ensure all declared secrets exist, create with 'missingpassword' if missing ---
    for f in ${builtins.toString secretFiles}; do
      secretPath="${secretsDir}/$f"
      if [ ! -f "$secretPath" ]; then
        echo "Secret $secretPath missing, creating with dummy value 'missingpassword'"
        if echo "$f" | grep -q "hash"; then
          hashed=$(openssl passwd -6 "missingpassword")
          echo "$hashed" | age -e $AGE_RECIPIENT_OPT -o "$secretPath"
        else
          echo "missingpassword" | age -e $AGE_RECIPIENT_OPT -o "$secretPath"
        fi
        chmod 0400 "$secretPath"
      fi
    done
  '';
in
{
  # systemd oneshot: Ensures age identity and all secrets exist before agenix/service start
  systemd.services.ensure-secrets = {
    description = "Ensure age identity and secret files exist before agenix/services";
    wantedBy = [ "multi-user.target" ];
    before = [ "agenix.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ensureSecretsScript}";
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
