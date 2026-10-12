{ config, lib, ... }:
let
  service = "vaultwarden";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8222;
    url = "pass.${hl.baseDomain}";
    configDir = "/var/lib/bitwarden_rs";
    homepage = {
      name = "Vaultwarden";
      description = "Password manager";
      icon = "bitwarden.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      ${service} = {
        enable = true;
        config = {
          DOMAIN = "https://${cfg.url}";
          SIGNUPS_ALLOWED = false;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = cfg.port;
          EXTENDED_LOGGING = true;
          LOG_LEVEL = "warn";
        };
      };
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
