{
  config,
  lib,
  ...
}:
let
  service = "jellyseerr";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 5055;
    url = "${service}.${homelab.baseDomain}";
    homepage = {
      name = "Jellyseerr";
      description = "Media request and discovery manager";
      icon = "jellyseerr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.port;
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
