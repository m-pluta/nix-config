{
  config,
  lib,
  ...
}:
let
  service = "victoriametrics";
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  vmUrl = "http://${cfg.listenAddress}:${toString cfg.port}";
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    url = lib.mkOption {
      type = lib.types.str;
      default = "vm.${homelab.baseDomain}";
    };
    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8428;
    };
    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "5y";
    };
    scrapeInterval = lib.mkOption {
      type = lib.types.str;
      default = "15s";
    };
    targets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              address = lib.mkOption {
                type = lib.types.str;
                default = name;
              };
              exporters = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
            };
          }
        )
      );
      default = { };
    };
    homepage.name = lib.mkOption {
      type = lib.types.str;
      default = "VictoriaMetrics";
    };
    homepage.description = lib.mkOption {
      type = lib.types.str;
      default = "Time series database and monitoring";
    };
    homepage.icon = lib.mkOption {
      type = lib.types.str;
      default = "victoriametrics.svg";
    };
    homepage.category = lib.mkOption {
      type = lib.types.str;
      default = "Observability";
    };
  };

  config = lib.mkIf cfg.enable {
    services.victoriametrics = {
      enable = true;
      retentionPeriod = cfg.retentionPeriod;
      prometheusConfig = {
        global.scrape_interval = cfg.scrapeInterval;
        scrape_configs =
          let
            allExporters = lib.unique (
              lib.concatLists (lib.mapAttrsToList (_: t: t.exporters) cfg.targets)
            );
          in
          map (exporter: {
            job_name = exporter;
            static_configs = lib.mapAttrsToList (hostName: target: {
              targets = [
                "${target.address}:${toString config.services.prometheus.exporters.${exporter}.port}"
              ];
              labels.instance = hostName;
            }) (lib.filterAttrs (_: t: builtins.elem exporter t.exporters) cfg.targets);
          }) allExporters;
      };
    };

    services.grafana.provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "VictoriaMetrics";
          type = "prometheus";
          url = vmUrl;
          isDefault = true;
          editable = false;
        }
      ];
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy ${vmUrl}
      '';
    };
  };
}
