{
  lib,
  config,
  ...
}:
let
  service = "plausible";
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "numbers.${hl.baseDomain}";
    };
    secretKeybaseFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''
        pkgs.writeText "keybase.txt" '''
          foobar
        '''
      '';
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "Plausible";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Open-source web analytics platform";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "plausible.svg";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };
  config = lib.mkIf cfg.enable {
    services.plausible = {
      enable = true;
      server = {
        port = cfg.port;
        baseUrl = "https://${cfg.url}";
        secretKeybaseFile = cfg.secretKeybaseFile;
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
