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
    };
  };

  age.secrets.cloudflare-dns-api.file = "${inputs.mikelab-secrets}/cloudflare-dns-api.age";

  # Override forgejo defaults from wolfgang's module
  services.forgejo = {
    package = lib.mkForce pkgs.forgejo;
    database.type = lib.mkForce "sqlite3";
    settings.server = {
      LANDING_PAGE = lib.mkForce "/explore/repos";
      HTTP_PORT = lib.mkForce 3001;
    };
    settings.mailer.ENABLED = lib.mkForce false;
  };

  # Override ACME contact email
  security.acme.defaults.email = lib.mkForce "mikey@mpluta.dev";
}
