{
  config,
  lib,
  ...
}:
let
  service = "navidrome";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 4533;
    url = "music.goose.party";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Navidrome";
      description = "Self-hosted music streaming service";
      icon = "navidrome.svg";
      category = "Media";
    };
  } // {
    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "${hl.mounts.fast}/Media/Music/Library";
    };
    environmentFile = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression ''
        pkgs.writeText "navidrome-env" '''
          ND_LASTFM_APIKEY=abcabc
          ND_LASTFM_SECRET=abcabc
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
      (lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = [
          "d ${cfg.musicDir} 0775 ${hl.user} ${hl.group} - -"
        ];
        systemd.services.navidrome.serviceConfig.EnvironmentFile = lib.mkIf (
          cfg.environmentFile != null
        ) cfg.environmentFile;
        services.${service} = {
          enable = true;
          user = hl.user;
          group = hl.group;
          settings = {
            Port = cfg.port;
            MusicFolder = "${cfg.musicDir}";
            DefaultDownsamplingFormat = "aac";
          };
        };
        services.frp.settings.proxies = [
          {
            name = service;
            type = "tcp";
            localIP = config.services.${service}.settings.Address;
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
