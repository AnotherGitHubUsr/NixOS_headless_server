{ config, pkgs, ... }:

{
  # Secret for nixuser password (file is created by ensure-secrets systemd service)
  age.secrets.nixuser-password = {
    file = ./secrets/nixuser-password.hash.age;
    mode = "0440";
    owner = "root";
    group = "root";
  };

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
    permitRootLogin = "no";
  };

  services.crowdsec = {
    enable = true;
    # NOTE: Crowdsec/iptables may block container traffic, see README and below!
  };
  services.fail2ban = { enable = true; };
  services.clamav.daemon.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 123 ];
    extraCommands = ''
      # Only allow NAS/Nixserver comms on naslink, drop others
      iptables -A INPUT  -s 10.250.250.250/32 -d 10.250.250.249/32 -j ACCEPT
      iptables -A OUTPUT -s 10.250.250.249/32 -d 10.250.250.250/32 -j ACCEPT
      iptables -A INPUT  -d 10.250.250.249/32 ! -s 10.250.250.250/32 -j DROP
      iptables -A OUTPUT -s 10.250.250.249/32 ! -d 10.250.250.250/32 -j DROP
    '';
    # This will restrict /30 subnet to only Nixserver/NAS communication.
  };

  # Docker/incus mitigation: Add rules to allow container bridges as needed,
  # especially if containers need external network access or if Crowdsec/Fail2ban 
  # bouncers block container traffic.
  # See https://crowdsec.net/faq/docker/

  # --- COMMENTARY FOR USERS ---
  # - The ensure-secrets systemd service (see secrets.nix) makes sure age keys and all declared secret files exist,
  #   preventing failed builds. If a secret or key is missing, it is generated automatically.
  #    ! ! ! Make sure to change the password. If it was missing it is set to "missingpassword" ! ! !
  # - To change or rotate secrets, use 'age' with ./secrets/public.age as described in secrets.nix.
  # - Always BACK UP your private key ./secrets/key.txt securely!
}
