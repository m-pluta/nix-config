{ config, lib, ... }:
{
  networking.hosts =
    let
      spencerAddress = lib.removeSuffix "/24" config.homelab.networks.external.spencer.v4.address;
    in
    {
      "${spencerAddress}" = [
        config.homelab.services.forgejo.url
        config.homelab.services.forgejo-runner.atticUrl
      ];
    };
  security.acme.certs =
    let
      domain = "goose.party";
    in
    {
      "${domain}" = {
        reloadServices = [ "caddy.service" ];
        domain = "${domain}";
        extraDomainNames = [ "*.${domain}" ];
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1:53";
        dnsPropagationCheck = true;
        group = config.services.caddy.group;
        environmentFile = config.homelab.cloudflare.dnsCredentialsFile;
      };
    };
  homelab = {
    baseDomain = "notthebe.ee";
    cloudflare.dnsCredentialsFile = config.age.secrets.cloudflareDnsApiCredentialsNotthebee.path;
    frp = {
      tokenFile = config.age.secrets.frpToken.path;
      enable = true;
    };
    services = {
      enable = true;
      keycloak.role = "server";
      nextcloud.role = "server";
      navidrome.role = "server";
      miniflux.role = "server";
      microbin.role = "server";
      forgejo-runner = {
        enable = true;
        forgejoUrl = config.homelab.services.forgejo.url;
        tokenFile = config.age.secrets.forgejoRunnerTokenSpencer.path;
        atticTokenFile = config.age.secrets.atticTokenSpencer.path;
      };
      forgejo.enable = true;
      matrix = {
        registrationSecretFile = config.age.secrets.matrixRegistrationSecret.path;
        enable = true;
      };
    };
  };
}
