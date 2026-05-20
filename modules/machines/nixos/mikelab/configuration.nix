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

  system.stateVersion = "25.11";

  boot.supportedFilesystems = [ "zfs" ];
  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };

  # AMD GPU
  hardware.graphics.enable = true;
  hardware.amdgpu.initrd.enable = true;
  hardware.enableRedistributableFirmware = true;

  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    libva-utils
    nvtopPackages.amd
  ];
}
