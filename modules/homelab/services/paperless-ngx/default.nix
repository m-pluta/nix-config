{ config, lib, inputs, pkgs, ... }:
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
    };
  config = lib.mkIf cfg.enable {
    age.secrets.paperless-password.file = "${inputs.secrets}/services/paperless/password.age";
    # TODO: remove once upstream nixpkgs fixes paperless-ngx consumer test failures
    nixpkgs.overlays = [
      (_final: prev: {
        paperless-ngx = prev.paperless-ngx.overrideAttrs (old: {
          disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [
            "src/documents/tests/test_management_consumer.py"
          ];
        });
      })
    ];
    services.${service} = {
      enable = true;
      port = cfg.port;
      passwordFile = config.age.secrets.paperless-password.path;
      consumptionDirIsPublic = true;
      settings = {
        PAPERLESS_URL = "https://${cfg.url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
