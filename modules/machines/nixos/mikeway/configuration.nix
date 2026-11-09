{
  config,
  ...
}:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./routing.nix
  ];

  networking.hostName = "mikeway";

  homelab = {
    enable = true;
    description = "Router and network gateway";
    tailscale.enable = true;
    # Split-horizon DNS: each homelab name resolves to its host's address on the
    # client's network.
    splitDns.enable = true;
    sites."mpluta.dev" = { };
    cloudflared = {
      enable = true;
      expose.${config.homelab.mainDomain} = [
        ""
        "www"
      ];
      tunnelId = "4874c13d-f0db-4b6a-a5dc-bd8e6d06bb82";
    };
  };

  networking.hostId = "f859d24b";
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = true;
  services.zfs.autoSnapshot = {
    enable = true;
    frequent = 4;
    hourly = 24;
    daily = 7;
    weekly = 4;
    monthly = 12;
  };

  system.stateVersion = "25.11";
}
