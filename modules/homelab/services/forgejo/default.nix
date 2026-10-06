{
  lib,
  config,
  pkgs,
  ...
}:
let
  service = "forgejo";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 3000;
    url = "git.${hl.baseDomain}";
    homepage = {
      name = "Forgejo";
      description = "A painless, self-hosted Git service";
      icon = "forgejo.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d /var/lib/${service} 0700 ${service} ${service} - -" ];
    services.openssh.settings.AcceptEnv = "GIT_PROTOCOL";
    services.${service} = {
      package = pkgs.forgejo;
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
        service = {
          DISABLE_REGISTRATION = true;
          ENABLE_NOTIFY_MAIL = true;
          REGISTER_EMAIL_CONFIRM = true;
        };
        repository = {
          DEFAULT_PRIVATE = "private";
          DEFAULT_REPO_UNITS = "repo.code,repo.issues,repo.pulls,repo.packages,repo.actions";
        };
        "repository.pull-request" = {
          DEFAULT_MERGE_STYLE = "squash";
          DEFAULT_UPDATE_STYLE = "rebase";
        };
      };
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
        request_body {
          max_size 10GB
        }
      '';
    };
  };
}
