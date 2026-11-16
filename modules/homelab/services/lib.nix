{ lib }:
{
  mkServiceOptions =
    {
      port ? null,
      url,
      shortcut ? null,
      homepage,
      configDir ? null,
      monitoredServices,
    }:
    {
      enable = lib.mkEnableOption homepage.name;
      url = lib.mkOption {
        type = lib.types.str;
        default = url;
      };
      shortcut = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = shortcut;
        description = "One-word name that opens the service, such as git for http://git/.";
      };
      homepage = {
        name = lib.mkOption {
          type = lib.types.str;
          default = homepage.name;
        };
        description = lib.mkOption {
          type = lib.types.str;
          default = homepage.description;
        };
        icon = lib.mkOption {
          type = lib.types.str;
          default = homepage.icon;
        };
        category = lib.mkOption {
          type = lib.types.str;
          default = homepage.category;
        };
      };
    }
    // lib.optionalAttrs (port != null) {
      port = lib.mkOption {
        type = lib.types.port;
        default = port;
      };
    }
    // lib.optionalAttrs (configDir != null) {
      configDir = lib.mkOption {
        type = lib.types.str;
        default = configDir;
      };
    }
    // {
      monitoredServices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = monitoredServices;
        description = "Full systemd unit names of the service that motd shows.";
      };
    };
}
