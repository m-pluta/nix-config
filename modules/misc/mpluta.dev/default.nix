{
  config,
  inputs,
  ...
}:
let
  domain = "mpluta.dev";
  tunnelId = "7a16d95b-031d-483f-befa-d8fdc081fe5c";
  webRoot = ./site;
in
{
  age.secrets.cloudflared-tunnel.file = "${inputs.secrets}/network/cloudflared-tunnel.age";

  services.caddy.virtualHosts."${domain}" = {
    useACMEHost = domain;
    serverAliases = [ "www.${domain}" ];
    extraConfig = ''
      root * ${webRoot}
      file_server
    '';
  };
  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = config.age.secrets.cloudflared-tunnel.path;
      ingress = {
        "${domain}" = {
          service = "https://127.0.0.1:443";
          originRequest = {
            noTLSVerify = true;
            originServerName = domain;
          };
        };
        "*.${domain}" = {
          service = "https://127.0.0.1:443";
          originRequest = {
            noTLSVerify = true;
            originServerName = domain;
          };
        };
      };
      default = "http_status:404";
    };
  };
}
