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
        # Tolerate the Tailscale address appearing after startup instead of failing hard with exit 2
        bind-dynamic = true;
        port = 53;
        server = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        no-hosts = true;
      };
    };

    # tailscale0 brings up 100.120.225.75 asynchronously; without ordering,
    # dnsmasq starts first, can't bind, and exhausts its restart budget
    systemd.services.dnsmasq = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };

    networking.firewall.interfaces.tailscale0.allowedUDPPorts = [ 53 ];
  };
}
