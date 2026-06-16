{ lib, config, ... }:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "The homelab services and configuration variables";
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
    baseDomain = lib.mkOption {
      default = "";
      type = lib.types.str;
      description = ''
        Base domain name to be used to access the homelab services via Caddy reverse proxy
      '';
    };
    cloudflare.dnsCredentialsFile = lib.mkOption {
      type = lib.types.path;
      example = ''
        CF_DNS_API_TOKEN=verybigsecret
        CF_API_EMAIL=foo@bar.com
      '';
    };
  };
  imports = [
    ./services
    ./samba
    ./motd
    ./fail2ban-cloudflare
    ./cloudflared
    ./dnsmasq
    ./tailscale
    ./wireguard-netns
  ];
  config = lib.mkIf cfg.enable {
    users.groups = lib.mapAttrs (_name: gid: { inherit gid; }) cfg.groups;
  };
}
