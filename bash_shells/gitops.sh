#!/usr/bin/env bash
# =============================================
# gitops.sh
# =============================================
# --- GIT VERSIONING, COMMIT, PUSH FOR NIXOS ---
# Called by: configuration.nix (activation script)
# Handles GitHub auth (from agenix), auto-versioning, push logic.
# ----------------------------------------------

set -euo pipefail

# --- ENVIRONMENT/PATH ---
export PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH}"
export PATH="${PATH}:/run/current-system/sw/bin"

cd /etc/nixos

trap 'rm -f /root/.git-credentials' EXIT

# 1. Use agenix secret for GitHub token
token="$(cat /run/agenix/github-token)"
echo "https://${token}:x-oauth-basic@github.com" > /root/.git-credentials
chmod 600 /root/.git-credentials
git config --global credential.helper store
git remote set-url origin https://github.com/AnotherGitHubUsr/NixOS_headless_server.git

# 2. Version bump logic
release_file="/etc/nixos/RELEASE_VERSION"
now=$(date +%s)
last_release_time=0
last_version="0.0.0"
if [ -f "$release_file" ]; then
  read last_version last_release_time < "$release_file"
fi

IFS=. read -r last_main last_minor last_patch <<< "$last_version"

  # Uses "mainRelease" as written in configuration.nix
mainRelease=$(sed -nE 's/^\s*mainRelease\s*=\s*"([^"]*)";/\1/p' /etc/nixos/configuration.nix)
if [ "$last_main" != "${mainRelease}" ]; then
  minor=0
  patch=0
else
  age=$((now - last_release_time))
  if [ "$age" -lt $((24 * 3600)) ]; then
    minor=$last_minor
    patch=$((last_patch + 1))
  else
    minor=$((last_minor + 1))
    patch=0
  fi
fi

version="${mainRelease}.${minor}.${patch}"
echo "$version $now" > "$release_file"

# 3. Prepare commit message
menuentry="$(awk -F\' '/menuentry / {print $2; exit}' /boot/grub/grub.cfg)"

git add -A

# Commit with version as main message, menuentry as a comment
git commit -m "release ${version}" -m "# menuentry: ${menuentry}" || true

git pull --rebase origin main || true
git push origin main

# /root/.git-credentials is removed automatically on script exit (success or error) via trap
