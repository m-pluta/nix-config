{
  config,
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
    tailscale = {
      enable = true;
      address = "100.120.225.75";
    };
    dnsmasq.enable = true;
    cloudflared = {
      enable = true;
      tunnelId = "7a16d95b-031d-483f-befa-d8fdc081fe5c";
      credentialsFile = config.age.secrets.cloudflared-tunnel.path;
      expose."mpluta.dev" = [
        ""
        "www"
        "git"
      ];
    };
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
      jellyfin.enable = true;
      sabnzbd.enable = true;
      deluge.enable = true;
      sonarr.enable = true;
      radarr.enable = true;
      bazarr.enable = true;
      prowlarr.enable = true;
      jellyseerr.enable = true;
      grafana.enable = true;
      victoriametrics = {
        enable = true;
        targets.mikelab = {
          address = "localhost";
          exporters = [
            "node"
            "systemd"
            "smartctl"
            "zfs"
          ];
        };
      };
    };
  };

  age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare-dns-api.age";
  security.acme.defaults.email = lib.mkForce "mikey@mpluta.dev";

  services.forgejo.database.type = "sqlite3";

}
