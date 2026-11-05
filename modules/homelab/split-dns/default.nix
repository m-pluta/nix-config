{
  lib,
  config,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.splitDns;

  # One view per network the resolver host is on, keyed by network name. Unbound
  # selects the view by the query's source subnet, so a name resolves to the address
  # its host has on the client's network.
  views = lib.filterAttrs (_: net: net != null) hl.networks.${cfg.resolverHost};

  # The address `host` has on `network`, or null if it has none there.
  addressOn = network: host: hl.networks.${host}.${network}.v4 or null;
in
{
  options.homelab.splitDns = {
    enable = lib.mkEnableOption "Split-horizon DNS for homelab domains (Unbound)";

    resolverHost = lib.mkOption {
      type = lib.types.str;
      description = ''
        hostName of the host running Unbound. This is independent of `enable` so
        clients can consume it without running Unbound.
      '';
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ hl.mainDomain ];
      description = ''
        Zones answered locally. Names with a record resolve to the host serving them,
        and other names in the zone resolve normally.
      '';
    };

    records = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "git.example.com" = "server";
      };
      description = ''
        Hostname -> hostName of the machine serving it. Each view answers with that
        machine's address on the view's network.
      '';
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
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.concatLists (
      lib.mapAttrsToList (
        network: _:
        lib.mapAttrsToList (name: host: {
          assertion = addressOn network host != null;
          message = "homelab.splitDns: ${name} is served by ${host}, which has no ${network} address";
        }) cfg.records
      ) views
    );

    services.unbound = {
      enable = true;
      # Don't point this host's /etc/resolv.conf at 127.0.0.1, since Unbound doesn't listen there.
      resolveLocalQueries = false;
      settings = {
        server = {
          # The addresses Unbound answers DNS on, one per view.
          interface = lib.mapAttrsToList (_: net: net.v4) views;
          # Bind listen addresses even before they exist (tailscale0 comes up late).
          ip-freebind = true;
          # Only answer clients in a view's subnet, and give each client that view.
          access-control = lib.mapAttrsToList (_: net: "${net.subnet} allow") views;
          access-control-view = lib.mapAttrsToList (network: net: "${net.subnet} ${network}") views;
          # Don't reveal the server's identity or version to clients.
          hide-identity = true;
          hide-version = true;
        };
        view = lib.mapAttrsToList (network: _: {
          name = network;
          # Names without a record fall through to normal resolution.
          local-zone = map (d: ''"${d}." transparent'') cfg.domains;
          local-data = lib.mapAttrsToList (
            name: host: ''"${name}. A ${addressOn network host}"''
          ) cfg.records;
        }) views;
      }
      # Forward all other queries to the upstreams, or recurse from the root servers if none.
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

    # Open DNS (port 53, over both UDP and TCP) on each view's interface only.
    networking.firewall.interfaces = lib.mapAttrs' (
      _: net:
      lib.nameValuePair net.interface {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      }
    ) views;
  };
}
