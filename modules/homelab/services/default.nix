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
    services = {
      enable = lib.mkEnableOption "Settings and services for the homelab";
    };
  };

  config = lib.mkIf hl.services.enable {
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
    virtualisation.oci-containers = {
      backend = "podman";
    };

    networking.firewall.interfaces.podman0.allowedUDPPorts =
      lib.lists.optionals config.virtualisation.podman.enable
        [ 53 ];
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
    ./oauth2-proxy
    ./nextcloud
    ./paperless-ngx
    ./plausible
    ./sabnzbd
    ./traces
    ./uptime-kuma
    ./vaultwarden
  ];
}
