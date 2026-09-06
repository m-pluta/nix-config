{ config, lib, ... }:
let
  service = "audiobookshelf";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8113;
    url = "audiobooks.${homelab.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "Audiobookshelf";
      description = "Audiobook and podcast player";
      icon = "audiobookshelf.svg";
      category = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.port;
    };
    users.users.${service}.extraGroups = [ "media" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
