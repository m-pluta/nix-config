{
  lib,
  config,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.dnsmasq;
in
{
  options.homelab.dnsmasq = {
    enable = lib.mkEnableOption "Split DNS for homelab services via dnsmasq";
    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Domains to resolve via split DNS";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hl.tailscale.address != null;
        message = "homelab.dnsmasq requires homelab.tailscale.address to be set";
      }
    ];

    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        address = map (domain: "/${domain}/${hl.tailscale.address}") cfg.domains;
        listen-address = hl.tailscale.address;
        port = 53;
        no-resolv = true;
        no-hosts = true;
      };
    };
    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];
  };
}
