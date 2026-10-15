{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "perfetto";
  hl = config.homelab;
  cfg = hl.services.${service};
  forgejo = hl.services.forgejo;

  # nixpkgs packages only Perfetto's command-line tools, so use the prebuilt UI from
  # the GitHub release.
  version = "58.2";
  ui = pkgs.fetchzip {
    url = "https://github.com/google/perfetto/releases/download/v${version}/perfetto-ui.zip";
    hash = "sha256-DZTOCTHQ+4mi6oefwv1SY/fJ3WfM3Q3BnOhs/Xy+W6s=";
    stripRoot = false;
  };
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "Perfetto trace viewer";
    url = lib.mkOption {
      type = lib.types.str;
      default = "perfetto.${hl.mainDomain}";
    };
    forgejoTraces = {
      enable = lib.mkEnableOption ''
        serving Forgejo release attachments named timings.json under
        /traces/<owner>/<repo>/<tag>/timings.json, so release notes can link straight to
        a trace
      '';
      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          Environment file setting FORGEJO_TRACES_TOKEN to a read-only Forgejo token, used
          to fetch traces from private repositories. Without it, only public repositories'
          traces can be opened.
        '';
      };
    };
    homepage = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "Perfetto";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "Trace viewer";
      };
      icon = lib.mkOption {
        type = lib.types.str;
        default = "chrome-devtools.svg";
      };
      category = lib.mkOption {
        type = lib.types.str;
        default = "Services";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # The vhost is not exposed through the tunnel, so it is reachable only from the LAN
      # and tailnet.
      {
        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          handle {
            root * ${ui}
            file_server
          }
        '';
      }

      # Traces are served from the viewer's own origin, so they open without CORS. Only
      # files named timings.json are proxied, so the token cannot read anything else.
      (lib.mkIf cfg.forgejoTraces.enable {
        assertions = [
          {
            assertion = forgejo.enable;
            message = "homelab.services.perfetto.forgejoTraces needs homelab.services.forgejo";
          }
        ];

        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          @trace path_regexp trace ^/traces/([^/]+)/([^/]+)/([^/]+)/timings\.json$
          handle @trace {
            rewrite * /{re.trace.1}/{re.trace.2}/releases/download/{re.trace.3}/timings.json
            reverse_proxy http://127.0.0.1:${toString forgejo.port} {
              header_up Host ${forgejo.url}
              header_up -Cookie
              ${
                if cfg.forgejoTraces.tokenFile != null then
                  ''header_up Authorization "token {env.FORGEJO_TRACES_TOKEN}"''
                else
                  "header_up -Authorization"
              }
            }
          }
        '';

        systemd.services.caddy.serviceConfig.EnvironmentFile = lib.mkIf (
          cfg.forgejoTraces.tokenFile != null
        ) cfg.forgejoTraces.tokenFile;
      })
    ]
  );
}
