{
  config,
  lib,
  ...
}:
let
  service = "victoriametrics";
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
  vmUrl = "http://127.0.0.1:${toString cfg.port}";
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8428;
    url = "vm.${homelab.baseDomain}";
    homepage = {
      name = "VictoriaMetrics";
      description = "Time series database and monitoring";
      icon = "victoriametrics.svg";
      category = "Observability";
    };
  } // {
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
