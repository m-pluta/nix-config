# SSO login clients. Each service declares its own on the host that runs it. The host that
# runs Kanidm creates them all.
{
  config,
  lib,
  inputs,
  ...
}:
let
  hl = config.homelab;
  secretName = name: "kanidm-client-${name}";

  clientType = lib.types.submodule {
    options = {
      displayName = lib.mkOption {
        type = lib.types.str;
        description = "Name shown on Kanidm's apps page and consent screen.";
      };
      originUrl = lib.mkOption {
        type = with lib.types; either str (listOf str);
        description = "Addresses Kanidm can send a login code to. Kanidm refuses any other address.";
      };
      originLanding = lib.mkOption {
        type = lib.types.str;
        description = "Page that the service's tile on Kanidm's apps page opens. Kanidm does not use it for logins.";
      };
      scopes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "openid"
          "profile"
          "email"
        ];
        description = "What the service may read about a user, such as name and email.";
      };
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Other Kanidm OAuth2 client settings.";
      };
    };
  };
in
{
  options.homelab.sso = {
    clients = lib.mkOption {
      type = lib.types.attrsOf clientType;
      default = { };
      description = ''
        Kanidm login clients for services on this host. Each needs a secret in nix-secrets
        at services/kanidm/clients/<name>.age, readable by this host and Kanidm's, and
        only members of the <name>.access group can log in.
      '';
    };
    allClients = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      internal = true;
      description = "Every host's clients, filled in from the flake.";
    };
  };

  config = lib.mkIf hl.services.kanidm.enable {
    age.secrets = lib.mapAttrs' (
      name: _:
      lib.nameValuePair (secretName name) {
        file = "${inputs.secrets}/services/kanidm/clients/${name}.age";
        owner = "kanidm";
      }
    ) hl.sso.allClients;

    services.kanidm.provision = {
      groups = lib.mapAttrs' (name: _: lib.nameValuePair "${name}.access" { }) hl.sso.allClients;
      systems.oauth2 = lib.mapAttrs (
        name: client:
        {
          inherit (client) displayName originUrl originLanding;
          basicSecretFile = config.age.secrets.${secretName name}.path;
          preferShortUsername = true;
          scopeMaps."${name}.access" = client.scopes;
        }
        // client.settings
      ) hl.sso.allClients;
    };
  };
}
