{
  disko.devices = {
    disk = {
      system = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-KINGSTON_SA2000M8250G_50026B76846156F0";
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
                # umask=0077 so only root can read /boot contents
                mountOptions = [ "umask=0077" ];
              };
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
      data = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-ADATA_SX8200PNP_2K452L1N5EEP";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      };
    };

    zpool = {
      rpool = {
        type = "zpool";
        # 4K sector alignment, correct for all modern NVMe/SSD, 2^12 Bytes
        options.ashift = "12";
        # inherited by all child datasets unless overridden
        # Datasets inherit all FS options from the root
        rootFsOptions = {
          compression = "zstd";
          # posix ACLs stored in extended attributes, NixOS standard
          acltype = "posixacl";
          xattr = "sa";
          # pool root not mountable, only specified datasets are
          mountpoint = "none";
        };
        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options."com.sun:auto-snapshot" = "true";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              # nix store is read from constantly, atime updates are wasted writes
              atime = "off";
              # store is rebuildable from the flake, snapshots waste space
              "com.sun:auto-snapshot" = "false";
            };
          };
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options."com.sun:auto-snapshot" = "true";
          };
          # carves out space nothing can use, keeps pool from hitting 100%
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
          "services" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              canmount = "off";
              "com.sun:auto-snapshot" = "false";
            };
          };
          "services/grafana" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/grafana";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/victoriametrics" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/victoriametrics";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/forgejo" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/forgejo";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/jellyfin" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/jellyfin";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/sonarr" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/sonarr";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/radarr" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/radarr";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/prowlarr" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/prowlarr";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/bazarr" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/bazarr";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/jellyseerr" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/jellyseerr";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/sabnzbd" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/sabnzbd";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/deluge" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/deluge";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/uptime-kuma" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/uptime-kuma";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/hass" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/hass";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/immich" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/immich";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/vaultwarden" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/vaultwarden";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/navidrome" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/navidrome";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/microbin" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/microbin";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/paperless" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/paperless";
            options."com.sun:auto-snapshot" = "true";
          };
          "services/attic" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/private/atticd";
            options = {
              "com.sun:auto-snapshot" = "true";
              quota = "50G";
            };
          };
          "services/nextcloud" = {
            type = "zfs_fs";
            mountpoint = "/var/lib/nextcloud";
            options."com.sun:auto-snapshot" = "true";
          };
          "photos" = {
            type = "zfs_fs";
            mountpoint = "/tank/photos";
            options = {
              "com.sun:auto-snapshot" = "true";
              recordsize = "1M";
            };
          };
          "media" = {
            type = "zfs_fs";
            mountpoint = "/tank/media";
            options = {
              "com.sun:auto-snapshot" = "false";
              recordsize = "1M";
            };
          };
          # carves out space nothing can use, keeps pool from hitting 100%
          "reserved" = {
            type = "zfs_fs";
            options = {
              reservation = "20G";
              canmount = "off";
              mountpoint = "none";
              "com.sun:auto-snapshot" = "false";
            };
          };
        };
      };
    };
  };
}
