{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  homelab = {
    enable = true;
    baseDomain = "mpluta.dev";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflare-dns-api.path;
    timeZone = "Europe/London";
    services = {
      enable = true;
      forgejo.enable = true;
      homepage.enable = true;
    };
  };

  age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare-dns-api.age";
  security.acme.defaults.email = lib.mkForce "mikey@mpluta.dev";

  services.forgejo = {
    database.type = "sqlite3";
    settings.server.HTTP_PORT = 3001;
  };

}
