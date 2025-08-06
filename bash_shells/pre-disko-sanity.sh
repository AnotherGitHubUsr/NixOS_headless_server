#!/usr/bin/env bash
# =============================================
# pre-disko-sanity.sh
# =============================================
# --- SANITY CHECKS BEFORE RUNNING DISKO ---
# - Checks disk label assignment consistency
# - Prevents accidental data loss or reformatting
# - Called manually before disk operations/install
# --------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

NAMES_FILE="/etc/nixos/discworld-names.nix"
DISK_NIX="/etc/nixos/disk.nix"

# Read list of currently "used" names from discworld-names.nix using nix
USED=($(nix eval --raw --expr '
  let names = import ./discworld-names.nix; in
    builtins.concatStringsSep " " (builtins.attrNames (builtins.filterAttrs (_: v: v == "used") names))
'))

# Build a mapping: label -> device
declare -A labeldev
while read -r dev label; do
  [[ -z "$label" ]] && continue
  labeldev[$label]=$dev
done < <(lsblk -dno NAME,LABEL | awk '{print "/dev/"$1, $2}')

# 1. For each disk to be created/formatted/labeled (from disk.nix), check for conflicts.
grep -Po 'label\s*=\s*"\K[^"]+' "$DISK_NIX" | while read -r label; do
  if printf '%s\n' "${USED[@]}" | grep -qx "$label"; then
    if [[ -n "${labeldev[$label]:-}" ]]; then
      echo "OK: $label already assigned to ${labeldev[$label]}"
    else
      echo "ERROR: Label '$label' is marked as 'used' but not found on any device. Disko would try to create/format, but this is unsafe. Aborting."
      exit 1
    fi
  else
    if [[ -n "${labeldev[$label]:-}" ]]; then
      echo "ERROR: Label '$label' found on device ${labeldev[$label]}, but not marked as 'used' in names file. Please update names file or investigate."
      exit 1
    else
      echo "Ready: Label '$label' is not present or used and will be assigned as part of Disko run if the target device is specified."
    fi
  fi
done

# 2. Make sure no label is assigned to more than one device
dups=0
for label in "${USED[@]}"; do
  count=$(lsblk -dno LABEL | grep -c "^$label$")
  if (( count > 1 )); then
    echo "ERROR: Multiple devices found with label '$label'."
    dups=1
  fi
done

if (( dups )); then
  exit 1
fi

# 3. Warn if any disk in the system is NOT in disk.nix (not an error, just info).
for dev in /dev/sd* /dev/nvme*; do
  if [[ -b "$dev" ]]; then
    found=0
    for label in "${!labeldev[@]}"; do
      [[ "${labeldev[$label]}" == "$dev" ]] && found=1
    done
    [[ $found == 0 ]] && echo "INFO: Device $dev is not mentioned in disk.nix. It will not be labeled, formatted, or mounted."
  fi
done
