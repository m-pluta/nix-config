{ config, lib, ... }:
let
  zfsFilesystems = lib.attrsets.filterAttrs (_n: v: v.fsType == "zfs") config.fileSystems;
  zfsEnabled = zfsFilesystems != { };
in
{
  # imports = [ ./snapraid.nix ];
  disko.zfs.enable = true;

  services = lib.mkIf zfsEnabled {
    zfs = {
      autoScrub.enable = true;
      trim.enable = true;
    };
  };
}
