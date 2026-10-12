{ config, lib, ... }:
let
  service = "home-assistant";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8123;
    url = "hass.${hl.baseDomain}";
    configDir = "/var/lib/hass";
    homepage = {
      name = "Home Assistant";
      description = "Home automation platform";
      icon = "home-assistant.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
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
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };
}
