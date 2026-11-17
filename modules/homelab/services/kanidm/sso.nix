# Kanidm logins for the services, from homelab.services.<name>.auth
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  hl = config.homelab;
  secretName = name: "kanidm-client-${name}";
  ldapPort = 3636;
  lanInterface = hl.networks.${config.networking.hostName}.lan.interface or null;

  icons = import ./icons.nix;
  kanidmIcon =
    name:
    if name == null || !(icons.hashes ? ${name}) then
      null
    else
      pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/${icons.rev}/${
          if lib.hasSuffix ".svg" name then "svg" else "png"
        }/${name}";
        hash = icons.hashes.${name};
      };

  oidcServices = lib.filterAttrs (_: s: s.auth.oidc.enable or false) hl.allHosts.services;
  ldapServices = lib.filterAttrs (_: s: s.auth.ldap.enable or false) hl.allHosts.services;
in
{
  options.homelab.services.kanidm.ldap = {
    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "ldaps://${hl.services.kanidm.url}:${toString ldapPort}";
      description = "Address of Kanidm's LDAP server.";
    };
    baseDn = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.concatMapStringsSep "," (part: "dc=${part}") (lib.splitString "." hl.mainDomain);
      description = "Base DN of Kanidm's LDAP server.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = lib.mapAttrsToList (name: s: {
        assertion = !s.auth.oidc.enable || s.auth.oidc.redirectPaths != [ ];
        message = "homelab.services.${name}.auth.oidc.enable is true, but auth.oidc.redirectPaths is empty.";
      }) (lib.filterAttrs (_: s: s ? auth) hl.services);
    }

    (lib.mkIf hl.services.kanidm.enable {
      # Each needs a secret in nix-secrets at services/kanidm/clients/<name>.age, readable
      # by the service's host and Kanidm's.
      age.secrets = lib.mapAttrs' (
        name: _:
        lib.nameValuePair (secretName name) {
          file = "${inputs.secrets}/services/kanidm/clients/${name}.age";
          owner = "kanidm";
        }
      ) oidcServices;

      services.kanidm.provision = {
        groups = lib.mapAttrs' (name: _: lib.nameValuePair "${name}.access" { }) (
          oidcServices // ldapServices
        );
        systems.oauth2 = lib.mapAttrs (
          name: s:
          let
            redirectUrls = map (path: "https://${s.url}${path}") s.auth.oidc.redirectPaths;
          in
          {
            displayName = s.homepage.name;
            originUrl = if lib.length redirectUrls == 1 then lib.head redirectUrls else redirectUrls;
            originLanding = "https://${s.url}/";
            imageFile = kanidmIcon s.homepage.icon;
            basicSecretFile = config.age.secrets.${secretName name}.path;
            preferShortUsername = true;
            scopeMaps."${name}.access" = s.auth.oidc.scopes;
          }
          // s.auth.oidc.extraClientSettings
        ) oidcServices;
      };
    })

    # Kanidm's LDAP server, with the same certificate as the HTTPS server
    (lib.mkIf (hl.services.kanidm.enable && ldapServices != { }) {
      services.kanidm.server.settings.ldapbindaddress = "[::]:${toString ldapPort}";
      networking.firewall.interfaces = lib.optionalAttrs (lanInterface != null) {
        ${lanInterface}.allowedTCPPorts = [ ldapPort ];
      };
    })
  ];
}
