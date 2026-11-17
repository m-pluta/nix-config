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
      auth ? { },
    }:
    {
      enable = lib.mkEnableOption homepage.name;
      # Kanidm logins. Only members of the <name>.access group can log in.
      auth = {
        oidc = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = auth.oidc.enable or false;
            description = "Whether the service logs in through Kanidm's OIDC.";
          };
          redirectPaths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = auth.oidc.redirectPaths or [ ];
            example = [ "/login/generic_oauth" ];
            description = "Paths on the service's url that Kanidm can send an OIDC login code to.";
          };
          scopes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default =
              auth.oidc.scopes or [
                "openid"
                "profile"
                "email"
              ];
            description = "What the service may read about a user, such as name and email.";
          };
          extraClientSettings = lib.mkOption {
            type = lib.types.attrs;
            default = auth.oidc.extraClientSettings or { };
            description = "Other Kanidm OAuth2 client settings.";
          };
        };
        ldap.enable = lib.mkOption {
          type = lib.types.bool;
          default = auth.ldap.enable or false;
          description = "Whether the service checks passwords against Kanidm's LDAP server.";
        };
      };
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
