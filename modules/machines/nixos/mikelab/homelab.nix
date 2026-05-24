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
    monitoring.exporters = {
      smartctl.enable = true;
      zfs.enable = true;
    };
    services = {
      enable = true;
      forgejo = {
        enable = true;
        port = 3001;
      };
      homepage.enable = true;
      grafana.enable = true;
      victoriametrics = {
        enable = true;
        targets.mikelab = {
          address = "localhost";
          exporters = [ "node" "systemd" "smartctl" "zfs" ];
        };
      };
    };
  };

  age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare-dns-api.age";
  security.acme.defaults.email = lib.mkForce "mikey@mpluta.dev";

  services.forgejo.database.type = "sqlite3";

}
