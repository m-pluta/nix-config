{ config, ... }:
{
  homelab = {
    networks = {
      mikeway = {
        lan = {
          v4 = "192.168.100.1";
          subnet = "192.168.100.0/24";
          interface = "br-lan";
        };
        mesh.v4 = "100.67.111.121";
      };
      mikelab = {
        lan = {
          v4 = "192.168.100.10";
          subnet = "192.168.100.0/24";
          interface = "enp6s0";
        };
        mesh.v4 = "100.120.225.75";
      };
    };

    splitDns.resolverAddress = config.homelab.networks.mikeway.lan.v4;
  };
}
