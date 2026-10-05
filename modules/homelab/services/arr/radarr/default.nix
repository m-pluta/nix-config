{ config, lib, ... }:
let
  service = "radarr";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = hl.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 7878;
    url = "${service}.${hl.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Radarr";
      description = "Movie collection manager";
      icon = "radarr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service}.enable = true;
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
