{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./networking.nix
    ./homelab.nix
  ];
  networking.hostName = "mikelab";
  networking.hostId = "deadbeef";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  system.stateVersion = "25.11";

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 0;
  boot.tmp.cleanOnBoot = true;

  # ZFS
  boot.supportedFilesystems = [ "zfs" ];
  disko.zfs.enable = true;
  services.zfs = {
    autoSnapshot = {
      enable = true;
      frequent = 4;
      hourly = 24;
      daily = 7;
      weekly = 4;
      monthly = 12;
    };
    trim.enable = true;
    autoScrub.enable = true;
  };

  # AMD GPU
  hardware.graphics.enable = true;
  hardware.amdgpu.initrd.enable = true;
  hardware.enableRedistributableFirmware = true;

  # Nix
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];
  zramSwap.enable = true;

  # Secrets
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  environment.systemPackages = with pkgs; [
    btop
    curl
    tree
    pciutils
    usbutils
    smartmontools
    libva-utils
    nvtopPackages.amd
  ];
}
