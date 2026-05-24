{ config, lib, ... }:
let
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.radicale;
  homelab = config.homelab;
in
{
  options.homelab.services.radicale =
    serviceLib.mkServiceOptions {
      port = 5232;
      url = "cal.${homelab.baseDomain}";
      homepage = {
        name = "Radicale";
        description = "Free and Open-Source CalDAV and CardDAV Server";
        icon = "radicale.svg";
        category = "Services";
      };
    }
    // {
      passwordFile = lib.mkOption {
        description = "Path to Radicale user credentials";
        type = lib.types.path;
      };
    };
  config = lib.mkIf cfg.enable {
    systemd.services.radicale.serviceConfig.LoadCredential = "radicale.htpasswd:${cfg.passwordFile}";
    services.radicale = {
      enable = true;
      extraArgs = [
        "--auth-htpasswd-filename=%d/radicale.htpasswd"
        "--auth-htpasswd-encryption=plain"
      ];
      settings = {
        server = {
          hosts = [
            "127.0.0.1:${toString cfg.port}"
          ];
        };
        storage = {
          filesystem_folder = "/var/lib/radicale/collections";
        };

        auth = {
          type = "htpasswd";
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
