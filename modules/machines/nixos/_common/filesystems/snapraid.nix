{ config, lib, ... }:
{
  services.snapraid.exclude = [
    "*.unrecoverable"
    "/tmp/"
    "/lost+found/"
    "/Media/"
  ];

  systemd.services = lib.attrsets.optionalAttrs (config.services.snapraid.enable) {
    snapraid-sync = {
      serviceConfig = {
        RestrictNamespaces = lib.mkForce false;
        RestrictAddressFamilies = lib.mkForce "";
      };
    };
    snapraid-scrub = {
      serviceConfig = {
        RestrictNamespaces = lib.mkForce false;
        RestrictAddressFamilies = lib.mkForce "";
      };
    };
  };
}
