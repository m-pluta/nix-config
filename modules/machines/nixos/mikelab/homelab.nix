{
  config,
  inputs,
  ...
}:
{
  "mpluta.dev".enable = true;

  homelab = {
    enable = true;
    description = "Primary server hosting storage and the self-hosted services";
    baseDomain = "mpluta.dev";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflare-dns-api.path;
    timeZone = "Europe/London";
    groups.media = 15000;
    net.lan = "192.168.100.10";
    tailscale = {
      enable = true;
      address = "100.120.225.75";
    };
    samba = {
      enable = true;
      shares.Media = {
        path = "/tank/media/library";
        readOnly = true;
      };
      shares.Import = {
        path = "/tank/import";
      };
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
      uptime-kuma = {
        enable = true;
        port = 3002;
      };
      home-assistant.enable = true;
      immich = {
        enable = true;
        mediaDir = "/tank/photos";
      };
      vaultwarden.enable = true;
      paperless.enable = true;
      nextcloud.enable = true;
      navidrome = {
        enable = true;
        mediaDir = "/tank/media/library/music";
      };
      miniflux.enable = true;
      microbin.enable = true;
      attic.enable = true;
      forgejo-runner.enable = true;
      audiobookshelf.enable = true;
      lidarr.enable = true;
      grafana.enable = true;
      victoriametrics = {
        enable = true;
        targets.mikelab.exporters = [
          "node"
          "systemd"
          "smartctl"
          "zfs"
        ];
        targets.mikeway.exporters = [
          "node"
          "systemd"
        ];
      };
    };
  };

  systemd.tmpfiles.rules =
    let
      mediaDir = "d /tank/media";
      perms = "2775 root media - -";
    in
    [
      "${mediaDir} ${perms}"
      "${mediaDir}/torrents ${perms}"
      "${mediaDir}/torrents/movies ${perms}"
      "${mediaDir}/torrents/shows ${perms}"
      "${mediaDir}/torrents/music ${perms}"
      "${mediaDir}/torrents/books ${perms}"
      "${mediaDir}/usenet ${perms}"
      "${mediaDir}/usenet/incomplete ${perms}"
      "${mediaDir}/usenet/complete ${perms}"
      "${mediaDir}/usenet/complete/movies ${perms}"
      "${mediaDir}/usenet/complete/shows ${perms}"
      "${mediaDir}/usenet/complete/music ${perms}"
      "${mediaDir}/usenet/complete/books ${perms}"
      "${mediaDir}/library ${perms}"
      "${mediaDir}/library/movies ${perms}"
      "${mediaDir}/library/shows ${perms}"
      "${mediaDir}/library/music ${perms}"
      "${mediaDir}/library/books ${perms}"
    ];

  age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare/dns-api.age";

}
