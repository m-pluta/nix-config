{ config, lib, ... }:
let
  service = "vaultwarden";
  serviceLib = import ../lib.nix { inherit lib; };
  homelab = config.homelab;
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8222;
    url = "pass.${homelab.baseDomain}";
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
      fail2ban-cloudflare = lib.mkIf config.services.fail2ban-cloudflare.enable {
        jails = {
          vaultwarden = {
            serviceName = "vaultwarden";
            failRegex = "^.*Username or password is incorrect. Try again. IP: <HOST>. Username: <F-USER>.*</F-USER>.$";
          };
        };
      };
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
      caddy.virtualHosts."${cfg.url}" = {
        useACMEHost = homelab.baseDomain;
        extraConfig = ''
          reverse_proxy http://127.0.0.1:${toString cfg.port}
        '';
      };
    };
  };

}
