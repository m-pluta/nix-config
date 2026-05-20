{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./filesystems
    ./nix
    #"${inputs.secrets}/networks.nix"
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

  services.ntp.enable = true;

  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      LoginGraceTime = 0;
      PermitRootLogin = "no";
    };
    ports = [ 22 ];
  };

  security = {
    doas.enable = lib.mkDefault false;
    sudo = {
      enable = lib.mkDefault true;
      wheelNeedsPassword = lib.mkDefault false;
    };
  };

  programs.git.enable = true;
  programs.mosh.enable = true;
  programs.htop.enable = true;
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
  };

  homelab.motd.enable = true;

  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
    # secrets = {
    #   hashedUserPassword.file = "${inputs.secrets}/hashedUserPassword.age";
    #   smtpPassword = {
    #     file = "${inputs.secrets}/smtpPassword.age";
    #     owner = "notthebee";
    #     group = "notthebee";
    #     mode = "0440";
    #   };
    # };
  };

  # email = {
  #   enable = true;
  #   fromAddress = "moe@notthebe.ee";
  #   toAddress = "server_announcements@mailbox.org";
  #   smtpServer = "email-smtp.eu-west-1.amazonaws.com";
  #   smtpUsername = "AKIAYYXVLL34J7LSXFZF";
  #   smtpPasswordPath = config.age.secrets.smtpPassword.path;
  # };

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
