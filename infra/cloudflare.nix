{
  lib,
  nixosConfigurations,
  cloudflareAccountId,
  ...
}:
let
  # Hosts running a Cloudflare tunnel, with their tunnel settings.
  tunnelHosts = lib.filterAttrs (_: cfg: cfg.enable) (
    lib.mapAttrs (_: host: host.config.homelab.cloudflared) nixosConfigurations
  );

  # Every exposed hostname, with the host whose tunnel serves it.
  exposed = lib.concatLists (
    lib.mapAttrsToList (
      host: cfg:
      lib.concatLists (
        lib.mapAttrsToList (
          domain: labels:
          map (label: {
            inherit host domain;
            name = if label == "" then domain else "${label}.${domain}";
          }) labels
        ) cfg.expose
      )
    ) tunnelHosts
  );

  # Terraform resource names can't contain dots.
  resourceName = name: lib.replaceStrings [ "." ] [ "_" ] name;

  zoneId = domain: "\${cloudflare_zone.${resourceName domain}.id}";
in
{
  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 5.28";
  };

  # The API token comes from CLOUDFLARE_API_TOKEN.
  provider.cloudflare = { };

  resource = {
    cloudflare_zero_trust_tunnel_cloudflared = lib.mapAttrs (host: _: {
      account_id = cloudflareAccountId;
      name = host;
      config_src = "local";
    }) tunnelHosts;

    cloudflare_dns_record = lib.listToAttrs (
      map (
        e:
        lib.nameValuePair (resourceName e.name) {
          zone_id = zoneId e.domain;
          inherit (e) name;
          type = "CNAME";
          content = "\${cloudflare_zero_trust_tunnel_cloudflared.${e.host}.id}.cfargotunnel.com";
          proxied = true;
          ttl = 1;
        }
      ) exposed
    );
  };
}
