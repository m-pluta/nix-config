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
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 4533;
      url = "music.${hl.baseDomain}";
      configDir = "/var/lib/${service}";
      homepage = {
        name = "Navidrome";
        description = "Self-hosted music streaming service";
        icon = "navidrome.svg";
        category = "Media";
      };
    }
    // {
      mediaDir = lib.mkOption {
        type = lib.types.str;
        default = "${hl.mounts.fast}/Media/Music/Library";
      };
      environmentFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression ''
          pkgs.writeText "navidrome-env" '''
            ND_LASTFM_APIKEY=abcabc
            ND_LASTFM_SECRET=abcabc
          '''
        '';
      };
    };
  config = lib.mkIf cfg.enable {
    systemd.services.navidrome.serviceConfig.EnvironmentFile = lib.mkIf (
      cfg.environmentFile != null
    ) cfg.environmentFile;
    services.${service} = {
      enable = true;
      settings = {
        Port = cfg.port;
        MusicFolder = "${cfg.mediaDir}";
        DefaultDownsamplingFormat = "aac";
      };
    };
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
