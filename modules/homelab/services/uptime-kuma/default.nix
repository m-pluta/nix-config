{ config, lib, ... }:
let
  service = "uptime-kuma";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 3001;
    url = "uptime.${hl.baseDomain}";
    configDir = "/var/lib/${service}";
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
      settings.PORT = toString cfg.port;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
