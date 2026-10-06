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
          Service port on 127.0.0.1 that the ingress host forwards to. null = a non-proxy
          vhost rendered verbatim from `extraConfig` (e.g. static file serving).
        '';
      };
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra Caddy directives for this vhost.";
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
          That host renders the ingress Caddy configuration.
        '';
      };

      routes = lib.mkOption {
        type = lib.types.attrsOf routeType;
        default = { };
        description = "Ingress routes served by this host (URL -> service).";
      };
    };
  };

  config = lib.mkMerge [
    # Ingress host: public TLS, ACME wildcard cert, per-service vhosts.
    (lib.mkIf isIngressHost {
      assertions = [
        {
          assertion = hl.baseDomain != "";
          message = "homelab.ingress ingressHost requires homelab.baseDomain to be set";
        }
        {
          assertion = lan != null;
          message = "homelab.networks.${config.networking.hostName}.lan must be set so the ingress is served on the LAN";
        }
      ];

      # Env file with CF_DNS_API_TOKEN and CF_API_EMAIL for the DNS-01 challenge.
      age.secrets.cloudflare-dns-api.file = "${inputs.secrets}/network/cloudflare/dns-api.age";

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
          environmentFile = config.age.secrets.cloudflare-dns-api.path;
        };
      };

      # Caddy binds 0.0.0.0, so only the LAN is opened and a router never exposes it on
      # the WAN. The tailnet is already a trusted interface, and public access arrives
      # via the tunnel on loopback.
      networking.firewall.interfaces.${lanInterface}.allowedTCPPorts = [
        80
        443
      ];

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
        ];
      };
    })
  ];
}
