{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  service = "euro-office";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  secretsDir = "/var/lib/${service}/secrets";
in
{
  imports = [ inputs.nix-euro-office.nixosModules.default ];

  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8071;
    url = "office.${hl.mainDomain}";
    monitoredServices = [
      "euro-office-docservice"
      "euro-office-converter"
    ];
    homepage = {
      name = "Euro-Office";
      description = "Document editing in Nextcloud";
      icon = "onlyoffice.svg";
      category = "Services";
    };
  };

  config = lib.mkIf cfg.enable {
    services.euro-office = {
      enable = true;
      hostname = cfg.url;
      port = 8072;
      securityNonceFile = "${secretsDir}/nonce.conf";
      jwtSecretFile = "${secretsDir}/jwt";
      # Nextcloud has a private address (LAN and tailnet only).
      allowLocalConnections = true;
    };
    services.nginx.virtualHosts.${cfg.url}.listen = [
      {
        addr = "127.0.0.1";
        port = cfg.port;
      }
    ];

    # Made at activation, before nginx loads the nonce file.
    system.activationScripts."${service}-secrets" = {
      deps = [ "users" ];
      text = ''
        install -d -m 0750 -o root -g ${service} ${secretsDir}
        if [ ! -s ${secretsDir}/jwt ]; then
          (umask 027; ${lib.getExe pkgs.openssl} rand -hex 32 > ${secretsDir}/jwt)
        fi
        if [ ! -s ${secretsDir}/nonce.conf ]; then
          (umask 027; printf 'set $secure_link_secret "%s";\n' "$(${lib.getExe pkgs.openssl} rand -hex 32)" > ${secretsDir}/nonce.conf)
        fi
        chown root:${service} ${secretsDir}/jwt ${secretsDir}/nonce.conf
      '';
    };

    # Nextcloud's Euro-Office app
    systemd.services."nextcloud-${service}" = lib.mkIf hl.services.nextcloud.enable {
      description = "Set up Nextcloud's Euro-Office app";
      after = [
        "nextcloud-setup.service"
        "euro-office-docservice.service"
      ];
      requires = [ "nextcloud-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.nextcloud.occ ];
      environment = {
        DOCUMENT_SERVER_URL = "https://${cfg.url}/";
        NEXTCLOUD_URL = "https://${hl.services.nextcloud.url}/";
      };
      serviceConfig = {
        Type = "oneshot";
        LoadCredential = [ "jwt:${secretsDir}/jwt" ];
        ExecStart = lib.getExe (
          pkgs.writeShellApplication {
            name = "nextcloud-${service}";
            text = builtins.readFile ./nextcloud-app.sh;
          }
        );
      };
    };

    homelab.ingress.routes."${cfg.url}".port = cfg.port;
  };
}
