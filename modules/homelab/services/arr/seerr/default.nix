{
  config,
  lib,
  ...
}:
let
  service = "seerr";
  serviceLib = import ../../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 5055;
    url = "${service}.${hl.mainDomain}";
    configDir = "/var/lib/${service}";
    monitoredServices = [ service ];
    homepage = {
      name = "Seerr";
      description = "Media request and discovery manager";
      icon = "seerr.svg";
      category = "Arr";
    };
  };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      port = cfg.port;
      configDir = cfg.configDir;
    };
    # The NixOS default from stateVersion 26.05
    systemd.services.${service}.serviceConfig.StateDirectory = lib.mkForce service;
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
