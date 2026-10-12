{ config, lib, ... }:
let
  service = "sonarr";
  serviceLib = import ../../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8989;
    url = "${service}.${hl.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Sonarr";
      description = "TV show collection manager";
      icon = "sonarr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service}.enable = true;
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
