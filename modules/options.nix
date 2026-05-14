{ lib, ... }:
{
  options.my = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "mpluta.dev";
      description = "Public domain under which my services are published";
    };
    tailnet = lib.mkOption {
      type = lib.types.str;
      default = "tail5724d6.ts.net";
      description = "Tailscale MagicDNS domain";
    };
  };
}
