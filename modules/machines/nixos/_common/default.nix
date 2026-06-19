{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./filesystems
    ./nix
  ];

  i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";
  console.keyMap = lib.mkDefault "uk";
  time.timeZone = lib.mkDefault "Europe/London";

  boot = {
    loader.systemd-boot.enable = lib.mkDefault true;
    loader.systemd-boot.configurationLimit = lib.mkDefault 10;
    loader.efi.canTouchEfiVariables = lib.mkDefault true;
    loader.timeout = lib.mkDefault 0;
    tmp.cleanOnBoot = lib.mkDefault true;
  };

  networking.nameservers = lib.mkDefault [
    "1.1.1.1"
    "8.8.8.8"
  ];
  networking.networkmanager.enable = lib.mkDefault false;
  networking.firewall.enable = lib.mkDefault true;

  services.ntp.enable = lib.mkDefault true;

  services.openssh = {
    enable = lib.mkDefault true;
    openFirewall = lib.mkDefault true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      LoginGraceTime = 0;
      PermitRootLogin = "no";
      ClientAliveInterval = lib.mkDefault 60;
      ClientAliveCountMax = lib.mkDefault 5;
    };
    ports = [ 22 ];
  };

  security = {
    doas.enable = lib.mkDefault false;
    sudo = {
      enable = lib.mkDefault true;
      wheelNeedsPassword = false;
    };
  };

  programs.git.enable = lib.mkDefault true;
  programs.mosh.enable = lib.mkDefault true;
  programs.htop.enable = lib.mkDefault true;
  programs.neovim = {
    enable = lib.mkDefault true;
    viAlias = lib.mkDefault true;
    vimAlias = lib.mkDefault true;
    defaultEditor = lib.mkDefault true;
  };

  # services.autoaspm.enable = lib.mkDefault true;
  # powerManagement.powertop.enable = lib.mkDefault true;

  homelab.motd.enable = lib.mkDefault true;

  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };

  environment.systemPackages = with pkgs; [
    # Shell essentials
    jq
    ripgrep
    tmux
    tree

    # Networking
    curl
    wget
    iperf3
    nmap
    rsync

    # System monitoring
    btop
    fastfetch
    iotop
    lm_sensors
    ncdu

    # Hardware diagnostics
    pciutils
    usbutils
    smartmontools
  ];
}
