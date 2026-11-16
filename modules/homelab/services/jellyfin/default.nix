{
  config,
  lib,
  ...
}:
let
  service = "jellyfin";
  # Jellyfin sets its own port. The NixOS module has no option for it.
  port = 8096;
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    url = "${service}.${hl.mainDomain}";
    shortcut = "jellyfin";
    configDir = "/var/lib/${service}";
    monitoredServices = [ "jellyfin.service" ];
    homepage = {
      name = "Jellyfin";
      description = "The Free Software Media System";
      icon = "jellyfin.svg";
      category = "Media";
    };
  };
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (_final: prev: {
        jellyfin-web = prev.jellyfin-web.overrideAttrs (
          _finalAttrs: _previousAttrs: {
            installPhase = ''
              runHook preInstall

              # this is the important line
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web

              runHook postInstall
            '';
          }
        );
      })
    ];
    services.${service}.enable = true;
    users.users.${service}.extraGroups = [ "media" ];
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}" = {
      inherit port;
      shortcut = cfg.shortcut;
    };
  };

}
