{ ... }:

{
  # add zfs kernel modules and userspace tools
  boot.supportedFilesystems = [ "zfs" ];

  # reconcile zfs datasets on every rebuild from disko config
  disko.zfs.enable = true;

  services.zfs = {
    # Snapshots can be disabled per-dataset with com.sun:auto-snapshot=false property
    autoSnapshot = {
      enable = true;
      frequent = 4; # every 15 min
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
    # periodic TRIM for SSDs, runs weekly by default
    trim.enable = true;
    # periodic data integrity scrub, runs monthly by default
    autoScrub.enable = true;
  };
}
