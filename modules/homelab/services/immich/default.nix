{
  config,
  lib,
  ...
}:
let
  service = "immich";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 2283;
      url = "photos.${hl.baseDomain}";
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
    users.users.${service}.extraGroups = [
      "media"
      "video"
      "render"
    ];
    services.${service} = {
      enable = true;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = "${cfg.mediaDir}";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
