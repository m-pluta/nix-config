{
  config,
  pkgs,
  ...
}:
let
  wardrobe = builtins.fromJSON ''"Native King\u2019s Wardrobe"'';
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ./homelab.nix
  ];
  networking.hostName = "mikelab";
  networking.hostId = "deadbeef";
  wifi = {
    enable = true;
    ssids = [
      wardrobe
      "VM8776666"
      "loopback"
      "ItHurtsWhenIP"
    ];
  };
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
  services.iperf3 = {
    enable = true;
    openFirewall = true;
  };
  # AMD GPU
  hardware.graphics.enable = true;
  hardware.amdgpu.initrd.enable = true;
  hardware.enableRedistributableFirmware = true;
  # NVIDIA GPU
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Pascal predates the open kernel modules, which need Turing or newer
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Keeps the driver initialised with no display client attached
    nvidiaPersistenced = true;
    nvidiaSettings = false;
  };
  zramSwap.enable = true;
  environment.systemPackages = with pkgs; [
    libva-utils
    nvtopPackages.full
    rocmPackages.rocm-smi
  ];
}
