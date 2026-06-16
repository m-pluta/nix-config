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
    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    security.acme = {
      acceptTerms = true;
      defaults.email = "mikey@mpluta.dev";
      certs.${config.homelab.baseDomain} = {
        reloadServices = [ "caddy.service" ];
        domain = "${config.homelab.baseDomain}";
        extraDomainNames = [ "*.${config.homelab.baseDomain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
        group = config.services.caddy.group;
        environmentFile = config.homelab.cloudflare.dnsCredentialsFile;
      };
    };
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = {
        "http://${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
          '';
        };
        "http://*.${config.homelab.baseDomain}" = {
          extraConfig = ''
            redir https://{host}{uri}
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
    #./arr/lidarr
    ./arr/prowlarr
    ./arr/radarr
    ./arr/sonarr
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
