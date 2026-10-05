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
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    security.acme = {
      acceptTerms = true;
      defaults.email = "mikey@mpluta.dev";
      certs.${hl.baseDomain} = {
        reloadServices = [ "caddy.service" ];
        domain = "${hl.baseDomain}";
        extraDomainNames = [ "*.${hl.baseDomain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
        group = config.services.caddy.group;
        environmentFile = hl.cloudflare.dnsCredentialsFile;
      };
    };
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        "http://${hl.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${hl.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "*.${hl.baseDomain}" = {
          useACMEHost = hl.baseDomain;
          extraConfig = ''
            respond 404
          '';
        };
      };
    };
    virtualisation.podman = {
      dockerCompat = true;
      autoPrune.enable = true;
      extraPackages = [ pkgs.zfs ];
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };
    virtualisation.containers.containersConf.settings = {
      containers.dns_servers = [ hl.tailscale.address ];
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
