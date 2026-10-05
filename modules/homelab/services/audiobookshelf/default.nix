{ config, lib, ... }:
let
  service = "audiobookshelf";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8113;
    url = "audiobooks.${hl.baseDomain}";
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
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
