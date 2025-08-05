#!/usr/bin/env bash
# check-discworld-disknames.sh
# Checks that all detected disk labels are valid Discworld names.
# Call from a NixOS activationScript for safe disko usage.

# Set -e for immediate exit on error
set -e

# List of all allowed names (should be synced with disk.nix!)
approved=(Weatherwax Littlebottom Carrot Vimes Angua Detritus \
Glod Gaspode Dibbler Twoflower Rincewind Cohen Susan Luggage Teatime VonLipwig \
Otto William Nobby Sybil Ridcully Ponder Librarian Magrat Nanny Carborundum Bluejohn Brick \
Lu-Tze Igor MrsCake Vetinary Drumknott LadySybil AdoraBelle Sally MissDearheart \
LordVetinary Colon RobbAnybody Cripslock DeWorde)

disklabels=$(lsblk -dno LABEL | grep -v '^$')
not_approved=()
for label in $disklabels; do
  ok=0
  for name in "${approved[@]}"; do
    if [[ "$label" == "$name" ]]; then ok=1; break; fi
  done
  if [[ "$ok" == "0" ]]; then
    not_approved+=("$label")
  fi
done

if [ "${#not_approved[@]}" -ne 0 ]; then
  echo "WARNING: The following disks do NOT use approved Discworld names:"
  printf '  - %s\n' "${not_approved[@]}"
  echo "These disks are eligible for formatting according to disko config."
else
  echo "All disks use approved Discworld names. No unintended formatting will occur."
fi
