{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  service = "forgejo";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  # nixpkgs builds the frontend from the unpatched source, so patches to it need their
  # own frontend build swapped into the package's static files.
  frontend = pkgs.buildNpmPackage {
    pname = "forgejo-frontend";
    inherit (pkgs.forgejo) version npmDeps;
    src = pkgs.applyPatches {
      name = "forgejo-src-patched";
      inherit (pkgs.forgejo) src;
      patches = [
        ./remember-log-time-options.patch
        ./log-fullscreen-button.patch
      ];
    };
    buildPhase = "./node_modules/.bin/webpack";
    installPhase = "mkdir $out; cp -R ./public $out/";
  };
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 3000;
    url = "git.${hl.mainDomain}";
    shortcut = "git";
    homepage = {
      name = "Forgejo";
      description = "A painless, self-hosted Git service";
      icon = "forgejo.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.openssh.settings.AcceptEnv = [ "GIT_PROTOCOL" ];
    services.${service} = {
      package = pkgs.forgejo.overrideAttrs (old: {
        postInstall = old.postInstall + ''
          # The copy from the store is read-only, so make it writable before removing it.
          chmod -R u+w $data/public
          rm -r $data/public
          cp -R ${frontend}/public $data
        '';
      });
      enable = true;
      database.type = lib.mkDefault "sqlite3";
      lfs.enable = true;
      settings = {
        server = {
          DOMAIN = cfg.url;
          ROOT_URL = "https://${cfg.url}/";
          HTTP_PORT = cfg.port;
          LANDING_PAGE = lib.mkDefault "/explore/repos";
          SSH_PORT = lib.head config.services.openssh.ports;
        };
        log = {
          LEVEL = "Trace";
        };
        # New accounts only through Kanidm
        service = {
          ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
          SHOW_REGISTRATION_BUTTON = false;
          ENABLE_NOTIFY_MAIL = true;
          REGISTER_EMAIL_CONFIRM = true;
        };
        repository = {
          DEFAULT_PRIVATE = "private";
          DEFAULT_REPO_UNITS = "repo.code,repo.issues,repo.pulls,repo.packages,repo.actions";
        };
        oauth2_client = {
          ENABLE_AUTO_REGISTRATION = true;
          USERNAME = "nickname";
          # Link existing accounts by logging in to them
          ACCOUNT_LINKING = "login";
        };
        "repository.pull-request" = {
          DEFAULT_MERGE_STYLE = "squash";
          DEFAULT_UPDATE_STYLE = "rebase";
        };
      };
    };
    age.secrets."${service}-kanidm-secret".file =
      "${inputs.secrets}/services/kanidm/clients/${service}.age";
    homelab.sso.clients.${service} = {
      displayName = "Forgejo";
      originUrl = "https://${cfg.url}/user/oauth2/kanidm/callback";
      originLanding = "https://${cfg.url}/";
    };
    # Forgejo's Kanidm login source
    systemd.services."${service}-kanidm-login" = {
      description = "Add Forgejo's Kanidm login source";
      after = [ "${service}.service" ];
      requires = [ "${service}.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.${service}.package ];
      environment = {
        FORGEJO_WORK_DIR = config.services.${service}.stateDir;
        FORGEJO_CUSTOM = config.services.${service}.customDir;
        CLIENT_ID = service;
        DISCOVERY_URL = "https://${hl.services.kanidm.url}/oauth2/openid/${service}/.well-known/openid-configuration";
      };
      serviceConfig = {
        Type = "oneshot";
        User = config.services.${service}.user;
        Group = config.services.${service}.group;
        LoadCredential = [ "kanidm-secret:${config.age.secrets."${service}-kanidm-secret".path}" ];
        ExecStart = lib.getExe (
          pkgs.writeShellApplication {
            name = "${service}-kanidm-login";
            runtimeInputs = [ pkgs.gawk ];
            text = builtins.readFile ./kanidm-login.sh;
          }
        );
      };
    };
    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
      extraConfig = ''
        request_body {
          max_size 10GB
        }
      '';
    };
  };
}
