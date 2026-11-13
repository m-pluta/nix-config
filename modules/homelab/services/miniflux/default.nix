{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "miniflux";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8067;
    url = "news.${hl.mainDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Miniflux";
      description = "Minimalist and opinionated feed reader";
      icon = "miniflux-light.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets."${service}-admin-credentials".file =
      "${inputs.secrets}/services/${service}/admin-credentials.age";
    services.${service} = {
      enable = true;
      adminCredentialsFile = config.age.secrets."${service}-admin-credentials".path;
      config = {
        BASE_URL = "https://${cfg.url}";
        CREATE_ADMIN = true;
        LISTEN_ADDR = "127.0.0.1:${toString cfg.port}";
        OAUTH2_PROVIDER = "oidc";
        OAUTH2_OIDC_PROVIDER_NAME = "Kanidm";
        OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://${hl.services.kanidm.url}/oauth2/openid/${service}";
        OAUTH2_CLIENT_ID = service;
        OAUTH2_CLIENT_SECRET_FILE = "/run/credentials/${service}.service/kanidm-secret";
        OAUTH2_REDIRECT_URL = "https://${cfg.url}/oauth2/oidc/callback";
        OAUTH2_USER_CREATION = 1;
      };
    };
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    systemd.services.${service}.serviceConfig.LoadCredential = [
      "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}"
    ];
    homelab.sso.clients.${service} = {
      displayName = "Miniflux";
      originUrl = "https://${cfg.url}/oauth2/oidc/callback";
      originLanding = "https://${cfg.url}/";
    };
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
