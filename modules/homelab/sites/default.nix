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
  generationsKept = 10;

  # Run as the forced command for a site's deploy key, with the site's domain as its
  # argument: `deploy <domain> <env> <store path>`, `rollback <domain> <env> <store path>`,
  # `remove <domain> <env>`, `current <domain> <env>` or `list <domain>`, where env is
  # prod, qa or pr-<n>, and list prints the sandboxes.
  # Each environment is a Nix profile, so its recent builds stay available as generations.
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

      if [[ "$action" == list ]]; then
        for l in "${root}/$domain"/sandbox/pr-*; do
          name=''${l##*/}
          if [[ "$name" =~ ^pr-[0-9]+$ ]]; then echo "$name"; fi
        done
        exit 0
      fi

      case "$env" in
        prod | qa) link="${root}/$domain/$env" ;;
        pr-[0-9]*) [[ "$env" =~ ^pr-[0-9]+$ ]] || { echo "bad environment: $env" >&2; exit 1; }
          link="${root}/$domain/sandbox/$env" ;;
        *) echo "bad environment: $env" >&2; exit 1 ;;
      esac

      store_path() {
        [[ "$1" =~ ^/nix/store/[a-z0-9]{32}-[A-Za-z0-9+._?=-]+$ ]] || { echo "bad store path: $1" >&2; exit 1; }
      }

      case "$action" in
        deploy)
          path=''${args[3]:-}
          store_path "$path"
          [[ "''${path#/nix/store/*-}" == "$domain" ]] || { echo "not a build of $domain: $path" >&2; exit 1; }
          nix-store --realise "$path" >/dev/null
          # A site build is plain files, so it references nothing but itself.
          references=$(nix-store --query --references "$path")
          [[ -z "$references" || "$references" == "$path" ]] || { echo "not a build of $domain: $path has references" >&2; exit 1; }
          nix-env --profile "$link" --set "$path"
          nix-env --profile "$link" --delete-generations +${toString generationsKept}
          echo "$domain $env -> $path"
          ;;
        rollback)
          path=''${args[3]:-}
          store_path "$path"
          generation=
          for g in "$link"-*-link; do
            if [[ "$(readlink "$g")" == "$path" ]]; then
              n=''${g#"$link"-}
              n=''${n%-link}
              if [[ -z "$generation" || "$n" -gt "$generation" ]]; then generation=$n; fi
            fi
          done
          [[ -n "$generation" ]] || { echo "$path was not recently deployed to $env" >&2; exit 1; }
          nix-env --profile "$link" --switch-generation "$generation"
          echo "$domain $env -> $path"
          ;;
        remove)
          [[ "$env" == pr-* ]] || { echo "only sandboxes can be removed" >&2; exit 1; }
          rm -f "$link" "$link"-*-link
          ;;
        current)
          readlink -e "$link"
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
  options.homelab.sites = lib.mkOption {
    type = lib.types.attrsOf siteType;
    default = { };
    description = ''
      Static sites served from deployed builds, keyed by domain. Each gets prod at the
      domain and its www and prod. names, qa at qa.<domain>, and a sandbox per pull
      request at pr-<n>.sandbox.<domain>.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    users.users.sites = {
      isSystemUser = true;
      group = "sites";
      home = root;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = lib.concatLists (
        lib.mapAttrsToList (
          domain: site:
          map (key: ''command="${lib.getExe deployCommand} ${domain}",restrict ${key}'') site.deployKeys
        ) cfg
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
      ]) cfg
    );

    # A wildcard certificate for each domain's sandboxes.
    homelab.ingress.certificates = lib.mapAttrs' (
      domain: _:
      lib.nameValuePair "sandbox.${domain}" [
        "sandbox.${domain}"
        "*.sandbox.${domain}"
      ]
    ) cfg;

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
      ) cfg
    );
  };
}
