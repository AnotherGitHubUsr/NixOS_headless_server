{ config, pkgs, ... }:

{
  networking.hostName = "nixserver";
  time.timeZone = "Europe/Berlin";
  networking.timeServers = [
    "bevtime1.metrologie.at"
    "times.tubit.tu-berlin.de"
    "ntp11.metas.ch"
    "time-a-g.nist.gov"
  ];
  networking.ntp.useNts = true;

  networking.interfaces.enp4s0 = {
    ipv4.addresses = [{ address = "192.168.1.3"; prefixLength = 24; }];
  };
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [
    "192.168.1.50" # Pihole
    "9.9.9.9"      # Quad9
  ];

  # /30 subnet for NAS communication
  networking.interfaces.naslink = {
    ipv4.addresses = [{ address = "10.250.250.249"; prefixLength = 30; }];
  };
}
