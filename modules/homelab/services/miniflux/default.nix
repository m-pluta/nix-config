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
    url = "news.${hl.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Miniflux";
      description = "Minimalist and opinionated feed reader";
      icon = "miniflux-light.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets.miniflux-admin-credentials.file = "${inputs.secrets}/services/miniflux/admin-credentials.age";
    services.${service} = {
      enable = true;
      adminCredentialsFile = config.age.secrets.miniflux-admin-credentials.path;
      config = {
        BASE_URL = "https://${cfg.url}";
        CREATE_ADMIN = true;
        LISTEN_ADDR = "127.0.0.1:${toString cfg.port}";
      };
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
