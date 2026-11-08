{
  lib,
  config,
  inputs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.ingress;

  lan = hl.networks.${config.networking.hostName}.lan.v4 or null;
  lanInterface = hl.networks.${config.networking.hostName}.lan.interface or null;

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

  # Whether certificate name `pattern` (possibly "*.x") covers hostname `name`.
  certCovers =
    pattern: name:
    let
      suffix = lib.removePrefix "*" pattern;
    in
    pattern == name
    || (
      lib.hasPrefix "*." pattern
      && lib.hasSuffix suffix name
      && !lib.hasInfix "." (lib.removeSuffix suffix name)
    );

  # The most specific certificate on this host covering `name` and its aliases.
  certFor =
    name: aliases:
    let
      depth = cert: lib.length (lib.splitString "." cert);
    in
    lib.findFirst
      (cert: lib.all (n: lib.any (p: certCovers p n) cfg.certificates.${cert}) ([ name ] ++ aliases))
      (throw "homelab.ingress: no certificate on ${config.networking.hostName} covers ${name}")
      (lib.sort (a: b: depth a > depth b) (lib.attrNames cfg.certificates));

  # Build the Caddy virtual host for one route. It terminates TLS with the certificate
  # covering its hostname and, when `upstream` is set, proxies requests to it. When
  # `upstream` is null, only the route's own extraConfig is used, which allows vhosts
  # that don't proxy anything, such as static file serving.
  mkIngressVhost = url: r: upstream: {
    useACMEHost = certFor url r.serverAliases;
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
          Service port on 127.0.0.1 that Caddy forwards to. null = a non-proxy
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
      certificates = lib.mkOption {
        type = lib.types.attrsOf (lib.types.nonEmptyListOf lib.types.str);
        default = { };
        apply = lib.mapAttrs (_: lib.unique);
        description = ''
          ACME certificates for this host's routes, domain -> hostnames it covers. Each
          route uses the most specific one covering it.
        '';
      };

      routes = lib.mkOption {
        type = lib.types.attrsOf routeType;
        default = { };
        description = "Routes served by this host (URL -> service).";
      };
    };
  };

  config = lib.mkMerge [
    # Any host that declares routes terminates TLS, obtains the wildcard certificate,
    # and serves one Caddy virtual host per route.
    (lib.mkIf (cfg.routes != { }) {
      assertions = [
        {
          assertion = hl.mainDomain != "";
          message = "homelab.ingress.routes requires homelab.mainDomain to be set";
        }
        {
          assertion = lan != null;
          message = "homelab.networks.${config.networking.hostName}.lan must be set so the ingress is served on the LAN";
        }
      ];

      # Environment file holding CF_DNS_API_TOKEN and CF_API_EMAIL, which ACME uses to
      # prove domain ownership through Cloudflare DNS (the DNS-01 challenge).
      age.secrets.cloudflare-dns-token.file = "${inputs.secrets}/infra/cloudflare/dns-token.age";

      # The main domain and all its subdomains.
      homelab.ingress.certificates.${hl.mainDomain} = [
        hl.mainDomain
        "*.${hl.mainDomain}"
      ];

      # Request each certificate through the DNS challenge, and reload Caddy whenever one
      # is renewed.
      security.acme = {
        acceptTerms = true;
        defaults.email = "mikey@${hl.mainDomain}";
        certs = lib.mapAttrs (cert: hostnames: {
          reloadServices = [ "caddy.service" ];
          domain = cert;
          extraDomainNames = lib.remove cert hostnames;
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1:53";
          dnsPropagationCheck = true;
          group = config.services.caddy.group;
          environmentFile = config.age.secrets.cloudflare-dns-token.path;
        }) cfg.certificates;
      };

      # Allow HTTP and HTTPS in from the LAN interface, and from this host's Podman
      # networks when it runs containers. Caddy listens on all addresses, so opening the
      # ports globally could expose it on the WAN if the router were misconfigured. Other
      # routes into the host need no rule: the tailnet is already a trusted interface,
      # and public traffic arrives through the Cloudflare tunnel on loopback.
      networking.firewall.interfaces =
        lib.genAttrs ([ lanInterface ] ++ lib.optional config.virtualisation.podman.enable "podman+")
          (_: {
            allowedTCPPorts = [
              80
              443
            ];
          });

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
          # Redirect plain HTTP to HTTPS for every certificate's hostnames.
          (lib.genAttrs' (lib.concatLists (lib.attrValues cfg.certificates)) (
            hostname: lib.nameValuePair "http://${hostname}" { extraConfig = "redir https://{host}{uri}"; }
          ))
          # Answer 404 for any subdomain that has no route declared.
          {
            "*.${hl.mainDomain}" = {
              useACMEHost = certFor "*.${hl.mainDomain}" [ ];
              extraConfig = "respond 404";
            };
          }
          # One virtual host per declared route. Routes with a port proxy to that port on
          # this machine's loopback address.
          (lib.mapAttrs (
            url: r:
            mkIngressVhost url r (if r.port == null then null else "http://127.0.0.1:${toString r.port}")
          ) cfg.routes)
        ];
      };
    })
  ];
}
