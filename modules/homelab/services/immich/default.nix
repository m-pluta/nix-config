{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "immich";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  unstable = inputs.nixpkgs-unstable;
in
{
  # Immich 3 until NixOS 26.11
  disabledModules = [ "services/web-apps/immich.nix" ];
  imports = [ "${unstable}/nixos/modules/services/web-apps/immich.nix" ];

  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 2283;
      url = "photos.${hl.mainDomain}";
      monitoredServices = [
        "immich-server"
        "immich-machine-learning"
      ];
      homepage = {
        name = "Immich";
        description = "Self-hosted photo and video management solution";
        icon = "immich.svg";
        category = "Media";
      };
    }
    // {
      mediaDir = lib.mkOption {
        type = lib.types.path;
      };
    };
  config = lib.mkIf cfg.enable {
    users.users.${service}.extraGroups = [
      "media"
      "video"
      "render"
    ];
    services.${service} = {
      enable = true;
      package = unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.immich;
      host = "127.0.0.1";
      port = cfg.port;
      mediaLocation = "${cfg.mediaDir}";
      # Immich's whole config, including settings once changed in the admin UI
      settings = {
        storageTemplate.enabled = true;
        server.externalDomain = "https://${cfg.url}";
        oauth = {
          enabled = true;
          buttonText = "Log in with Kanidm";
          issuerUrl = "https://${hl.services.kanidm.url}/oauth2/openid/${service}";
          clientId = service;
          clientSecret._secret = config.age.secrets."${service}-kanidm-secret".path;
          scope = "openid email profile";
          signingAlgorithm = "ES256";
          autoRegister = true;
          # Mobile app logins return through this page
          mobileOverrideEnabled = true;
          mobileRedirectUri = "https://${cfg.url}/api/oauth/mobile-redirect";
        };
      };
    };
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    homelab.sso.clients.${service} = {
      displayName = "Immich";
      originUrl = [
        "https://${cfg.url}/auth/login"
        "https://${cfg.url}/user-settings"
        "https://${cfg.url}/api/oauth/mobile-redirect"
      ];
      originLanding = "https://${cfg.url}/";
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };

}
