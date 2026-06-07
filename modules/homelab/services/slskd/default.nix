{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "slskd";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  ns = hl.wireguard-netns.namespace;
in
{
  imports = [ ./beets.nix ];
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 5030;
      url = "slskd.${hl.baseDomain}";
      configDir = "/var/lib/${service}";
      homepage = {
        name = "slskd";
        description = "Web-based Soulseek client";
        icon = "slskd.svg";
        category = "Downloads";
      };
    }
    // {
      musicDir = lib.mkOption {
        type = lib.types.str;
        default = "${hl.mounts.fast}/Media/Music/Library";
      };
      downloadDir = lib.mkOption {
        type = lib.types.str;
        default = "${hl.mounts.fast}/Media/Music/Import";
      };
      incompleteDownloadDir = lib.mkOption {
        type = lib.types.str;
        default = "${hl.mounts.fast}/Media/Music/Import.tmp";
      };
      beetsConfigFile = lib.mkOption {
        type = lib.types.path;
      };
      environmentFile = lib.mkOption {
        description = "File with slskd credentials";
        type = lib.types.path;
        example = lib.literalExpression ''
          pkgs.writeText "slskd-env" '''
            SLSKD_PASSWORD=slskd
            SLSKD_USERNAME=slskd
            SLSKD_JWT=secret
          '''
        '';
      };
    };
  config = lib.mkIf cfg.enable {
    users.users.${service}.extraGroups = [ "media" ];
    services.${service} = {
      enable = true;
      environmentFile = cfg.environmentFile;
      domain = null;
      settings = {
        integration.scripts.slskd-import-files = {
          on = [
            "DownloadDirectoryComplete"
            "DownloadFileComplete"
          ];
          run =
            let
              slskd-import-files = pkgs.writeScriptBin "slskd-import-files" ''
                #!${lib.getExe pkgs.bash}
                cd ${cfg.musicDir}/.beets
                HOME=${cfg.musicDir}/.beets ${lib.getExe pkgs.beets} -c ${cfg.beetsConfigFile} import -m -A -q ${cfg.downloadDir}
              '';
            in
            {
              executable = "${lib.getExe pkgs.bash}";
              command = "-c ${lib.getExe slskd-import-files}";
            };
        };
        directories = {
          downloads = cfg.downloadDir;
          incomplete = cfg.incompleteDownloadDir;
        };
        shares = {
          directories = [ cfg.musicDir ];
          filters = [
            "\.ini$"
            "Thumbs.db$"
            "\.DS_Store$"
          ];
        };
      };
    };
    systemd.sockets = lib.mkIf hl.wireguard-netns.enable {
      "slskd-web-proxy" = {
        enable = true;
        description = "Socket for Proxy to slskd WebUI";
        listenStreams = [ (toString cfg.port) ];
        wantedBy = [ "sockets.target" ];
      };
    };
    systemd.services = {
      slskd = {
        serviceConfig.ReadWritePaths = [
          cfg.musicDir
        ];
        serviceConfig.ReadOnlyPaths = lib.mkForce [ ];
        serviceConfig.NetworkNamespacePath = lib.attrsets.optionalAttrs hl.wireguard-netns.enable [
          "/var/run/netns/${ns}"
        ];
      }
      // lib.attrsets.optionalAttrs hl.wireguard-netns.enable {
        bindsTo = [ "netns@${ns}.service" ];
        environment = {
          DOTNET_USE_POLLING_FILE_WATCHER = "true";
        };
        requires = [
          "network-online.target"
          "${ns}.service"
        ];
      };
      "slskd-web-proxy" = lib.attrsets.optionalAttrs hl.wireguard-netns.enable {
        enable = true;
        description = "Proxy to slskd WebUI in Network Namespace";
        requires = [
          "slskd.service"
          "slskd-web-proxy.socket"
        ];
        after = [
          "slskd.service"
          "slskd-web-proxy.socket"
        ];
        unitConfig = {
          JoinsNamespaceOf = "slskd.service";
        };
        serviceConfig = {
          User = config.services.slskd.user;
          Group = config.services.slskd.group;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:${toString cfg.port}";
          PrivateNetwork = "yes";
        };
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
