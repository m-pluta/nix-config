{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/boot.nix
    ../../modules/networking.nix
    ../../modules/nix-settings.nix
    ../../modules/tailscale.nix
    ../../modules/users.nix
    ../../modules/zfs.nix
    ../../modules/services/monitoring.nix
  ];

  # Host identity
  networking.hostName = "mikelab";
  networking.hostId = "deadbeef";
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  # Firmware blobs for wifi + AMD CPU microcode updates
  hardware.enableRedistributableFirmware = true;

  programs.git.enable = true;
  programs.tmux.enable = true;

  # Host-level packages
  environment.systemPackages = with pkgs; [
    vim
    neovim
    helix
    htop
    btop
    wget
    curl
    rsync
    tree
    pciutils
    usbutils
    smartmontools
  ];

  system.stateVersion = "25.11";
}
