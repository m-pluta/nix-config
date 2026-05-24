{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.monitoring;
  enabledExporters = lib.filterAttrs (_: v: v.enable) cfg.exporters;
in
{
  options.homelab.monitoring.exporters = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          extraConfig = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
        };
      }
    );
    default = { };
  };

  config = lib.mkIf config.homelab.enable {
    homelab.monitoring.exporters = {
      node.enable = lib.mkDefault true;
      systemd.enable = lib.mkDefault true;
    };

    services.prometheus.exporters = lib.mapAttrs (
      _name: value:
      {
        enable = true;
      }
      // value.extraConfig
    ) enabledExporters;
  };
}
