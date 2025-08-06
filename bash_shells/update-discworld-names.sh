#!/usr/bin/env bash
# =============================================
# update-discworld-names.sh
# =============================================
# --- UPDATE DISCWORLD-NAMES.NIX TO MATCH CURRENT DISK LABELS ---
# Called by: disk.nix (systemd.services.update-discworld-names)
# Atomically updates the .nix registry to reflect reality.
# ---------------------------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

NAMES_FILE="/etc/nixos/discworld-names.nix"
TMPFILE="$(mktemp)"

# Use nix to extract all possible names (keys in the attrset)
ALL_NAMES=($(nix eval --raw --expr 'builtins.concatStringsSep " " (builtins.attrNames (import ./discworld-names.nix))'))

# Get currently assigned disk labels (unique, non-empty)
CURRENT=($(lsblk -dno LABEL | grep -v '^$' | sort -u))

echo "{" > "$TMPFILE"
for name in "${ALL_NAMES[@]}"; do
  state="unused"
  for lbl in "${CURRENT[@]}"; do
    if [[ "$lbl" == "$name" ]]; then
      state="used"
      break
    fi
    if [[ "$state" == "unused" && $(grep "$name = \"used\"" "$NAMES_FILE") ]]; then
      echo "WARN: $name was marked as used, but no labeled disk was found. Marking as unused."
    fi
  done
  echo "  $name = \"$state\";" >> "$TMPFILE"
done
echo "}" >> "$TMPFILE"

mv "$TMPFILE" "$NAMES_FILE"
echo "Updated $NAMES_FILE with current disk label state."
