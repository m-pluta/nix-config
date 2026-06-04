{
  config,
  lib,
  ...
}:
let
  service = "jellyfin";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
  homelab = config.homelab;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8096;
    url = "jellyfin.${homelab.baseDomain}";
    configDir = "/var/lib/${service}";
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
    users.users.${service}.extraGroups = [ homelab.mediaGroup ];
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };

}
