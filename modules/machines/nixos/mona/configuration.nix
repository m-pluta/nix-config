{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./desktop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  nixpkgs.config.allowUnfree = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "virtio_pci"
    "usbhid"
    "usb_storage"
    "sr_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/7d2c6e9b-70c1-4abb-859c-7a5f0afc06f3";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1B83-ECE3";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/41059ca6-49c4-4790-8379-cf34ec5a7bdc"; }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  services = {
    openssh.enable = true;
    qemuGuest.enable = true;
  };

  networking = {
    networkmanager.enable = true;
    hostName = "mona";
    hostId = "3bd395cc";
  };

  system.stateVersion = lib.mkForce "25.11";
  services.printing.enable = true;
}
