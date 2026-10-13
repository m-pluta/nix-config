{ lib, config, ... }:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "The homelab services and configuration variables";
    description = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Short description of this host's role in the homelab, shown in the README.";
      example = "Primary server hosting the self-hosted services";
    };
    groups = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      description = "Shared groups for cross-service access. Keys are group names, values are GIDs.";
      example = {
        media = 15000;
      };
    };
    timeZone = lib.mkOption {
      default = "Europe/Berlin";
      type = lib.types.str;
      description = ''
        Time zone to be used for the homelab services
      '';
    };
    mainDomain = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        Main domain name, used to build the homelab service URLs and for the ingress certificate
      '';
    };
  };
  imports = [
    ./cloudflared
    ./ingress
    ./motd
    ./networks
    ./samba
    ./services
    ./split-dns
    ./tailscale
    ./wireguard-netns
  ];
  config = lib.mkIf cfg.enable {
    users.groups = lib.mapAttrs (_name: gid: { inherit gid; }) cfg.groups;
  };
}
