{
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.splitDns;
in
{
  options.homelab.splitDns = {
    enable = lib.mkEnableOption "Split-horizon DNS for homelab domains (Unbound)";

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Domains answered locally (wildcard-redirected per view) instead of resolved normally.";
    };

    upstreams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      description = ''
        Forwarders for everything outside `domains`. Set to [ ] for full recursion
        (Unbound talks to the root servers directly, nothing leaks to a public resolver).
      '';
    };

    views = lib.mkOption {
      description = ''
        One Unbound view per network. Unbound selects the view by the query's *source*
        subnet (access-control-view), so the same name resolves to `answer` appropriate to
        where the client is — a LAN client gets the LAN address, a tailnet client the tailnet
        address. Source-based selection is why this works on a Tailscale /32, where dnsmasq's
        interface-based localise-queries cannot.
      '';
      default = [ ];
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "View name (must be unique).";
            };
            interface = lib.mkOption {
              type = lib.types.str;
              description = "Interface to open port 53 on.";
            };
            listen = lib.mkOption {
              type = lib.types.str;
              description = "Address Unbound binds/answers on for this view.";
            };
            subnet = lib.mkOption {
              type = lib.types.str;
              example = "192.168.100.0/24";
              description = "Client source CIDR that selects this view.";
            };
            answer = lib.mkOption {
              type = lib.types.str;
              description = "Address the split domains resolve to for clients in this view.";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.views != [ ];
        message = "homelab.splitDns.views must not be empty when enabled";
      }
    ];

    services.unbound = {
      enable = true;
      # We manage /etc/resolv.conf and forwarding ourselves; don't let the module
      # point the local resolver at 127.0.0.1.
      resolveLocalQueries = false;
      settings = {
        server = {
          interface = map (v: v.listen) cfg.views;
          # Bind listen addresses even before they exist (tailscale0 comes up late).
          ip-freebind = true;
          access-control = map (v: "${v.subnet} allow") cfg.views;
          access-control-view = map (v: "${v.subnet} ${v.name}") cfg.views;
          hide-identity = true;
          hide-version = true;
        };
        view = map (v: {
          name = v.name;
          view-first = true;
          local-zone = map (d: ''"${d}." redirect'') cfg.domains;
          local-data = map (d: ''"${d}. A ${v.answer}"'') cfg.domains;
        }) cfg.views;
      }
      // lib.optionalAttrs (cfg.upstreams != [ ]) {
        forward-zone = [
          {
            name = ".";
            forward-addr = cfg.upstreams;
          }
        ];
      };
    };

    # tailscale0's address appears asynchronously; hold Unbound until tailscaled is up.
    systemd.services.unbound.after = [ "tailscaled.service" ];
    systemd.services.unbound.wants = [ "tailscaled.service" ];

    networking.firewall.interfaces = lib.listToAttrs (
      map (
        v:
        lib.nameValuePair v.interface {
          allowedUDPPorts = [ 53 ];
          allowedTCPPorts = [ 53 ];
        }
      ) cfg.views
    );
  };
}
