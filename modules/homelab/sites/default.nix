{
  lib,
  config,
  pkgs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.sites;
  root = "/var/lib/sites";

  # Run as the forced command for a site's deploy key, with the site's domain as its
  # argument: `deploy <domain> <env> <store path>`, `remove <domain> <env>` or
  # `current <domain> <env>`, where env is prod, qa or pr-<n>.
  deployCommand = pkgs.writeShellApplication {
    name = "sites-deploy";
    runtimeInputs = [
      pkgs.coreutils
      config.nix.package
    ];
    text = ''
      site=$1
      read -r -a args <<< "''${SSH_ORIGINAL_COMMAND:-}"
      action=''${args[0]:-}
      domain=''${args[1]:-}
      env=''${args[2]:-}

      [[ "$domain" == "$site" ]] || { echo "this key can only deploy $site" >&2; exit 1; }
      case "$env" in
        prod | qa) link="${root}/$domain/$env" ;;
        pr-[0-9]*) [[ "$env" =~ ^pr-[0-9]+$ ]] || { echo "bad environment: $env" >&2; exit 1; }
          link="${root}/$domain/sandbox/$env" ;;
        *) echo "bad environment: $env" >&2; exit 1 ;;
      esac

      case "$action" in
        deploy)
          path=''${args[3]:-}
          [[ "$path" =~ ^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+$ ]] || { echo "bad store path: $path" >&2; exit 1; }
          nix-store --realise "$path" --add-root "$link" >/dev/null
          echo "$domain $env -> $path"
          ;;
        remove)
          [[ "$env" == pr-* ]] || { echo "only sandboxes can be removed" >&2; exit 1; }
          rm -f "$link"
          ;;
        current)
          readlink "$link"
          ;;
        *) echo "unknown action: $action" >&2; exit 1 ;;
      esac
    '';
  };

  siteType = lib.types.submodule {
    options = {
      deployKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "SSH keys allowed to deploy this site, and only this site.";
      };
    };
  };
in
{
  options.homelab.sites = {
    domains = lib.mkOption {
      type = lib.types.attrsOf siteType;
      default = { };
      description = ''
        Static sites served from deployed builds, keyed by domain. Each gets prod at the
        domain and its www and prod. names, qa at qa.<domain>, and a sandbox per pull
        request at pr-<n>.sandbox.<domain>.
      '';
    };
  };

  config = lib.mkIf (cfg.domains != { }) {
    users.users.sites = {
      isSystemUser = true;
      group = "sites";
      home = root;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = lib.concatLists (
        lib.mapAttrsToList (
          domain: site:
          map (key: ''command="${lib.getExe deployCommand} ${domain}",restrict ${key}'') site.deployKeys
        ) cfg.domains
      );
    };
    users.groups.sites = { };

    systemd.tmpfiles.rules = [
      "d ${root} 0755 sites sites - -"
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (domain: _: [
        "d ${root}/${domain} 0755 sites sites - -"
        "d ${root}/${domain}/sandbox 0755 sites sites - -"
      ]) cfg.domains
    );

    # A wildcard certificate for each domain's sandboxes.
    homelab.ingress.certificates = lib.mapAttrs' (
      domain: _:
      lib.nameValuePair "sandbox.${domain}" [
        "sandbox.${domain}"
        "*.sandbox.${domain}"
      ]
    ) cfg.domains;

    homelab.ingress.routes = lib.mkMerge (
      lib.mapAttrsToList (
        domain: _:
        let
          serve = dir: ''
            root * ${dir}
            file_server
          '';
          # Index of the sandbox name in Caddy's {labels.N}, counted from the right.
          sandboxLabel = toString (lib.length (lib.splitString "." domain) + 1);
        in
        {
          ${domain} = {
            serverAliases = [
              "www.${domain}"
              "prod.${domain}"
            ];
            extraConfig = serve "${root}/${domain}/prod";
          };
          "qa.${domain}".extraConfig = serve "${root}/${domain}/qa";
          "*.sandbox.${domain}".extraConfig = serve "${root}/${domain}/sandbox/{labels.${sandboxLabel}}";
        }
      ) cfg.domains
    );
  };
}
