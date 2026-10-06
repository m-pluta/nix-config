{
  config,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./routing.nix
  ];

  networking.hostName = "mikeway";

  homelab = {
    enable = true;
    description = "Router, network gateway, and homelab ingress host";
    tailscale.enable = true;
    # Split-horizon DNS: Unbound picks a view by the client's source subnet, so
    # the main domain resolves to the LAN IP on the LAN and the tailnet IP over tailscale.
    splitDns = {
      enable = true;
      domains = [ config.homelab.mainDomain ];
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
      expose.${config.homelab.mainDomain} = [
        ""
        "www"
        "git"
      ];
    };
  };

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
