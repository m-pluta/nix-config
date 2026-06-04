{ lib, config, ... }:
let
  cfg = config.homelab;
in
{
  options.homelab = {
    enable = lib.mkEnableOption "The homelab services and configuration variables";
    mounts.slow = lib.mkOption {
      default = "/mnt/mergerfs_slow";
      type = lib.types.path;
      description = ''
        Path to the 'slow' tier mount
      '';
    };
    mounts.fast = lib.mkOption {
      default = "/mnt/cache";
      type = lib.types.path;
      description = ''
        Path to the 'fast' tier mount
      '';
    };
    mounts.config = lib.mkOption {
      default = "/persist/opt/services";
      type = lib.types.path;
      description = ''
        Path to the service configuration files
      '';
    };
    mounts.merged = lib.mkOption {
      default = "/mnt/user";
      type = lib.types.path;
      description = ''
        Path to the merged tier mount
      '';
    };
    mediaGroup = lib.mkOption {
      default = "media";
      type = lib.types.str;
      description = "Shared group for media access across services";
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
    ./backup
    ./services
    ./samba
    ./networks
    ./motd
    ./fail2ban-cloudflare
    ./cloudflared
    ./dnsmasq
    ./tailscale
    ./wireguard-netns
  ];
  config = lib.mkIf cfg.enable {
    users.groups.${cfg.mediaGroup} = {
      gid = 15000;
    };
  };
}
