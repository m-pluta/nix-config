{
  # Mirrors the existing layout. Partition and filesystem labels match what is on the
  # disk, since disko mounts by partition label. Swap is bigger than the current 8.8G
  # partition, so only a rebuild gets 16G.
  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-SAMSUNG_MZVLQ512HBLU-00B_S6F1NF0T465334";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          label = "EFI";
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };
        swap = {
          label = "swap";
          size = "16G";
          content = {
            type = "swap";
          };
        };
        root = {
          label = "root";
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
