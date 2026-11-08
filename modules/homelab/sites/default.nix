{
  lib,
  config,
  pkgs,
  keys,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.sites;
  sitesDir = "/var/lib/sites";

  # Run as the forced command for a site's deploy key, with the site's domain as its
  # argument: `sandbox deploy <n> <store path>`, `sandbox remove <n>`,
  # `qa deploy <store path>` or `prod release`, which points prod at qa's build.
  # Each environment is a Nix profile, so its earlier builds stay available as generations.
  deployCommand = pkgs.writeShellApplication {
    name = "sites-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      config.nix.package
    ];
    runtimeEnv = {
      SITES_DIR = sitesDir;
    };
    text = builtins.readFile ./sites-deploy.sh;
  };

in
{
  options.homelab.sites = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { });
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
      home = "/home/sites";
      createHome = true;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = lib.mapAttrsToList (
        domain: _:
        ''command="${lib.getExe deployCommand} ${domain}",restrict ${keys.deploy.sites.${domain}}''
      ) cfg;
    };
    users.groups.sites = { };

    systemd.tmpfiles.rules = [
      "d ${sitesDir} 0755 sites sites - -"
    ]
    ++ lib.concatLists (
      lib.mapAttrsToList (domain: _: [
        "d ${sitesDir}/${domain} 0755 sites sites - -"
        "d ${sitesDir}/${domain}/sandbox 0755 sites sites - -"
      ]) cfg
    );

    # A certificate for each site's domain, its subdomains and its sandboxes.
    homelab.ingress.certificates = lib.mapAttrs (domain: _: [
      domain
      "*.${domain}"
      "*.sandbox.${domain}"
    ]) cfg;

    homelab.ingress.routes = lib.mkMerge (
      lib.mapAttrsToList (
        domain: _:
        let
          # Store files all share one modification time, so drop the validators built from it.
          serve = dir: ''
            root * ${dir}
            header -ETag
            header -Last-Modified
            header Cache-Control no-cache
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
            extraConfig = serve "${sitesDir}/${domain}/prod";
          };
          "qa.${domain}".extraConfig = serve "${sitesDir}/${domain}/qa";
          "*.sandbox.${domain}".extraConfig = ''
            @sandbox vars_regexp {labels.${sandboxLabel}} ^pr-[0-9]+$
            handle @sandbox {
              ${serve "${sitesDir}/${domain}/sandbox/{labels.${sandboxLabel}}"}
            }
            handle {
              respond 404
            }
          '';
        }
      ) cfg
    );
  };
}
