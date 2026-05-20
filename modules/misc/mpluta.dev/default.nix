{
  ...
}:
let
  domain = "mpluta.dev";
  webRoot = ./site;
in
{
  services.caddy = {
    enable = true;
    email = "michalpl2003@gmail.com";
    virtualHosts."${domain}" = {
      serverAliases = [ "www.${domain}" ];
      extraConfig = ''
        file_server
        root ${webRoot}
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
