{
  config,
  lib,
  ...
}:
let
  service = "sabnzbd";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8080;
    url = "${service}.${hl.mainDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "SABnzbd";
      description = "The free and easy binary newsreader";
      icon = "sabnzbd.svg";
      category = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      configFile = null;
      settings.misc = {
        port = cfg.port;
        host_whitelist = cfg.url;
      };
    };
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
