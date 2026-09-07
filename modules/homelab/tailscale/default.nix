{
  lib,
  config,
  inputs,
  ...
}:
let
  service = "tailscale";
  cfg = config.homelab.${service};
in
{
  options.homelab.${service} = {
    enable = lib.mkEnableOption "Tailscale VPN";
    address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.homelab.networks.${config.networking.hostName}.tailscale or null;
      description = "Tailscale IP address of this host. Defaults from `homelab.networks.<hostName>.tailscale`.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      trustedInterfaces = [ "tailscale0" ];
      checkReversePath = "loose";
    };

    age.secrets.tailscale-auth-key.file = "${inputs.secrets}/network/tailscale/auth-key.age";

    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = lib.mkDefault "client";
      authKeyFile = config.age.secrets.tailscale-auth-key.path;
    };
  };
}
