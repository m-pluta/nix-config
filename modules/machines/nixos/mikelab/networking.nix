{ config, inputs, ... }:
{
  age.secrets.wifi.file = "${inputs.secrets}/wifi.age";

  networking = {
    firewall = {
      enable = true;
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
    };
    wireless = {
      enable = true;
      secretsFile = config.age.secrets.wifi.path;
      networks."ItHurtsWhenIP" = {
        pskRaw = "ext:PSK_HOME";
      };
    };
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
  };
}
