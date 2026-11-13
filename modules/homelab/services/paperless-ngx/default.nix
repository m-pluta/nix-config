{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "paperless";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  # Memory-only directory for the Kanidm settings.
  # Not a RuntimeDirectory, because systemd removes that when the unit ends.
  kanidmEnvDir = "/run/${service}-kanidm";
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 28981;
    url = "${service}.${hl.mainDomain}";
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
    age.secrets."${service}-admin-password".file =
      "${inputs.secrets}/services/${service}/admin-password.age";
    services.${service} = {
      enable = true;
      port = cfg.port;
      passwordFile = config.age.secrets."${service}-admin-password".path;
      consumptionDirIsPublic = true;
      environmentFile = "${kanidmEnvDir}/env";
      settings = {
        PAPERLESS_URL = "https://${cfg.url}";
        PAPERLESS_OCR_LANGUAGE = "eng";
        # Load the OpenID Connect login provider of allauth
        PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
        PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
        PAPERLESS_DISABLE_REGULAR_LOGIN = true;
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
      };
    };
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    homelab.sso.clients.${service} = {
      displayName = "Paperless";
      originUrl = "https://${cfg.url}/accounts/oidc/kanidm/login/callback/";
      originLanding = "https://${cfg.url}/";
    };
    # Paperless's Kanidm provider settings, which hold the client secret
    systemd.services."${service}-kanidm-env" = {
      description = "Write Paperless's Kanidm provider settings";
      before = [ "paperless-scheduler.service" ];
      requiredBy = [ "paperless-scheduler.service" ];
      environment = {
        CLIENT_ID = service;
        ENV_DIR = kanidmEnvDir;
        SERVER_URL = "https://${hl.services.kanidm.url}/oauth2/openid/${service}";
      };
      serviceConfig = {
        Type = "oneshot";
        User = config.services.${service}.user;
        LoadCredential = [ "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}" ];
        ExecStart = lib.getExe (
          pkgs.writeShellApplication {
            name = "${service}-kanidm-env";
            runtimeInputs = [ pkgs.jq ];
            text = builtins.readFile ./kanidm-env.sh;
          }
        );
      };
    };
    systemd.tmpfiles.rules = [
      "d /var/lib/${service} 0700 ${service} ${service} - -"
      # Made at boot and not by the unit, so it stays when the unit ends.
      "d ${kanidmEnvDir} 0700 ${service} ${service} - -"
    ];
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
