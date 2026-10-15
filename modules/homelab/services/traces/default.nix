{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "traces";
  hl = config.homelab;
  cfg = hl.services.${service};
  forgejo = hl.services.forgejo;

  # The root opens the first enabled viewer.
  rootViewer = lib.findFirst (v: cfg.${v}.enable) null [
    "perfetto"
    "speedscope"
  ];

  # Upstream settings for requests to Forgejo. The viewer's cookies are not sent on, and
  # the token is added when there is one.
  forgejoUpstream = ''
    header_up Host ${forgejo.url}
    header_up -Cookie
    ${
      if cfg.forgejo.tokenFile != null then
        ''header_up Authorization "token {env.FORGEJO_TRACES_TOKEN}"''
      else
        "header_up -Authorization"
    }
  '';

  # nixpkgs packages only Perfetto's command-line tools, so use the prebuilt UI from
  # the GitHub release.
  perfettoVersion = "58.2";
  perfetto = pkgs.fetchzip {
    url = "https://github.com/google/perfetto/releases/download/v${perfettoVersion}/perfetto-ui.zip";
    hash = "sha256-DZTOCTHQ+4mi6oefwv1SY/fJ3WfM3Q3BnOhs/Xy+W6s=";
    stripRoot = false;
  };
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption "trace viewers";
    url = lib.mkOption {
      type = lib.types.str;
      default = "traces.${hl.mainDomain}";
    };
    perfetto.enable = lib.mkEnableOption "the Perfetto UI at /perfetto/";
    speedscope.enable = lib.mkEnableOption "the Speedscope UI at /speedscope/";
    forgejo = {
      enable = lib.mkEnableOption ''
        serving traces stored in Forgejo: release attachments named timings.json under
        /releases/<owner>/<repo>/<tag>/timings.json, and comment attachments named
        build-trace-*.json under /attachments/<uuid>, so releases and CI comments can link
        straight to a trace
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
        default = "Traces";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "Trace viewers";
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
      # and tailnet. Each viewer lives in its own folder, and traces are served from the
      # same origin, so viewers can open them without CORS.
      {
        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          ${lib.optionalString (rootViewer != null) "redir / /${rootViewer}/"}
          handle {
            respond 404
          }
        '';
      }

      (lib.mkIf cfg.perfetto.enable {
        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          redir /perfetto /perfetto/
          handle_path /perfetto/* {
            root * ${perfetto}
            file_server
          }
        '';
      })

      (lib.mkIf cfg.speedscope.enable {
        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          redir /speedscope /speedscope/
          handle_path /speedscope/* {
            root * ${pkgs.speedscope}/lib/node_modules/speedscope/dist/release
            file_server
          }
        '';
      })

      # Only trace files are proxied, so the token cannot read anything else. Comment
      # attachment URLs carry no file name, so those are checked by the file name Forgejo
      # returns instead.
      (lib.mkIf cfg.forgejo.enable {
        assertions = [
          {
            assertion = forgejo.enable;
            message = "homelab.services.traces.forgejo needs homelab.services.forgejo";
          }
        ];

        homelab.ingress.routes.${cfg.url}.extraConfig = ''
          @release path_regexp release ^/releases/([^/]+)/([^/]+)/([^/]+)/timings\.json$
          handle @release {
            rewrite * /{re.release.1}/{re.release.2}/releases/download/{re.release.3}/timings.json
            reverse_proxy http://127.0.0.1:${toString forgejo.port} {
              ${forgejoUpstream}
            }
          }

          @attachment path_regexp ^/attachments/[0-9a-f-]+$
          handle @attachment {
            reverse_proxy http://127.0.0.1:${toString forgejo.port} {
              ${forgejoUpstream}
              @trace header Content-Disposition *filename="build-trace-*
              handle_response @trace {
                copy_response
              }
              handle_response {
                respond 404
              }
            }
          }
        '';

        systemd.services.caddy.serviceConfig.EnvironmentFile = lib.mkIf (
          cfg.forgejo.tokenFile != null
        ) cfg.forgejo.tokenFile;
      })
    ]
  );
}
