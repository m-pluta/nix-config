{ config, lib, ... }:
let
  service = "prowlarr";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 9696;
    url = "${service}.${homelab.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Prowlarr";
      description = "PVR indexer";
      icon = "prowlarr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
