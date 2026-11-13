{
  lib,
  config,
  inputs,
  ...
}:
let
  service = "oauth2-proxy";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  credentials = "/run/credentials/${service}.service";
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 4180;
    url = "auth.${hl.mainDomain}";
    homepage = {
      name = "Login proxy";
      description = "Kanidm login in front of services";
      icon = "oauth2-proxy.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    age.secrets."${service}-cookie-secret".file =
      "${inputs.secrets}/services/${service}/cookie-secret.age";
    homelab.sso.clients.${service} = {
      displayName = "Login proxy";
      originUrl = "https://${cfg.url}/oauth2/callback";
      originLanding = "https://${hl.services.homepage.url}/";
    };
    services.oauth2-proxy = {
      enable = true;
      provider = "oidc";
      clientID = service;
      clientSecretFile = "${credentials}/kanidm-secret";
      oidcIssuerUrl = "https://${hl.services.kanidm.url}/oauth2/openid/${service}";
      redirectURL = "https://${cfg.url}/oauth2/callback";
      httpAddress = "http://127.0.0.1:${toString cfg.port}";
      scope = "openid email profile";
      email.domains = [ "*" ];
      cookie = {
        domain = ".${hl.mainDomain}";
        secretFile = "${credentials}/cookie-secret";
        secure = true;
      };
      reverseProxy = true;
      setXauthrequest = true;
      upstream = [ "static://202" ];
      extraConfig = {
        code-challenge-method = "S256";
        whitelist-domain = ".${hl.mainDomain}";
        skip-provider-button = true;
        insecure-oidc-allow-unverified-email = true;
      };
    };
    # systemd hands oauth2-proxy private copies of the secrets at each start.
    systemd.services.${service}.serviceConfig.LoadCredential = [
      "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}"
      "cookie-secret:${config.age.secrets."${service}-cookie-secret".path}"
    ];
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
      forwardAuth = false;
    };
  };
}
