{
  disko.devices = {
    disk.system = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLQ512HBLU-00B_S6F1NF0T465334";
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
          swap = {
            size = "16G";
            content.type = "swap";
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      options.ashift = "12";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        mountpoint = "none";
      };
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options = {
            mountpoint = "/";
            "com.sun:auto-snapshot" = "true";
          };
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options = {
            mountpoint = "/nix";
            atime = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options."com.sun:auto-snapshot" = "true";
        };
        "services" = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            canmount = "off";
            "com.sun:auto-snapshot" = "false";
          };
        };
        "services/uptime-kuma" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/private/uptime-kuma";
          options."com.sun:auto-snapshot" = "true";
        };
        "services/kanidm" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/kanidm";
          options."com.sun:auto-snapshot" = "true";
        };
        "services/hass" = {
          type = "zfs_fs";
          mountpoint = "/var/lib/hass";
          options."com.sun:auto-snapshot" = "true";
        };
        "reserved" = {
          type = "zfs_fs";
          options = {
            reservation = "5G";
            canmount = "off";
            mountpoint = "none";
            "com.sun:auto-snapshot" = "false";
          };
        };
      };
    };
  };
}
