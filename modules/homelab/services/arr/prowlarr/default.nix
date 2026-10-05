{ config, lib, ... }:
let
  service = "prowlarr";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = hl.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 9696;
    url = "${service}.${hl.baseDomain}";
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
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
