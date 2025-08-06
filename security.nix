# =========================
# security.nix
# =========================
# --- SECURITY SERVICES, FIREWALL, HARDENING ---
# Manages secret/service dependencies, fail2ban, AV, firewall, crowdsec.
# ----------------------------------------------

{ config, pkgs, ... }:

{
  # --- ALL SECRET MANAGEMENT via ensure-secrets.service ---
  # Any security or service module should depend on secrets being present at their /run/agenix/ paths.

  # --- FAIL2BAN: SSH AND BRUTE-FORCE PROTECTION ---
  services.fail2ban.enable = true;

  # --- CLAMAV: ANTIVIRUS DAEMON AND UPDATER ---
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;

  # --- FIREWALL: BASIC IPV4/6 FILTERING ---
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ]; # SSH/HTTP/HTTPS
  networking.firewall.allowedUDPPorts = [ 53 ];        # DNS

  # --- CROWDSEC: BEHAVIORAL DETECTION ---
  services.crowdsec = {
    enable = true;
    # Ensure crowdsec doesn't conflict with fail2ban or docker.
    postOverflowsAction = "true"; # Prevents failure on crowdsec errors.
  };

  # --- IPTABLES-PERSISTENT (OPTIONAL) ---
  # systemd.services.iptables-persistent = { ... };

  # --- SECRETS DEPENDENCY NOTE ---
  # If you have security services that require secrets, ensure their systemd units use:
  # after = [ "ensure-secrets.service" ];

  # Optionally, ensure all dependent services have
  # environment.variables or configuration files that reference secrets at:
  #   /run/agenix/github-token, /run/agenix/traefik-auth, etc.
}
