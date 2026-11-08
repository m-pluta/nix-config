{
  config,
  lib,
  inputs,
  ...
}:
let
  service = "gitlab";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  # services.gitlab.secrets option → file in nix-secrets services/gitlab/
  secretFiles = {
    secretFile = "secret-key-base";
    dbFile = "db-key-base";
    otpFile = "otp-key-base";
    jwsFile = "openid-connect-signing-key";
    activeRecordPrimaryKeyFile = "active-record-encryption-primary-key";
    activeRecordDeterministicKeyFile = "active-record-encryption-deterministic-key";
    activeRecordSaltFile = "active-record-encryption-key-derivation-salt";
  };
  secret = name: config.age.secrets."${service}-${name}".path;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    url = "gitlab.${hl.mainDomain}";
    configDir = "/var/lib/gitlab";
    monitoredServices = [
      "gitlab"
      "gitaly"
      "gitlab-workhorse"
      "gitlab-sidekiq"
    ];
    homepage = {
      name = "GitLab";
      description = "DevOps platform";
      icon = "gitlab.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets = lib.genAttrs' (lib.attrValues secretFiles ++ [ "admin-password" ]) (
      name:
      lib.nameValuePair "${service}-${name}" {
        file = "${inputs.secrets}/services/${service}/${name}.age";
        owner = config.services.${service}.user;
      }
    );
    services.openssh.settings.AcceptEnv = "GIT_PROTOCOL";
    services.${service} = {
      enable = true;
      host = cfg.url;
      port = 443;
      https = true;
      statePath = cfg.configDir;
      backup = {
        startAt = "03:00";
        keepTime = 168;
      };
      databaseCreateLocally = true;
      initialRootEmail = "mikey@${hl.mainDomain}";
      initialRootPasswordFile = secret "admin-password";
      secrets = lib.mapAttrs (_: secret) secretFiles;
    };
    homelab.ingress.routes."${cfg.url}" = {
      upstream = "unix//run/gitlab/gitlab-workhorse.socket";
      extraConfig = ''
        request_body {
          max_size 10GB
        }
      '';
    };
  };
}
