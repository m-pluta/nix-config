{ config, pkgs, ... }:

let
  scrapeConfig = pkgs.writeText "vmscrape.yml" (builtins.toJSON {
    scrape_configs = [
      {
        job_name = "node";
        static_configs = [{ targets = [ "127.0.0.1:9100" ]; }];
      }
      {
        job_name = "zfs";
        static_configs = [{ targets = [ "127.0.0.1:9134" ]; }];
      }
    ];
  });
in
{
  services.victoriametrics = {
    enable = true;
    listenAddress = "127.0.0.1:8428";
    retentionPeriod = "5y";
    extraOptions = [
      "-promscrape.config=${scrapeConfig}"
    ];
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [ "systemd" "processes" ];
      port = 9100;
    };
    zfs = {
      enable = true;
      port = 9134;
    };
  };

  services.grafana = {
    enable = true;
    settings.server = {
      http_addr = "0.0.0.0";
      http_port = 3000;
      domain = "mikelab";
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "VictoriaMetrics";
        type = "prometheus";
        url = "http://127.0.0.1:8428";
        isDefault = true;
      }];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3000 ];
}
