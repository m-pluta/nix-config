{ config, inputs, ... }:
{
  age.secrets.wifi.file = "${inputs.secrets}/wifi.age";

  networking.firewall.enable = true;
  networking.firewall.checkReversePath = "loose";
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  networking.networkmanager.enable = false;
  networking.wireless = {
    enable = true;
    secretsFile = config.age.secrets.wifi.path;
    networks."ItHurtsWhenIP" = {
      pskRaw = "ext:PSK_HOME";
    };
  };

  programs.mosh.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      ClientAliveInterval = 60;
      ClientAliveCountMax = 5;
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
  };
}
