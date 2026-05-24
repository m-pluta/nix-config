{
  config,
  lib,
  ...
}:
let
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.immich;
  homelab = config.homelab;
in
{
  options.homelab.services.immich =
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
        default = config.homelab.user;
        type = lib.types.str;
        description = ''
          User to run the Immich container as
        '';
      };
      group = lib.mkOption {
        default = config.homelab.group;
        type = lib.types.str;
        description = ''
          Group to run the Immich container as
        '';
      };
      mediaDir = lib.mkOption {
        type = lib.types.path;
        default = "${config.homelab.mounts.fast}/Photos/Immich";
      };
    };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.mediaDir} 0775 immich ${homelab.group} - -" ];
    users.users.immich.extraGroups = [
      "video"
      "render"
    ];
    services.immich = {
      group = homelab.group;
      enable = true;
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
