{
  lib,
  config,
  pkgs,
  ...
}:
let
  serviceLib = import ../../lib.nix { inherit lib; };
  cfg = config.homelab.services.raspberrymatic;
  homelab = config.homelab;
in
{
  options.homelab.services.raspberrymatic = serviceLib.mkServiceOptions {
    port = 8124;
    url = "ccu.${homelab.baseDomain}";
    configDir = "/persist/opt/services/ccu";
    homepage = {
      name = "RaspberryMatic";
      description = "Homematic IP CCU";
      icon = "raspberrymatic.png";
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
    services.udev.extraRules = ''
      ACTION=="add", ATTRS{idVendor}=="1b1f", ATTRS{idProduct}=="c020", RUN+="${pkgs.kmod}/bin/modprobe cp210x" RUN+="${pkgs.bash}/bin/bash -c 'echo 1b1f c020 > /sys/bus/usb-serial/drivers/cp210x/new_id'"
    '';
    virtualisation = {
      podman.enable = true;
      oci-containers = {
        containers = {
          ccu = {
            image = "ghcr.io/jens-maus/raspberrymatic:latest";
            autoStart = true;
            hostname = "ccu";
            dependsOn = [ "homeassistant" ];
            extraOptions = [
              "--pull=newer"
              "--privileged"
              "--device=/dev/ttyUSB0:/dev/ttyUSB0"
              "--network=container:homeassistant"
            ];
            volumes = [
              "${cfg.configDir}:/usr/local:rw"
              "/run/current-system/kernel-modules:/lib/modules:ro"
            ];
            environment = {
              APP_NAME = "CCU";
              TZ = homelab.timeZone;
              UID = toString config.users.users.${homelab.user}.uid;
              GID = toString config.users.groups.${homelab.group}.gid;
            };
          };
        };
      };
    };
  };
}
