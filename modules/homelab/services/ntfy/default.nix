{ config, lib, ... }:
let
  service = "ntfy";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 2586;
    url = "ntfy.${hl.mainDomain}";
    configDir = "/var/lib/private/ntfy-sh";
    monitoredServices = [ "ntfy-sh.service" ];
    homepage = {
      name = "ntfy";
      description = "Push notifications";
      icon = "ntfy.png";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${cfg.url}";
        listen-http = "127.0.0.1:${toString cfg.port}";
        behind-proxy = true;
        # Send iOS poll requests through ntfy.sh. The message text stays on this server.
        upstream-base-url = "https://ntfy.sh";
      };
    };
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
