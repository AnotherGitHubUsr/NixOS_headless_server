{ config, pkgs, ... }:

{
  # All secret management (age identity, secret provisioning) is handled by ensure-secrets.service.
  # Any security or service module should depend on secrets being present at their /run/agenix/ paths.

  # Fail2ban example: enables basic SSH and service brute-force protection
  services.fail2ban.enable = true;

  # ClamAV: enable for automated virus scanning
  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;

  # Firewall: basic IPv4/IPv6 filtering (adjust as needed)
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 ]; # SSH/HTTP/HTTPS
  networking.firewall.allowedUDPPorts = [ 53 ];        # DNS

  # Crowdsec: behavioral detection (adjust/configure as required)
  services.crowdsec = {
    enable = true;
    # Ensure crowdsec doesn't conflict with fail2ban or docker.
    postOverflowsAction = "true"; # Prevents failure on crowdsec errors.
  };

  # iptables-persistent (if needed)
  # systemd.services.iptables-persistent = { ... };

  # If you have security services that require secrets, ensure their systemd units use:
  # after = [ "ensure-secrets.service" ];

  # Optionally, ensure all dependent services have
  # environment.variables or configuration files that reference secrets at:
  #   /run/agenix/github-token, /run/agenix/traefik-auth, etc.
}
