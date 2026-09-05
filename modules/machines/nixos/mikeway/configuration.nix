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
    tailscale = {
      enable = true;
      address = "100.67.111.121";
    };
  };

  # No ZFS on this box (ext4 root); _common/filesystems forces it on.
  disko.zfs.enable = lib.mkForce false;

  system.stateVersion = "25.11";
}
