{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  service = "nextcloud";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8009;
      url = "cloud.${hl.baseDomain}";
      configDir = "/var/lib/${service}";
      monitoredServices = [
        "phpfpm-nextcloud"
      ];
      homepage = {
        name = "Nextcloud";
        description = "File sync and sharing";
        icon = "nextcloud.svg";
        category = "Services";
      };
    }
    // {
      admin.username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
      };
    };
  config = lib.mkIf cfg.enable {
    age.secrets.nextcloud-admin-password = {
      file = "${inputs.secrets}/services/nextcloud/password.age";
      owner = "nextcloud";
    };
    # Nextcloud requires nginx internally as its PHP-FPM frontend
    services.nginx.virtualHosts."nix-nextcloud".listen = [
      {
        addr = "127.0.0.1";
        port = cfg.port;
      }
    ];
    services.nextcloud = {
      enable = true;
      hostName = "nix-nextcloud";
      package = pkgs.nextcloud32;
      database.createLocally = true;
      configureRedis = true;
      maxUploadSize = "16G";
      https = true;
      settings = {
        overwriteprotocol = "https";
        overwritehost = cfg.url;
        default_phone_region = "GB";
        trusted_domains = [ cfg.url ];
      };
      config = {
        dbtype = "pgsql";
        adminuser = cfg.admin.username;
        adminpassFile = config.age.secrets.nextcloud-admin-password.path;
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
