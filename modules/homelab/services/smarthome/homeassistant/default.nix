{ config, lib, ... }:
let
  service = "home-assistant";
  serviceLib = import ../../lib.nix { inherit lib; };
  homelab = config.homelab;
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8123;
    url = "hass.${homelab.baseDomain}";
    configDir = "/var/lib/hass";
    homepage = {
      name = "Home Assistant";
      description = "Home automation platform";
      icon = "home-assistant.svg";
      category = "Smart Home";
    };
  };
  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;
      configDir = cfg.configDir;
      extraComponents = [
        # "analytics"
        # "google_translate"
        # "met"
        # "radio_browser"
        # "shopping_list"
        "isal"
      ];
      config = {
        default_config = { };
        http = {
          server_port = cfg.port;
          use_x_forwarded_for = true;
          trusted_proxies = [
            "127.0.0.1"
            "::1"
          ];
        };
      };
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
