{
  config,
  pkgs,
  lib,
  ...
}:
let
  nordHighlight = builtins.toFile "nord.css" (builtins.readFile ./nord.css);
  nordUi = builtins.toFile "nord_ui.css" (builtins.readFile ./nord_ui.css);
  highlightJsNix = pkgs.fetchurl {
    url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/languages/nix.min.js";
    hash = "sha256-j4dmtrr8qUODoICuOsgnj1ojTAmxbKe00mE5sfElC/I=";
  };
  highlightJs = pkgs.fetchurl {
    url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.1/highlight.min.js";
    hash = "sha256-xKOZ3W9Ii8l6NUbjR2dHs+cUyZxXuUcxVMb7jSWbk4E=";
  };
  service = "microbin";
  serviceLib = import ../lib.nix { inherit lib; };
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8069;
      url = "bin.goose.party";
      configDir = "/var/lib/microbin";
      homepage = {
        name = "Microbin";
        description = "A minimal pastebin";
        icon = "microbin.png";
        category = "Services";
      };
    }
    // {
      passwordFile = lib.mkOption {
        default = "";
        type = lib.types.str;
        example = lib.literalExpression ''
          pkgs.writeText "microbin-secret.txt" '''
            MICROBIN_ADMIN_USERNAME
            MICROBIN_ADMIN_PASSWORD
            MICROBIN_UPLOADER_PASSWORD
          '''
        '';
      };
      role = lib.mkOption {
        type = lib.types.enum [
          "client"
          "server"
        ];
        default = "client";
      };
    };
  config =
    let
      mkIfElse =
        p: yes: no:
        lib.mkMerge [
          (lib.mkIf p yes)
          (lib.mkIf (!p) no)
        ];
      addr = "127.0.0.1";
    in
    mkIfElse (cfg.role == "client")
      (lib.mkIf cfg.enable {
        nixpkgs.overlays = with pkgs; [
          (_final: prev: {
            microbin = prev.microbin.overrideAttrs (
              _finalAttrs: _previousAttrs: {
                postPatch = ''
                  cp ${nordHighlight} templates/assets/highlight/highlight.min.css
                  cp ${highlightJs} templates/assets/highlight/highlight.min.js
                  cp ${highlightJsNix} templates/assets/highlight/nix.min.js
                  echo "" >> templates/assets/water.css
                  cat ${nordUi} >> templates/assets/water.css
                  sed -i "s#<option value=\"auto\">#<option value=\"auto\" selected>#" templates/index.html
                  sed -i "s#highlight.min.js\"></script>#highlight.min.js\"></script><script type=\"text/javascript\" src=\"{{ args.public_path_as_str() }}/static/highlight/nix.min.js\"></script>#" templates/upload.html
                '';
              }
            );
          })
        ];
        services = {
          ${service} = {
            enable = true;
            settings = {
              MICROBIN_WIDE = true;
              MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB = 2048;
              MICROBIN_PUBLIC_PATH = "https://${cfg.url}/";
              MICROBIN_BIND = addr;
              MICROBIN_PORT = toString cfg.port;
              MICROBIN_HIDE_LOGO = true;
              MICROBIN_HIGHLIGHTSYNTAX = true;
              MICROBIN_HIDE_HEADER = true;
              MICROBIN_HIDE_FOOTER = true;
            };
          }
          // lib.attrsets.optionalAttrs (cfg.passwordFile != "") {
            passwordFile = cfg.passwordFile;
          };
          frp.settings.proxies = [
            {
              name = service;
              type = "tcp";
              localIP = addr;
              localPort = cfg.port;
              remotePort = cfg.port;
            }
          ];
        };
      })
      # server
      {
        services.caddy.virtualHosts."${cfg.url}" = {
          useACMEHost = "goose.party";
          extraConfig = ''
            handle {
              forward_auth 127.0.0.1:4192 {
                uri https://login.goose.party/oauth2/auth
                header_up X-Real-IP {remote_host}
                @error status 401
                handle_response @error {
                  redir * https://login.goose.party/oauth2/start?rd={scheme}://{host}{uri}
                }
              }
              reverse_proxy http://${addr}:${toString cfg.port}
            }
            @noauth path /p/* /static/* file/* /static/highlight/*
            handle @noauth {
              reverse_proxy http://${addr}:${toString cfg.port}
            }
          '';
        };
      };
}
