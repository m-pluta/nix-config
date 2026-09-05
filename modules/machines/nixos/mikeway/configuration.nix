{
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
    description = "Router and network gateway";
  };

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  services.tailscale.enable = true;

  system.stateVersion = "25.11";
}
