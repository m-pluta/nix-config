{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.homelab.tailscale;
in
{
  options.homelab.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
    address = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Tailscale IP address of this host";
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
