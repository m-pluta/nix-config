{
  config,
  lib,
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
    url = "news.goose.party";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Miniflux";
      description = "Minimalist and opinionated feed reader";
      icon = "miniflux-light.svg";
      category = "Services";
    };
  } // {
    adminCredentialsFile = lib.mkOption {
      description = "File with admin credentials";
      type = lib.types.path;
    };
    role = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      default = "client";
    };
  };
  config =
    let
      mkIfElse =
        p: yes: no:
        lib.mkMerge [
          (lib.mkIf p yes)
          (lib.mkIf (!p) no)
        ];
      addr = "127.0.0.1";
    in
    mkIfElse (cfg.role == "client")
      (lib.mkIf cfg.enable {
        services.${service} = {
          enable = true;
          adminCredentialsFile = cfg.adminCredentialsFile;
          config = {
            BASE_URL = "https://${cfg.url}";
            CREATE_ADMIN = true;
            LISTEN_ADDR = "${addr}:${toString cfg.port}";
            OAUTH2_PROVIDER = "oidc";
            OAUTH2_CLIENT_ID = "miniflux";
            OAUTH2_REDIRECT_URL = "https://${cfg.url}/oauth2/oidc/callback";
            OAUTH2_OIDC_DISCOVERY_ENDPOINT = "https://${hl.services.keycloak.url}/realms/master";
            OAUTH2_USER_CREATION = "1";
            DISABLE_LOCAL_AUTH = "true";
          };
        };
        services.frp.settings.proxies = [
          {
            name = service;
            type = "tcp";
            localIP = addr;
            localPort = cfg.port;
            remotePort = cfg.port;
          }
        ];
      })
      {
        services.caddy.virtualHosts."${cfg.url}" = {
          useACMEHost = "goose.party";
          extraConfig = ''
            reverse_proxy http://${addr}:${toString cfg.port}
          '';
        };
      };
}
