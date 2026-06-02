{
  config,
  lib,
  ...
}:
let
  service = "immich";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 2283;
      url = "photos.${homelab.baseDomain}";
      monitoredServices = [
        "immich-server"
        "immich-machine-learning"
      ];
      homepage = {
        name = "Immich";
        description = "Self-hosted photo and video management solution";
        icon = "immich.svg";
        category = "Media";
      };
    }
    // {
      user = lib.mkOption {
        default = homelab.user;
        type = lib.types.str;
        description = "User to run Immich as";
      };
      group = lib.mkOption {
        default = homelab.group;
        type = lib.types.str;
        description = "Group to run Immich as";
      };
      mediaDir = lib.mkOption {
        type = lib.types.path;
        default = "${config.homelab.mounts.fast}/Photos/Immich";
      };
    };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.mediaDir} 0775 immich ${cfg.group} - -" ];
    users.users.immich.extraGroups = [
      "video"
      "render"
    ];
    services.immich = {
      group = cfg.group;
      enable = true;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = "${cfg.mediaDir}";
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
