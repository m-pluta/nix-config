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
    age.secrets."${service}-secret-key" = {
      file = "${inputs.secrets}/services/${service}/secret-key.age";
      owner = service;
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
        security.secret_key = "$__file{${config.age.secrets."${service}-secret-key".path}}";
        server = {
          http_addr = "127.0.0.1";
          http_port = cfg.port;
          domain = cfg.url;
        };
      };
    };
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
