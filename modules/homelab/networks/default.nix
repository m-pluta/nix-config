{ lib, ... }:
let
  mkNetworkType =
    defaults:
    lib.types.submodule (
      { config, ... }:
      {
        options = {
          v4 = lib.mkOption {
            type = lib.types.str;
            description = "IPv4 address.";
          };
          interface = lib.mkOption {
            type = lib.types.str;
            description = "Interface carrying this address.";
          };
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "CIDR of the network this address belongs to.";
          };
          prefixLength = lib.mkOption {
            type = lib.types.int;
            readOnly = true;
            default = lib.toInt (lib.last (lib.splitString "/" config.subnet));
            description = "Prefix length of `subnet`.";
          };
        };
        config = lib.mapAttrs (_: lib.mkDefault) defaults;
      }
    );
in
{
  options.homelab.networks = lib.mkOption {
    default = { };
    description = "Network addresses of every homelab host, keyed by hostName.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          lan = lib.mkOption {
            # Site-specific, so nothing is defaulted.
            type = lib.types.nullOr (mkNetworkType { });
            default = null;
            description = "Stable LAN address, or null if the host has none.";
          };
          mesh = lib.mkOption {
            type = lib.types.nullOr (mkNetworkType {
              subnet = "100.64.0.0/10";
              interface = "tailscale0";
            });
            default = null;
            description = "Mesh VPN address (currently Tailscale), or null if the host has none.";
          };
        };
      }
    );
  };
}
