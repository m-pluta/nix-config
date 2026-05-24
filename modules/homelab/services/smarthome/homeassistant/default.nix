{ config, lib, ... }:
let
  serviceLib = import ../../lib.nix { inherit lib; };
  homelab = config.homelab;
  cfg = config.homelab.services.homeassistant;
in
{
  options.homelab.services.homeassistant = serviceLib.mkServiceOptions {
    port = 8123;
    url = "home.${homelab.baseDomain}";
    configDir = "/persist/opt/services/homeassistant";
    homepage = {
      name = "Home Assistant";
      description = "Home automation platform";
      icon = "home-assistant.svg";
      category = "Smart Home";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.configDir} 0775 ${homelab.user} ${homelab.group} - -" ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          homeassistant = {
            image = "homeassistant/home-assistant:stable";
            autoStart = true;
            extraOptions = [
              "--pull=newer"
            ];
            volumes = [
              "${cfg.configDir}:/config"
            ];
            ports = [
              "127.0.0.1:${toString cfg.port}:8123"
              "127.0.0.1:8124:80"
            ];
            environment = {
              TZ = homelab.timeZone;
              PUID = toString config.users.users.${homelab.user}.uid;
              PGID = toString config.users.groups.${homelab.group}.gid;
            };
          };
        };
      };
    };
  };
}
