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
  secretNames = [
    "secret"
    "db"
    "otp"
    "jws"
    "active-record-primary-key"
    "active-record-deterministic-key"
    "active-record-salt"
    "root-password"
  ];
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
    age.secrets = lib.listToAttrs (
      map (
        name:
        lib.nameValuePair "${service}-${name}" {
          file = "${inputs.secrets}/services/${service}/${name}.age";
          owner = config.services.${service}.user;
        }
      ) secretNames
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
      initialRootPasswordFile = secret "root-password";
      secrets = {
        secretFile = secret "secret";
        dbFile = secret "db";
        otpFile = secret "otp";
        jwsFile = secret "jws";
        activeRecordPrimaryKeyFile = secret "active-record-primary-key";
        activeRecordDeterministicKeyFile = secret "active-record-deterministic-key";
        activeRecordSaltFile = secret "active-record-salt";
      };
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
