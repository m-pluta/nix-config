{ config, lib, ... }:
let
  service = "uptime-kuma";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 3001;
    url = "uptime.${homelab.baseDomain}";
    configDir = "/var/lib/uptime-kuma";
    homepage = {
      name = "Uptime Kuma";
      description = "Service monitoring tool";
      icon = "uptime-kuma.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
