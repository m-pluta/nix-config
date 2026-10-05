{
  config,
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
    description = "Router, network gateway, and homelab ingress host";
    baseDomain = "mpluta.dev";
    tailscale.enable = true;
    # Split-horizon DNS: Unbound picks a view by the client's source subnet, so
    # mpluta.dev resolves to the LAN IP on the LAN and the tailnet IP over tailscale.
    splitDns = {
      enable = true;
      domains = [ "mpluta.dev" ];
      views = [
        {
          name = "lan";
          interface = config.homelab.networks.mikeway.lan.interface;
          listen = config.homelab.networks.mikeway.lan.v4;
          subnet = config.homelab.networks.mikeway.lan.subnet;
          answer = config.homelab.networks.mikeway.lan.v4;
        }
        {
          name = "tailnet";
          interface = config.homelab.networks.mikeway.mesh.interface;
          listen = config.homelab.tailscale.address;
          subnet = config.homelab.networks.mikeway.mesh.subnet;
          answer = config.homelab.tailscale.address;
        }
      ];
    };
    cloudflared = {
      enable = true;
      tunnelId = "7a16d95b-031d-483f-befa-d8fdc081fe5c";
      expose."mpluta.dev" = [
        ""
        "www"
        "git"
      ];
    };
  };

  # Ingress Caddy: reachable from the LAN (tailnet is already a trusted interface,
  # public access arrives via the tunnel on loopback) but never served on the WAN.
  networking.firewall.interfaces.${config.homelab.networks.mikeway.lan.interface}.allowedTCPPorts = [
    80
    443
  ];

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
