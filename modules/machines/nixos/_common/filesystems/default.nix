{ config, lib, ... }:
let
  zfsFilesystems = lib.attrsets.filterAttrs (_n: v: v.fsType == "zfs") config.fileSystems;
  zfsEnabled = zfsFilesystems != { };
  zfsPools = lib.unique (
    map (fs: lib.head (lib.splitString "/" fs.device)) (lib.attrValues zfsFilesystems)
  );
in
{
  disko.zfs.enable = true;

  services = lib.mkIf zfsEnabled {
    zfs = {
      autoScrub.enable = true;
      trim.enable = true;
    };
  };

  # Keep pools imported across switches
  systemd.services = lib.genAttrs (map (pool: "zfs-import-${pool}") zfsPools) (_: {
    restartIfChanged = false;
  });
}
