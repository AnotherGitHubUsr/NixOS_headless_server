# =========================
# network.nix
# =========================
# --- NETWORKING, TIMEZONE, INTERFACES, SUBNETS ---
# Sets hostname, static IP, DNS, NTS NTP, and special /30 subnet for NAS.
# -------------------------------------------------

{ config, pkgs, ... }:

{
  # --- HOSTNAME & TIME ---
  networking.hostName = "nixserver";
  time.timeZone = "Europe/Berlin";        # This is standard for ME(S)T

  # --- NTP SERVERS (WITH NTS SUPPORT) ---
  networking.timeServers = [
    "bevtime1.metrologie.at"
    "times.tubit.tu-berlin.de"
    "ntp11.metas.ch"
    "time-a-g.nist.gov"
  ];
  networking.ntp.useNts = true;

  # --- PRIMARY ETHERNET INTERFACE (STATIC) ---
  networking.interfaces.enp4s0 = {
    ipv4.addresses = [{ address = "192.168.1.3"; prefixLength = 24; }];
  };
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [
    "192.168.1.50" # Pihole
    "9.9.9.9"      # Quad9
  ];

  # --- /30 SUBNET FOR NAS COMMUNICATION ONLY ---
  networking.interfaces.naslink = {
    ipv4.addresses = [{ address = "10.250.250.249"; prefixLength = 30; }];
  };
}
