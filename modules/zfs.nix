{ ... }:

{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;

  services.zfs = {
    autoSnapshot.enable = true;
    trim.enable = true;
    autoScrub.enable = true;
  };
}
