{ lib, ... }:
let
  networkType = lib.types.submodule {
    options = {
      v4 = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "IPv4 address.";
      };
      interface = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Interface carrying this address.";
      };
    };
  };
in
{
  options.homelab.networks = lib.mkOption {
    default = { };
    description = ''
      Every homelab host's network identity, keyed by hostName. Hosts are built as
      independent NixOS systems with no visibility into each other's config, so this
      is the one place cross-host addresses (reverse-proxy targets, split-DNS
      answers, static DHCP leases) get typed — set once in
      modules/machines/nixos/_common/networks.nix, read everywhere via
      `config.homelab.networks.<hostName>`.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          lan = lib.mkOption {
            type = networkType;
            default = { };
            description = "Stable LAN address.";
          };
          mesh = lib.mkOption {
            type = networkType;
            default = { };
            description = "Mesh VPN address (currently Tailscale).";
          };
        };
      }
    );
  };
}
