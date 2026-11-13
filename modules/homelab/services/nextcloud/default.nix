{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  service = "nextcloud";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8009;
      url = "cloud.${hl.mainDomain}";
      shortcut = "cloud";
      configDir = "/var/lib/${service}";
      monitoredServices = [
        "phpfpm-nextcloud"
      ];
      homepage = {
        name = "Nextcloud";
        description = "File sync and sharing";
        icon = "nextcloud.svg";
        category = "Services";
      };
    }
    // {
      admin.username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
      };
    };
  config = lib.mkIf cfg.enable {
    # Nextcloud's setup reads it through LoadCredential, so it stays root-only.
    age.secrets."${service}-admin-password".file =
      "${inputs.secrets}/services/${service}/admin-password.age";
    # Nextcloud requires nginx internally as its PHP-FPM frontend
    services.nginx.virtualHosts."nix-nextcloud".listen = [
      {
        addr = "127.0.0.1";
        port = cfg.port;
      }
    ];
    services.${service} = {
      enable = true;
      hostName = "nix-nextcloud";
      package = pkgs.nextcloud33;
      database.createLocally = true;
      configureRedis = true;
      maxUploadSize = "16G";
      https = true;
      settings = {
        overwriteprotocol = "https";
        overwritehost = cfg.url;
        default_phone_region = "GB";
        trusted_domains = [ cfg.url ];
        # Kanidm has a private address (LAN and tailnet only). Nextcloud blocks those by default.
        allow_local_remote_servers = true;
        user_oidc = {
          # Use PKCE. It proves that the app that started the login is the one that gets the token.
          use_pkce = true;
          # Create an account on the first Kanidm login
          auto_provision = true;
          # Use an existing account that has the same username
          soft_auto_provision = true;
        };
      };
      extraApps = { inherit (pkgs.nextcloud33Packages.apps) user_oidc; };
      extraAppsEnable = true;
      # Keep the app store on. It is off by default when extraApps is set.
      appstoreEnable = true;
      config = {
        dbtype = "pgsql";
        adminuser = cfg.admin.username;
        adminpassFile = config.age.secrets."${service}-admin-password".path;
      };
    };
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    homelab.sso.clients.${service} = {
      displayName = "Nextcloud";
      originUrl = "https://${cfg.url}/apps/user_oidc/code";
      originLanding = "https://${cfg.url}/";
      # user_oidc accepts only RS256 token signatures. Kanidm uses ES256 by default.
      settings.enableLegacyCrypto = true;
    };
    # Nextcloud's Kanidm provider
    systemd.services."${service}-kanidm-login" = {
      description = "Add Nextcloud's Kanidm provider";
      after = [ "nextcloud-setup.service" ];
      requires = [ "nextcloud-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.${service}.occ ];
      environment = {
        CLIENT_ID = service;
        DISCOVERY_URL = "https://${hl.services.kanidm.url}/oauth2/openid/${service}/.well-known/openid-configuration";
      };
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = [ "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}" ];
        ExecStart = lib.getExe (
          pkgs.writeShellApplication {
            name = "${service}-kanidm-login";
            text = builtins.readFile ./kanidm-login.sh;
          }
        );
      };
    };
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
