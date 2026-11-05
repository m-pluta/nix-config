{ inputs, self, ... }:
{
  perSystem =
    { system, ... }:
    {
      # OpenTofu configuration for resources outside the hosts, built as config.tf.json.
      packages.infra = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        extraArgs = {
          inherit (self) nixosConfigurations;
          cloudflareAccountId = "0d4c80186d7a57bd42349891cb26b929";
        };
        # One file per Cloudflare zone, with the zone and its hand-written records.
        modules = [
          ./cloudflare.nix
        ]
        ++ map (file: ./zones + "/${file}") (builtins.attrNames (builtins.readDir ./zones));
      };
    };
}
