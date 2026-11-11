{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "grafana";
  serviceLib = import ../../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 3000;
    url = "grafana.${hl.mainDomain}";
    homepage = {
      name = "Grafana";
      description = "Platform for data analytics and monitoring";
      icon = "grafana.svg";
      category = "Observability";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets."${service}-secret-key".file = "${inputs.secrets}/services/${service}/secret-key.age";
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    # systemd hands Grafana a private copy of the key at each start.
    systemd.services.grafana.serviceConfig.LoadCredential = [
      "secret-key:${config.age.secrets."${service}-secret-key".path}"
      "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}"
    ];
    homelab.sso.clients.${service} = {
      displayName = "Grafana";
      originUrl = "https://${cfg.url}/login/generic_oauth";
      originLanding = "https://${cfg.url}/";
    };
    services.grafana = {
      enable = true;
      provision = {
        enable = true;
        dashboards.settings.providers = [
          {
            name = "nix-config";
            options.path = ./dashboards;
          }
        ];
      };
      settings = {
        security.secret_key = "$__file{/run/credentials/grafana.service/secret-key}";
        server = {
          http_addr = "127.0.0.1";
          http_port = cfg.port;
          domain = cfg.url;
          root_url = "https://${cfg.url}/";
        };
        "auth.generic_oauth" =
          let
            kanidm = "https://${hl.services.kanidm.url}";
          in
          {
            enabled = true;
            name = "Kanidm";
            client_id = service;
            client_secret = "$__file{/run/credentials/grafana.service/kanidm-secret}";
            scopes = "openid profile email";
            auth_url = "${kanidm}/ui/oauth2";
            token_url = "${kanidm}/oauth2/token";
            api_url = "${kanidm}/oauth2/openid/${service}/userinfo";
            use_pkce = true;
            use_refresh_token = true;
            login_attribute_path = "preferred_username";
            allow_sign_up = true;
          };
      };
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
