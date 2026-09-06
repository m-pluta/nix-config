{
  lib,
  config,
  inputs,
  ...
}:
let
  service = "attic";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8070;
    url = "cache.${hl.baseDomain}";
    monitoredServices = [ "atticd" ];
    homepage = {
      name = "Attic";
      description = "Nix binary cache";
      icon = "nixos.svg";
      category = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."${service}-token".file = "${inputs.secrets}/services/${service}/token.age";

    services.atticd = {
      enable = true;
      environmentFile = config.age.secrets."${service}-token".path;
      settings = {
        listen = "127.0.0.1:${toString cfg.port}";
        allowed-hosts = [ cfg.url ];
        api-endpoint = "https://${cfg.url}/";
        jwt = { };
        storage = {
          type = "local";
          path = "/var/lib/atticd/storage";
        };
        garbage-collection = {
          interval = "24 hours";
          default-retention-period = "6 months";
        };
      };
    };

    homelab.ingress.routes.${cfg.url} = {
      port = cfg.port;
      extraConfig = ''
        request_body {
          max_size 50GB
        }
      '';
    };
  };
}
