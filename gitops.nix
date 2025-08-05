{ config, pkgs, ... }:

let
  mainRelease = "0"; # <--- Change this for a new main release (major version)
in
{
  # This activation script:
  # - Uses an agenix-managed GitHub token for authentication (never stores it long-term)
  # - Tracks release versions in /etc/nixos/RELEASE_VERSION with major.minor.patch logic
  # - Bumps patch if last release was <24h ago, otherwise bumps minor and resets patch
  # - Adds menuentry as a comment in the commit
  # - Cleans up /root/.git-credentials even if an error occurs
  # Now explicitly uses bash as interpreter for activationScript for portability and bashisms.
  system.activationScripts.gitops = {
    # This runs the script as bash, not sh
    interpreter = "${pkgs.bash}/bin/bash";
    text = ''
      set -e
      cd /etc/nixos

      # Use trap to always delete the credentials file on exit or error
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
    '';
  };
}
