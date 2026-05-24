{ lib }:
{
  mkServiceOptions =
    {
      port,
      url,
      homepage,
      configDir ? null,
      monitoredServices ? null,
    }:
    {
      enable = lib.mkEnableOption { description = "Enable ${homepage.name}"; };
      port = lib.mkOption {
        type = lib.types.port;
        default = port;
      };
      url = lib.mkOption {
        type = lib.types.str;
        default = url;
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
    // lib.optionalAttrs (configDir != null) {
      configDir = lib.mkOption {
        type = lib.types.str;
        default = configDir;
      };
    }
    // lib.optionalAttrs (monitoredServices != null) {
      monitoredServices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = monitoredServices;
      };
    };
}
