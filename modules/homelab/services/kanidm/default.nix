{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "kanidm";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  ingressCert = config.security.acme.certs.${hl.mainDomain};
  listenAddress = "127.0.0.1:${toString cfg.port}";
  idmAdminPassword = config.age.secrets."${service}-idm-admin-password".path;

  # Prints a one-time link for a person to set up their login.
  invite = pkgs.writeShellApplication {
    name = "kanidm-invite";
    runtimeInputs = [ config.services.kanidm.package ];
    runtimeEnv.IDM_ADMIN_PASSWORD_FILE = idmAdminPassword;
    text = builtins.readFile ./kanidm-invite.sh;
  };
in
{
  imports = [ ./sso.nix ];

  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8443;
    url = "id.${hl.mainDomain}";
    homepage = {
      name = "Kanidm";
      description = "Identity and login";
      icon = "kanidm.svg";
      category = "Services";
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets."${service}-idm-admin-password" = {
      file = "${inputs.secrets}/services/${service}/idm-admin-password.age";
      owner = service;
    };
    environment.systemPackages = [ invite ];
    services.kanidm = {
      package = pkgs.kanidmWithSecretProvisioning_1_12;
      server = {
        enable = true;
        settings = {
          origin = "https://${cfg.url}";
          domain = cfg.url;
          bindaddress = listenAddress;
          # Kanidm only serves HTTPS, so it reuses the ingress wildcard certificate.
          tls_chain = "/run/credentials/kanidm.service/tls_chain";
          tls_key = "/run/credentials/kanidm.service/tls_key";
          online_backup.versions = 7;
        };
      };
      # The CLI on this host, for admin tasks like passkey reset links.
      client = {
        enable = true;
        settings.uri = "https://${cfg.url}";
      };
      provision = {
        enable = true;
        # Over loopback, where the certificate's name doesn't match.
        instanceUrl = "https://${listenAddress}";
        acceptInvalidCerts = true;
        idmAdminPasswordFile = idmAdminPassword;
        persons = import ./people.nix;
      };
    };
    # systemd hands Kanidm private copies of the certificate files at each start.
    systemd.services.kanidm.serviceConfig.LoadCredential = [
      "tls_chain:${ingressCert.directory}/fullchain.pem"
      "tls_key:${ingressCert.directory}/key.pem"
    ];
    security.acme.certs.${hl.mainDomain}.reloadServices = [ "kanidm.service" ];
    homelab.ingress.routes."${cfg.url}" = {
      upstream = "https://${listenAddress}";
      upstreamCertName = cfg.url;
    };
  };
}
