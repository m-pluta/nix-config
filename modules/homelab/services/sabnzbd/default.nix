{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "sabnzbd";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = hl.services.${service};
  hl = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8080;
    url = "sabnzbd.${hl.baseDomain}";
    configDir = "/var/lib/${service}";
    homepage = {
      name = "SABnzbd";
      description = "The free and easy binary newsreader";
      icon = "sabnzbd.svg";
      category = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service}.enable = true;
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    # sabnzbd blocks reverse-proxied requests unless hostname is whitelisted
    systemd.services.${service}.preStart = lib.mkAfter ''
      if [ -f /var/lib/${service}/sabnzbd.ini ]; then
        ${lib.getExe pkgs.gnused} -i 's/^host_whitelist.*/host_whitelist = ${cfg.url}/' /var/lib/${service}/sabnzbd.ini
      fi
    '';
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
