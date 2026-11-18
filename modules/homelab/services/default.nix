{
  config,
  lib,
  pkgs,
  ...
}:
let
  hl = config.homelab;
in
{
  options.homelab = {
    allHosts.services = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      internal = true;
      description = "The services that are enabled on any host, with their settings from that host.";
    };
  };

  # Homelab settings for Podman, on each host that uses Podman
  config = lib.mkIf config.virtualisation.podman.enable {
    virtualisation.podman = {
      dockerCompat = true;
      autoPrune.enable = true;
      extraPackages = [ pkgs.zfs ];
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
    virtualisation.containers.containersConf.settings = {
      containers.dns_servers = [ hl.networks.${hl.splitDns.resolverHost}.lan.v4 ];
    };
    networking.firewall.interfaces.podman0.allowedUDPPorts = [ 53 ];
  };

  imports = [
    ./arr/bazarr
    ./arr/lidarr
    ./arr/prowlarr
    ./arr/radarr
    ./arr/seerr
    ./arr/sonarr
    ./attic
    ./audiobookshelf
    ./changedetection
    ./deluge
    ./forgejo
    ./forgejo-runner
    ./home-assistant
    ./homepage
    ./immich
    ./jellyfin
    ./kanidm
    ./microbin
    ./miniflux
    ./monitoring/exporters
    ./monitoring/grafana
    ./monitoring/victoriametrics
    ./navidrome
    ./nextcloud
    ./ntfy
    ./paperless-ngx
    ./plausible
    ./sabnzbd
    ./traces
    ./uptime-kuma
    ./vaultwarden
  ];
}
