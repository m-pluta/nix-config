{ lib, ... }:
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
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "192.168.100.10";
            description = "Stable LAN IPv4 address.";
          };
          tailscale = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "100.120.225.75";
            description = "Tailscale IPv4 address.";
          };
        };
      }
    );
  };
}
