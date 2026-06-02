{
  config,
  lib,
  ...
}:
let
  service = "microbin";
  serviceLib = import ../lib.nix { inherit lib; };
  homelab = config.homelab;
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8069;
      url = "bin.${homelab.baseDomain}";
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
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
    };
  config = lib.mkIf cfg.enable {
    services.${service} = {
      enable = true;
      settings = {
        MICROBIN_WIDE = true;
        MICROBIN_PUBLIC_PATH = "https://${cfg.url}/";
        MICROBIN_BIND = "127.0.0.1";
        MICROBIN_PORT = toString cfg.port;
        MICROBIN_MAX_FILE_SIZE_UNENCRYPTED_MB = 2048;
        MICROBIN_ETERNAL_PASTA = true;
        MICROBIN_HIDE_FOOTER = true;
        MICROBIN_HIGHLIGHTSYNTAX = true;
        MICROBIN_DISABLE_TELEMETRY = true;
      };
    }
    // lib.optionalAttrs (cfg.passwordFile != null) {
      passwordFile = cfg.passwordFile;
    };
    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = homelab.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
