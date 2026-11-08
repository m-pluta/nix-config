{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "immich";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  unstable = inputs.nixpkgs-unstable;
in
{
  # Immich 3 until NixOS 26.11
  disabledModules = [ "services/web-apps/immich.nix" ];
  imports = [ "${unstable}/nixos/modules/services/web-apps/immich.nix" ];

  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 2283;
      url = "photos.${hl.mainDomain}";
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
      package = unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.immich;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = "${cfg.mediaDir}";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
