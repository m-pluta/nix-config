{ config, lib, ... }:
let
  service = "paperless";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 28981;
      url = "paperless.${homelab.baseDomain}";
      configDir = "/var/lib/${service}";
      monitoredServices = [
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
        "paperless-web"
      ];
      homepage = {
        name = "Paperless-ngx";
        description = "Document management system";
        icon = "paperless.svg";
        category = "Services";
      };
    }
    // {
      mediaDir = lib.mkOption {
        type = lib.types.str;
        default = "${homelab.mounts.fast}/Documents/Paperless/Documents";
      };
      consumptionDir = lib.mkOption {
        type = lib.types.str;
        default = "${homelab.mounts.fast}/Documents/Paperless/Import";
      };
      passwordFile = lib.mkOption {
        type = lib.types.path;
      };
    };
  config = lib.mkIf cfg.enable {
    users.users.${service}.extraGroups = [ "media" ];
    services = {
      ${service} = {
        enable = true;
        port = cfg.port;
        passwordFile = cfg.passwordFile;
        mediaDir = cfg.mediaDir;
        consumptionDir = cfg.consumptionDir;
        consumptionDirIsPublic = true;
        settings = {
          PAPERLESS_URL = "https://${cfg.url}";
          PAPERLESS_CONSUMER_IGNORE_PATTERN = [
            ".DS_STORE/*"
            "desktop.ini"
          ];
          PAPERLESS_OCR_LANGUAGE = "deu+eng";
          PAPERLESS_OCR_USER_ARGS = {
            optimize = 1;
            pdfa_image_compression = "lossless";
          };
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
