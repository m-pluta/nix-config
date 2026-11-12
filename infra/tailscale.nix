{ lib, nixosConfigurations, ... }:
let
  # Every host sets the shared values, so any one of them gives the same answer.
  hl = (lib.head (lib.attrValues nixosConfigurations)).config.homelab;
  resolver = hl.networks.${hl.splitDns.resolverHost}.mesh.v4;
in
{
  terraform.required_providers.tailscale = {
    source = "tailscale/tailscale";
    version = "~> 0.28";
  };

  # The OAuth client comes from TAILSCALE_OAUTH_CLIENT_ID and TAILSCALE_OAUTH_CLIENT_SECRET.
  # The tailnet "-" means the tailnet the OAuth client belongs to.
  provider.tailscale.tailnet = "-";

  resource = {
    tailscale_dns_search_paths.this.search_paths = [ hl.mainDomain ];

    # Tailnet devices ask the resolver host for the main domain.
    tailscale_dns_split_nameservers.main = {
      domain = hl.mainDomain;
      nameservers = [ resolver ];
    };
  };
}
