{
  pkgs,
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
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 5055;
      url = "${service}.${homelab.baseDomain}";
      homepage = {
        name = "Jellyseerr";
        description = "Media request and discovery manager";
        icon = "jellyseerr.svg";
        category = "Arr";
      };
    }
    // {
      package = lib.mkPackageOption pkgs "jellyseerr" { };
    };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.port;
      package = cfg.package;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
