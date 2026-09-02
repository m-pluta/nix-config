{
  lib,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "mikeway";

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  # _common defaults this off. Keep on until static WAN/LAN + nftables NAT
  # routing is in place, so the rebuild doesn't drop the network.
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  system.stateVersion = "25.11";
}
