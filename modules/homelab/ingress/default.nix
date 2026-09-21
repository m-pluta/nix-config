{
  lib,
  config,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.ingress;

  isIngressHost = cfg.ingressHost != null && cfg.ingressHost == config.networking.hostName;
  lan = hl.networks.${config.networking.hostName}.lan or null;
  lanInterface = hl.networks.${config.networking.hostName}.lanInterface or null;
  ingressHostAddress =
    if cfg.ingressHost == null then null else hl.networks.${cfg.ingressHost}.lan or null;
  trustedIngressAddress = if ingressHostAddress == null then "127.0.0.1" else ingressHostAddress;

  proxyRoutes = lib.filterAttrs (_url: r: r.port != null);
  hasServiceRoutes = (proxyRoutes cfg.routes) != { };

  # Replace, rather than append to, X-Forwarded-For at each controlled hop. Combined
  # with strict trusted-proxy parsing this prevents clients from spoofing their address.
  mkReverseProxy = upstream: ''
    reverse_proxy ${upstream} {
      header_up X-Forwarded-For {client_ip}
      header_up X-Real-IP {client_ip}
      header_up -CF-Connecting-IP
    }
  '';

  # Ingress-host vhost: TLS-terminated, proxies to `upstream` (null = serve extraConfig verbatim).
  mkIngressVhost = _url: r: upstream: {
    useACMEHost = hl.baseDomain;
    serverAliases = r.serverAliases;
    extraConfig = lib.concatStringsSep "\n" (
      lib.filter (s: s != "") [
        (lib.optionalString (upstream != null) (mkReverseProxy upstream))
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
          Service port on 127.0.0.1. The service proxy forwards to it; the ingress host
          forwards to the service host. null = a non-proxy vhost rendered verbatim from
          `extraConfig` on the ingress host (e.g. static file serving).
        '';
      };
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Caddy directives for this vhost, applied at the ingress host.";
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
    ingress = {
      ingressHost = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "mikeway";
        description = ''
          hostName of the host running public ingress (TLS termination + tunnel).
          That host renders the ingress Caddy configuration; every other host with proxy
          routes runs a service proxy.
        '';
      };

      routes = lib.mkOption {
        type = lib.types.attrsOf routeType;
        default = { };
        description = "Ingress routes served by this host (URL -> service), auto-published to the ingress host.";
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
        description = "Routes for services on other hosts, injected by the flake for the ingress host to proxy to.";
      };
    };
  };

  config = lib.mkMerge [
    # Ingress host: public TLS, ACME wildcard cert, per-service vhosts (local + remote).
    (lib.mkIf isIngressHost {
      assertions = [
        {
          assertion = hl.baseDomain != "";
          message = "homelab.ingress ingressHost requires homelab.baseDomain to be set";
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

      # The ingress host opens 80/443 on its client-facing interface(s) itself:
      # Caddy binds 0.0.0.0, so a router must not expose it on the WAN side.
      services.caddy = {
        enable = true;
        globalConfig = ''
          auto_https off
          servers {
            # Cloudflared connects to 127.0.0.1:443. Only loopback may supply
            # Cloudflare/X-Forwarded client addresses.
            trusted_proxies static 127.0.0.0/8 ::1/128
            trusted_proxies_strict
            client_ip_headers CF-Connecting-IP X-Forwarded-For
          }
        '';
        virtualHosts = lib.mkMerge [
          {
            "http://${hl.baseDomain}".extraConfig = "redir https://{host}{uri}";
            "http://*.${hl.baseDomain}".extraConfig = "redir https://{host}{uri}";
            "*.${hl.baseDomain}" = {
              useACMEHost = hl.baseDomain;
              extraConfig = "respond 404";
            };
          }
          # Services local to the ingress host -> localhost.
          (lib.mapAttrs (
            _url: r:
            mkIngressVhost _url r (if r.port == null then null else "http://127.0.0.1:${toString r.port}")
          ) cfg.routes)
          # Services on other hosts -> that host's service proxy over the LAN.
          (lib.mapAttrs (
            _url: r: mkIngressVhost _url r (if r.port == null then null else "http://${r.lanIP}:80")
          ) cfg.remoteRoutes)
        ];
      };
    })

    # Service proxy: plain HTTP on the LAN, proxies each local service to localhost. No TLS.
    (lib.mkIf (!isIngressHost && hasServiceRoutes) {
      assertions = [
        {
          assertion = lan != null;
          message = "homelab.networks.${config.networking.hostName}.lan must be set so the ingress host can reach this service proxy";
        }
        {
          assertion = ingressHostAddress != null;
          message = "homelab.networks.${toString cfg.ingressHost}.lan must be set so service proxies can trust the ingress host";
        }
        {
          assertion = lanInterface != null;
          message = "homelab.networks.${config.networking.hostName}.lanInterface must be set to expose the service proxy only on the LAN";
        }
      ];

      networking.firewall.interfaces.${lanInterface}.allowedTCPPorts = [ 80 ];

      services.caddy = {
        enable = true;
        globalConfig = ''
          auto_https off
          servers {
            # Only the ingress host may supply a forwarded client address.
            trusted_proxies static ${trustedIngressAddress}/32
            trusted_proxies_strict
            client_ip_headers X-Forwarded-For
          }
        '';
        virtualHosts = lib.mapAttrs' (
          url: r:
          lib.nameValuePair "http://${url}" {
            extraConfig = ''
              bind ${lan}
              ${mkReverseProxy "http://127.0.0.1:${toString r.port}"}
            '';
          }
        ) (proxyRoutes cfg.routes);
      };
    })
  ];
}
