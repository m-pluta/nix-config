{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.homelab = {
    services = {
      enable = lib.mkEnableOption "Settings and services for the homelab";
    };
  };

  config = lib.mkIf config.homelab.services.enable {
    virtualisation.podman = {
      dockerCompat = true;
      autoPrune.enable = true;
      extraPackages = [ pkgs.zfs ];
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
    virtualisation.containers.containersConf.settings = {
      containers.dns_servers = [ config.homelab.tailscale.address ];
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
    ./arr/jellyseerr
    ./arr/lidarr
    ./arr/prowlarr
    ./arr/radarr
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
    ./microbin
    ./miniflux
    ./monitoring/exporters
    ./monitoring/exporters/shelly_plug_exporter
    ./monitoring/grafana
    ./monitoring/victoriametrics
    ./navidrome
    ./nextcloud
    ./paperless-ngx
    ./plausible
    ./sabnzbd
    ./uptime-kuma
    ./vaultwarden
  ];
}
