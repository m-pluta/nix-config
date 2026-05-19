{
  config,
  pkgs,
  ...
}:
{
  networking.hostName = "mikelab";
  networking.hostId = "deadbeef";
  time.timeZone = "Europe/London";
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
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  zramSwap.enable = true;

  # Secrets
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  # Programs
  programs.git.enable = true;
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    btop
    wget
    curl
    rsync
    tree
    pciutils
    usbutils
    smartmontools
    iperf3
    eza
    fastfetch
    tmux
    ncdu
    nmap
    jq
    ripgrep
    lm_sensors
    libva-utils
    nvtopPackages.amd
  ];
}
