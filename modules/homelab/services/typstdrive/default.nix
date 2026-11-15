{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  service = "typstdrive";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  cookieSecret = "/var/lib/${service}/secrets/cookie";
in
{
  imports = [ inputs.nix-typstdrive.nixosModules.default ];

  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8073;
    url = "typst.${hl.mainDomain}";
    shortcut = "typst";
    homepage = {
      name = "TypstDrive";
      description = "Typst editor";
      icon = "si-typst";
      category = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";

    homelab.sso.clients.${service} = {
      displayName = "TypstDrive";
      originUrl = "https://${cfg.url}/api/auth/sso/kanidm/callback";
      originLanding = "https://${cfg.url}/";
    };

    services.typstdrive = {
      enable = true;
      port = cfg.port;
      publicUrl = "https://${cfg.url}";
      trustProxyHeaders = true;
      database.type = "postgres";
      environment = {
        OIDC_PROVIDERS = "kanidm";
        OIDC_KANIDM_NAME = "Kanidm";
        OIDC_KANIDM_ISSUER = "https://${hl.services.kanidm.url}/oauth2/openid/${service}";
        OIDC_KANIDM_CLIENT_ID = service;
      };
    };

    # Made at activation, so sessions stay valid across restarts.
    system.activationScripts."${service}-secrets" = {
      deps = [ "users" ];
      text = ''
        install -d -m 0700 ${dirOf cookieSecret}
        if [ ! -s ${cookieSecret} ]; then
          (umask 077; ${lib.getExe pkgs.openssl} rand -hex 64 > ${cookieSecret})
        fi
      '';
    };

    # The secrets go to the server as environment variables, from systemd credentials.
    systemd.services.typstdrive.serviceConfig = {
      LoadCredential = [
        "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}"
        "cookie-secret:${cookieSecret}"
      ];
      ExecStart = lib.mkForce (
        lib.getExe (
          pkgs.writeShellApplication {
            name = "${service}-start";
            text = ''
              COOKIE_SECRET=$(< "$CREDENTIALS_DIRECTORY/cookie-secret")
              OIDC_KANIDM_CLIENT_SECRET=$(< "$CREDENTIALS_DIRECTORY/kanidm-secret")
              export COOKIE_SECRET OIDC_KANIDM_CLIENT_SECRET
              exec ${lib.getExe config.services.typstdrive.package}
            '';
          }
        )
      );
    };

    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
