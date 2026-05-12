{
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = { type = "zfs"; pool = "rpool"; };
            };
          };
        };
      };
      data = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = { type = "zfs"; pool = "tank"; };
            };
          };
        };
      };
    };
    zpool = {
      rpool = {
        type = "zpool";
        options.ashift = "12";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          mountpoint = "none";
        };
        datasets = {
          "root" = { type = "zfs_fs"; mountpoint = "/"; };
          "nix"  = { type = "zfs_fs"; mountpoint = "/nix"; options.atime = "off"; };
          "home" = { type = "zfs_fs"; mountpoint = "/home"; };
        };
      };
      tank = {
        type = "zpool";
        options.ashift = "12";
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          mountpoint = "none";
        };
        datasets = {
          "data" = { type = "zfs_fs"; mountpoint = "/tank"; };
        };
      };
    };
  };
}
