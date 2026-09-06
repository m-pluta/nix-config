{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./routing.nix
  ];

  networking.hostName = "mikeway";

  homelab = {
    enable = true;
    description = "Router, network gateway, and homelab front door";
    baseDomain = "mpluta.dev";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflare-dns-api.path;
    net.lan = "192.168.100.1";
    tailscale = {
      enable = true;
      address = "100.67.111.121";
    };
    # Split-horizon DNS: Unbound picks a view by the client's source subnet, so
    # mpluta.dev resolves to the LAN IP on the LAN and the tailnet IP over tailscale.
    splitDns = {
      enable = true;
      domains = [ "mpluta.dev" ];
      views = [
        {
          name = "lan";
          interface = "br-lan";
          listen = "192.168.100.1";
          subnet = "192.168.100.0/24";
          answer = "192.168.100.1";
        }
        {
          name = "tailnet";
          interface = "tailscale0";
          listen = "100.67.111.121";
          subnet = "100.64.0.0/10";
          answer = "100.67.111.121";
        }
      ];
    };
    cloudflared = {
      enable = true;
      tunnelId = "7a16d95b-031d-483f-befa-d8fdc081fe5c";
      credentialsFile = config.age.secrets.cloudflared-tunnel.path;
      expose."mpluta.dev" = [
        ""
        "www"
        "git"
      ];
    };
  };

  age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare/dns-api.age";

  # Front-door Caddy: reachable from the LAN (tailnet is already a trusted interface,
  # public access arrives via the tunnel on loopback) but never served on the WAN.
  networking.firewall.interfaces.br-lan.allowedTCPPorts = [
    80
    443
  ];

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
