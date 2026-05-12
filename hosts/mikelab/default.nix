{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/boot.nix
    ../../modules/zfs.nix
    ../../modules/networking.nix
    ../../modules/nix-settings.nix
    ../../modules/users.nix
  ];

  # Host identity
  networking.hostName = "mikelab";
  networking.hostId = "deadbeef";
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  # Host-level packages
  environment.systemPackages = with pkgs; [
    git vim neovim helix htop btop tmux wget curl rsync tree
    pciutils usbutils smartmontools
  ];

  system.stateVersion = "25.11";
}
