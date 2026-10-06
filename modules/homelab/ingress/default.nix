{
  lib,
  config,
  inputs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.ingress;

  isIngressHost = cfg.ingressHost == config.networking.hostName;
  lan = hl.networks.${config.networking.hostName}.lan.v4 or null;
  lanInterface = hl.networks.${config.networking.hostName}.lan.interface or null;
  ingressHostAddress = hl.networks.${cfg.ingressHost}.lan.v4 or null;
  trustedIngressAddress = if ingressHostAddress == null then "127.0.0.1" else ingressHostAddress;

  proxyRoutes = lib.filterAttrs (_url: r: r.port != null);
  hasServiceRoutes = (proxyRoutes cfg.routes) != { };

  # Build the Caddy reverse_proxy block that forwards a request to `upstream`. The
  # client address headers are overwritten with the address Caddy has verified, instead
  # of appending to whatever the client sent. Together with strict trusted-proxy parsing
  # (see the global Caddy config below), this stops clients from spoofing their address.
  mkReverseProxy = upstream: ''
    reverse_proxy ${upstream} {
      header_up X-Forwarded-For {client_ip}
      header_up X-Real-IP {client_ip}
      header_up -CF-Connecting-IP
    }
  '';

  # Build the Caddy virtual host for one route. It terminates TLS with the shared
  # wildcard certificate and, when `upstream` is set, proxies requests to it. When
  # `upstream` is null, only the route's own extraConfig is used, which allows vhosts
  # that don't proxy anything, such as static file serving.
  mkIngressVhost = r: upstream: {
    useACMEHost = hl.mainDomain;
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
        type = lib.types.str;
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
    # Only the ingress host runs this part. It terminates TLS, obtains the wildcard
    # certificate, and serves one Caddy virtual host per declared route, whether the
    # service runs on this host or on another one.
    (lib.mkIf isIngressHost {
      assertions = [
        {
          assertion = hl.mainDomain != "";
          message = "homelab.ingress ingressHost requires homelab.mainDomain to be set";
        }
        {
          assertion = lan != null;
          message = "homelab.networks.${config.networking.hostName}.lan must be set so the ingress is served on the LAN";
        }
      ];

      # Environment file holding CF_DNS_API_TOKEN and CF_API_EMAIL, which ACME uses to
      # prove domain ownership through Cloudflare DNS (the DNS-01 challenge).
      age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare/dns-api.age";

      # Request a single wildcard certificate for the main domain and all its subdomains,
      # and reload Caddy whenever it is renewed.
      security.acme = {
        acceptTerms = true;
        defaults.email = "mikey@${hl.mainDomain}";
        certs.${hl.mainDomain} = {
          reloadServices = [ "caddy.service" ];
          domain = hl.mainDomain;
          extraDomainNames = [ "*.${hl.mainDomain}" ];
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          dnsPropagationCheck = true;
          group = config.services.caddy.group;
          environmentFile = config.age.secrets.cloudflare-dns-api.path;
        };
      };

      # Allow HTTP and HTTPS in from the LAN interface only. Caddy listens on all
      # addresses, so opening the ports globally could expose it on the WAN if the router
      # were misconfigured. Other routes into the host need no rule: the tailnet is
      # already a trusted interface, and public traffic arrives through the Cloudflare
      # tunnel on loopback.
      networking.firewall.interfaces.${lanInterface}.allowedTCPPorts = [
        80
        443
      ];

      services.caddy = {
        enable = true;
        globalConfig = ''
          auto_https off
          servers {
            # Cloudflared connects to Caddy over loopback, so loopback is the only source
            # trusted to supply the real client address in the Cloudflare and
            # X-Forwarded-For headers. Requests from anywhere else have those headers
            # ignored.
            trusted_proxies static 127.0.0.0/8 ::1/128
            trusted_proxies_strict
            client_ip_headers CF-Connecting-IP X-Forwarded-For
          }
        '';
        virtualHosts = lib.mkMerge [
          # Redirect plain HTTP to HTTPS, and answer 404 for any subdomain that has no
          # route declared.
          {
            "http://${hl.mainDomain}".extraConfig = "redir https://{host}{uri}";
            "http://*.${hl.mainDomain}".extraConfig = "redir https://{host}{uri}";
            "*.${hl.mainDomain}" = {
              useACMEHost = hl.mainDomain;
              extraConfig = "respond 404";
            };
          }
          # One virtual host per declared route. Routes with a port proxy to that port on
          # this machine's loopback address, because these services run on the ingress host.
          (lib.mapAttrs (
            _: r: mkIngressVhost r (if r.port == null then null else "http://127.0.0.1:${toString r.port}")
          ) cfg.routes)
          # One virtual host per route for a service on another host, proxied over the LAN
          # to the service proxy running on that host.
          (lib.mapAttrs (
            _: r: mkIngressVhost r (if r.port == null then null else "http://${r.lanIP}:80")
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
            # Only the ingress host may connect, so ingress-level policy can't be bypassed.
            extraConfig = ''
              bind ${lan}
              @direct not remote_ip ${trustedIngressAddress}
              respond @direct 403
              ${mkReverseProxy "http://127.0.0.1:${toString r.port}"}
            '';
          }
        ) (proxyRoutes cfg.routes);
      };
    })
  ];
}
