{
  config,
  lib,
  ...
}:
let
  domain = "mpluta.dev";
  cfg = config.${domain};
in
{
  options.${domain}.enable = lib.mkEnableOption "${domain} static site";

  config = lib.mkIf cfg.enable {
    services.caddy.virtualHosts.${domain} = {
      useACMEHost = domain;
      serverAliases = [ "www.${domain}" ];
      extraConfig = ''
        root * ${./site}
        file_server
      '';
    };
  };
}
