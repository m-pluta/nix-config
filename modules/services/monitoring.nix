{ config, pkgs, ... }:
let
  # scrape config for VictoriaMetrics (prometheus-compatible format)
  scrapeConfig = pkgs.writeText "vmscrape.yml" (
    builtins.toJSON {
      scrape_configs = [
        {
          job_name = "node";
          static_configs = [ { targets = [ "127.0.0.1:9100" ]; } ];
        }
        {
          job_name = "zfs";
          static_configs = [ { targets = [ "127.0.0.1:9134" ]; } ];
        }
        {
          job_name = "smartctl";
          static_configs = [ { targets = [ "127.0.0.1:9633" ]; } ];
        }
      ];
    }
  );
in
{
  services.victoriametrics = {
    enable = true;
    stateDir = "victoriametrics";
    # localhost only, queried via grafana on same host
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "5y";
    extraOptions = [ "-promscrape.config=${scrapeConfig}" ];
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      # systemd unit states + per-process metrics on top of defaults
      enabledCollectors = [
        "systemd"
        "processes"
      ];
      port = 9100;
    };
    zfs = {
      enable = true;
      port = 9134;
    };
    # SMART attributes from smartmontools
    smartctl = {
      enable = true;
      port = 9633;
    };
  };

  services.grafana = {
    enable = true;
    dataDir = "/var/lib/grafana";
    settings.server = {
      # 0.0.0.0 + trustedInterfaces tailscale0 = tailnet-only access
      # can switch to 127.0.0.1 once caddy reverse-proxies it
      http_addr = "0.0.0.0";
      http_port = 3000;
      domain = "mikelab";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          type = "prometheus";
          url = "http://127.0.0.1:8428";
          isDefault = true;
        }
      ];
    };
  };
}
