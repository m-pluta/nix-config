{ config, ... }:
{
  homelab = {
    networks = {
      mikeway = {
        lan = {
          v4 = "192.168.100.1";
          interface = "br-lan";
        };
        mesh = {
          v4 = "100.67.111.121";
          interface = "tailscale0";
        };
      };
      mikelab = {
        lan = {
          v4 = "192.168.100.10";
          interface = "enp6s0";
        };
        mesh = {
          v4 = "100.120.225.75";
          interface = "tailscale0";
        };
      };
    };

    splitDns.resolverAddress = config.homelab.networks.mikeway.lan.v4;
  };
}
