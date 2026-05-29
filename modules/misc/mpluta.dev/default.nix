{
  ...
}:
let
  domain = "mpluta.dev";
  webRoot = ./site;
in
{
  services.caddy.virtualHosts."${domain}" = {
    useACMEHost = domain;
    serverAliases = [ "www.${domain}" ];
    extraConfig = ''
      root * ${webRoot}
      file_server
    '';
  };
}
