{
  config,
  inputs,
  ...
}:
{
  "mpluta.dev".enable = true;

  age.secrets.traces-forgejo-token.file = "${inputs.secrets}/services/traces/forgejo-token.age";

  homelab = {
    enable = true;
    description = "Primary server hosting storage and the self-hosted services";
    timeZone = "Europe/London";
    groups.media = 15000;
    tailscale.enable = true;
    # Split-horizon DNS: Unbound picks a view by the client's source subnet, so
    # the main domain resolves to the LAN IP on the LAN and the tailnet IP over tailscale.
    splitDns = {
      enable = true;
      domains = [ config.homelab.mainDomain ];
      views = [
        {
          name = "lan";
          interface = config.homelab.networks.mikelab.lan.interface;
          listen = config.homelab.networks.mikelab.lan.v4;
          subnet = config.homelab.networks.mikelab.lan.subnet;
          answer = config.homelab.networks.mikelab.lan.v4;
        }
        {
          name = "tailnet";
          interface = config.homelab.networks.mikelab.mesh.interface;
          listen = config.homelab.networks.mikelab.mesh.v4;
          subnet = config.homelab.networks.mikelab.mesh.subnet;
          answer = config.homelab.networks.mikelab.mesh.v4;
        }
      ];
    };
    cloudflared = {
      enable = true;
      tunnelId = "7a16d95b-031d-483f-befa-d8fdc081fe5c";
      expose.${config.homelab.mainDomain} = [
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
      traces = {
        enable = true;
        perfetto.enable = true;
        speedscope.enable = true;
        forgejo = {
          enable = true;
          tokenFile = config.age.secrets.traces-forgejo-token.path;
        };
      };
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

}
