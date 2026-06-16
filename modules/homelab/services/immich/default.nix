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
      mediaDir = lib.mkOption {
        type = lib.types.path;
      };
    };
  config = lib.mkIf cfg.enable {
    users.users.immich.extraGroups = [
      "media"
      "video"
      "render"
    ];
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = "${cfg.mediaDir}";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
