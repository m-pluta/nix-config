{
  config,
  inputs,
  ...
}:
{
  homelab = {
    enable = true;
    baseDomain = "mpluta.dev";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflare-dns-api.path;
    timeZone = "Europe/London";
    groups.media = 15000;
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
    samba = {
      enable = true;
      shares.Media = {
        path = "/tank/media/library";
        readOnly = true;
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
      audiobookshelf.enable = true;
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
