{
  lib,
  config,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.ingress;

  isFrontDoor = cfg.frontDoor != null && cfg.frontDoor == config.networking.hostName;

  proxyRoutes = lib.filterAttrs (_url: r: r.port != null);
  hasLocalBackends = (proxyRoutes cfg.routes) != { };

  # Front-door vhost: TLS-terminated, proxies to `upstream` (null = serve extraConfig verbatim).
  mkFrontVhost = _url: r: upstream: {
    useACMEHost = hl.baseDomain;
    serverAliases = r.serverAliases;
    extraConfig = lib.concatStringsSep "\n" (
      lib.filter (s: s != "") [
        (lib.optionalString (upstream != null) "reverse_proxy ${upstream}")
        r.extraConfig
      ]
    );
  };

  routeType = lib.types.submodule {
    options = {
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = ''
          Backend port on 127.0.0.1. The thin backend Caddy proxies to it; the front door
          proxies to the backend host. null = a non-proxy vhost rendered verbatim from
          `extraConfig` on the front door (e.g. static file serving).
        '';
      };
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Caddy directives for this vhost, applied at the front door.";
      };
      serverAliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional hostnames served by this vhost.";
      };
    };
  };
in
{
  options.homelab = {
    net.lan = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = hl.networks.${config.networking.hostName}.lan or null;
      example = "192.168.100.10";
      description = ''
        This host's stable LAN IPv4 address (the reverse-proxy upstream from the front
        door). Defaults from `homelab.networks.<hostName>.lan`.
      '';
    };

    ingress = {
      frontDoor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "mikeway";
        description = ''
          hostName of the host running the public front door (TLS termination + tunnel).
          That host renders the front-door Caddy; every other host with proxy routes runs a
          thin backend Caddy.
        '';
      };

      routes = lib.mkOption {
        type = lib.types.attrsOf routeType;
        default = { };
        description = "Ingress routes served by this host (URL -> backend), auto-published to the front door.";
      };

      remoteRoutes = lib.mkOption {
        internal = true;
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              lanIP = lib.mkOption { type = lib.types.str; };
              port = lib.mkOption {
                type = lib.types.nullOr lib.types.port;
                default = null;
              };
              extraConfig = lib.mkOption {
                type = lib.types.lines;
                default = "";
              };
              serverAliases = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
            };
          }
        );
        description = "Routes for services on other hosts, injected by the flake for the front door to proxy to.";
      };
    };
  };

  config = lib.mkMerge [
    # Front door: public TLS, ACME wildcard cert, per-service vhosts (local + remote).
    (lib.mkIf isFrontDoor {
      assertions = [
        {
          assertion = hl.baseDomain != "";
          message = "homelab.ingress front door requires homelab.baseDomain to be set";
        }
      ];

      security.acme = {
        acceptTerms = true;
        defaults.email = "mikey@${hl.baseDomain}";
        certs.${hl.baseDomain} = {
          reloadServices = [ "caddy.service" ];
          domain = hl.baseDomain;
          extraDomainNames = [ "*.${hl.baseDomain}" ];
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          dnsPropagationCheck = true;
          group = config.services.caddy.group;
          environmentFile = hl.cloudflare.dnsCredentialsFile;
        };
      };

      # The front-door host opens 80/443 on its client-facing interface(s) itself:
      # Caddy binds 0.0.0.0, so a router must not expose it on the WAN side.
      services.caddy = {
        enable = true;
        globalConfig = "auto_https off";
        virtualHosts = lib.mkMerge [
          {
            "http://${hl.baseDomain}".extraConfig = "redir https://{host}{uri}";
            "http://*.${hl.baseDomain}".extraConfig = "redir https://{host}{uri}";
            "*.${hl.baseDomain}" = {
              useACMEHost = hl.baseDomain;
              extraConfig = "respond 404";
            };
          }
          # Local services on the front door -> localhost.
          (lib.mapAttrs (
            _url: r:
            mkFrontVhost _url r (if r.port == null then null else "http://127.0.0.1:${toString r.port}")
          ) cfg.routes)
          # Services on other hosts -> that host's thin backend Caddy over the LAN.
          (lib.mapAttrs (
            _url: r: mkFrontVhost _url r (if r.port == null then null else "http://${r.lanIP}:80")
          ) cfg.remoteRoutes)
        ];
      };
    })

    # Thin backend: plain HTTP on the LAN, proxies each local service to localhost. No TLS.
    (lib.mkIf (!isFrontDoor && hasLocalBackends) {
      assertions = [
        {
          assertion = hl.net.lan != null;
          message = "homelab.net.lan must be set on a backend host so the front door can reach it";
        }
      ];

      networking.firewall.allowedTCPPorts = [ 80 ];

      services.caddy = {
        enable = true;
        globalConfig = "auto_https off";
        virtualHosts = lib.mapAttrs' (
          url: r:
          lib.nameValuePair "http://${url}" {
            extraConfig = ''
              bind ${hl.net.lan}
              reverse_proxy http://127.0.0.1:${toString r.port}
            '';
          }
        ) (proxyRoutes cfg.routes);
      };
    })
  ];
}
