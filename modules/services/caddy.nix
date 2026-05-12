{ config, pkgs, ... }:
{
  age.secrets.cloudflare-dns-api.file = ../../secrets/cloudflare-dns-api.age;

  services.caddy = {
    enable = true;
    email = config.my.adminEmail;

    package = pkgs.caddy.withPlugins {
      plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
      hash = "sha256-uKtStb6m1/hA5IaAdIyLGzAQdyIySjISdxXIRxehhyI=";
    };

    globalConfig = ''
      acme_dns cloudflare {
        api_token {env.CF_API_TOKEN}
      }
    '';

    virtualHosts."grafana.${config.my.domain}".extraConfig = ''
      reverse_proxy http://127.0.0.1:3000
    '';

    virtualHosts."git.${config.my.domain}".extraConfig = ''
      reverse_proxy http://127.0.0.1:3001
    '';
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = config.age.secrets.cloudflare-dns-api.path;
}
