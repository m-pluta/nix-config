{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "nextcloud";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8009;
      url = "cloud.goose.party";
      configDir = "/var/lib/${service}";
      monitoredServices = [
        "phpfpm-nextcloud"
      ];
      homepage = {
        name = "Nextcloud";
        description = "Enterprise File Storage and Collaboration";
        icon = "nextcloud.svg";
        category = "Services";
      };
    }
    // {
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "${hl.mounts.fast}/Media/Nextcloud";
      };
      admin.username = lib.mkOption {
        type = lib.types.str;
        example = "admin";
      };
      admin.passwordFile = lib.mkOption {
        type = lib.types.str;
        example = lib.literalExpression ''
          pkgs.writeText "nc-admin-password" '''
          super-secret-password
          '''
        '';
      };
      role = lib.mkOption {
        type = lib.types.enum [
          "client"
          "server"
        ];
        default = "client";
      };
    };
  config =
    let
      mkIfElse =
        p: yes: no:
        lib.mkMerge [
          (lib.mkIf p yes)
          (lib.mkIf (!p) no)
        ];
    in
    mkIfElse (cfg.role == "client")
      # client
      (lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = lib.lists.forEach [ "" ] (
          x: "d ${cfg.dataDir}/${x} 0775 nextcloud ${hl.mediaGroup} - -"
        );
        services.nginx.virtualHosts."nix-nextcloud".listen = [
          {
            addr = "127.0.0.1";
            port = cfg.port;
          }
        ];
        fileSystems."${config.services.nextcloud.home}/data" = {
          device = cfg.dataDir;
          fsType = "none";
          options = [
            "bind"
          ];
        };
        services.nextcloud = {
          enable = true;
          hostName = "nix-nextcloud";
          package = pkgs.nextcloud32;
          database.createLocally = true;
          configureRedis = true;
          maxUploadSize = "16G";
          https = true;
          autoUpdateApps.enable = true;
          extraAppsEnable = true;
          extraApps = with config.services.nextcloud.package.packages.apps; {
            inherit
              calendar
              contacts
              mail
              notes
              tasks
              gpoddersync
              uppush
              ;
          };

          settings = {
            overwriteprotocol = "https";
            default_phone_region = "DE";
          };
          config = {
            dbtype = "pgsql";
            adminuser = cfg.admin.username;
            adminpassFile = cfg.admin.passwordFile;
          };
        };
        services.frp.settings.proxies = [
          {
            name = service;
            type = "tcp";
            localIP = "127.0.0.1";
            localPort = cfg.port;
            remotePort = cfg.port;
          }
        ];
      })
      # server
      {
        services.caddy.virtualHosts."${cfg.url}" = {
          useACMEHost = "goose.party";
          extraConfig = ''
            reverse_proxy http://127.0.0.1:${toString cfg.port}
          '';
        };
      };
}
