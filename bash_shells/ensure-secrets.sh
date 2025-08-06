#!/usr/bin/env bash
# =============================================
# ensure-secrets.sh
# =============================================
# --- ENSURE AGE SECRETS & IDENTITY EXIST ---
# - Ensures age identity and all agenix secrets are present (creates dummy if missing)
# - Called by: secrets.nix (ensure-secrets systemd service)
# --------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

# --- CONFIGURABLE PATHS ---
SECRETS_DIR="/etc/nixos/secrets"
SECRET_FILES=(
  "github-token.age"
  "traefik-auth.age"
  "cloudflare-api.age"
  "cloudflare-tunnel.age"
  "letsencrypt-acme.age"
  "nixuser-password.hash.age"
  "tailscale-authkey.age"
)

AGE_KEY_FILE="${SECRETS_DIR}/key.txt"
AGE_RECIPIENT_FILE="${SECRETS_DIR}/public.age"

# --- ENSURE AGE IDENTITY EXISTS ---
if [[ ! -f "$AGE_KEY_FILE" && ! -f "$AGE_RECIPIENT_FILE" ]]; then
  echo "No age key or public recipient found, generating new age identity in $AGE_KEY_FILE"
  mkdir -p "$SECRETS_DIR"
  age-keygen -o "$AGE_KEY_FILE"
  age-keygen -y "$AGE_KEY_FILE" > "$AGE_RECIPIENT_FILE"
  chmod 0400 "$AGE_KEY_FILE"
  chmod 0444 "$AGE_RECIPIENT_FILE"
  echo "A new age identity was generated. BACK UP $AGE_KEY_FILE securely! Anyone with $AGE_KEY_FILE can decrypt your secrets."
fi

# --- USE PRIVATE KEY IF EXISTS, ELSE PUBLIC RECIPIENT ---
if [[ -f "$AGE_KEY_FILE" ]]; then
  AGE_RECIPIENT_OPT="-i $AGE_KEY_FILE"
else
  AGE_RECIPIENT_OPT="-r $(cat $AGE_RECIPIENT_FILE)"
fi

# --- ENSURE ALL SECRET FILES EXIST ---
for f in "${SECRET_FILES[@]}"; do
  secret_path="${SECRETS_DIR}/$f"
  if [[ ! -f "$secret_path" ]]; then
    echo "Secret $secret_path missing, creating with dummy value 'missingpassword'"
    if [[ "$f" == *hash* ]]; then
      hashed=$(openssl passwd -6 "missingpassword")
      echo "$hashed" | age -e $AGE_RECIPIENT_OPT -o "$secret_path"
    else
      echo "missingpassword" | age -e $AGE_RECIPIENT_OPT -o "$secret_path"
    fi
    chmod 0400 "$secret_path"
  fi
done

# --- NOTES FOR OPERATORS ---
# - Your age keypair is at $AGE_KEY_FILE (private) and $AGE_RECIPIENT_FILE (public).
# - BACK UP $AGE_KEY_FILE securely. Anyone with it can decrypt your secrets.
# - To change a secret: echo "newvalue" | age -e -r "$(cat $AGE_RECIPIENT_FILE)" -o $SECRETS_DIR/your-secret.age
# - To change a password hash: echo "newpassword" | openssl passwd -6 -stdin | age -e -r "$(cat $AGE_RECIPIENT_FILE)" -o $SECRETS_DIR/nixuser-password.hash.age
# - Remove a .age file and re-run this script to recreate with 'missingpassword' (not recommended except for test/dev).

exit 0
