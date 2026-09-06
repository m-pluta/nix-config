{ config, lib, ... }:
let
  service = "lidarr";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8686;
    url = "${service}.${homelab.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Lidarr";
      description = "Music collection manager";
      icon = "lidarr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service}.enable = true;
    users.users.${service}.extraGroups = [ "media" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };
}
