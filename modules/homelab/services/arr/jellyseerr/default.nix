{
  config,
  lib,
  ...
}:
let
  service = "jellyseerr";
  serviceLib = import ../../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 5055;
    url = "${service}.${hl.baseDomain}";
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
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
