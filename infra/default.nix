{
  inputs,
  self,
  lib,
  ...
}:
{
  perSystem =
    { system, ... }:
    {
      # OpenTofu configuration for resources outside the hosts, built as config.tf.json.
      packages.infra = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = {
          inherit (self) nixosConfigurations;
          cloudflareAccountId =
            (lib.head (lib.attrValues self.nixosConfigurations)).config.homelab.cloudflared.accountId;
        };
        # One file per Cloudflare zone, with the zone and its hand-written records.
        modules = [
          ./cloudflare.nix
        ]
        ++ map (file: ./zones + "/${file}") (builtins.attrNames (builtins.readDir ./zones));
      };
    };
}
