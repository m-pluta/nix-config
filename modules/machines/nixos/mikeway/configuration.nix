{
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
    description = "Router and network gateway";
    tailscale.enable = true;
    # Split-horizon DNS: each homelab name resolves to its host's address on the
    # client's network.
    splitDns.enable = true;
    cloudflared = {
      enable = true;
      tunnelId = "4874c13d-f0db-4b6a-a5dc-bd8e6d06bb82";
    };
  };

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
