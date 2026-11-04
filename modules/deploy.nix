{
  inputs,
  self,
  lib,
  withSystem,
  ...
}:
let
  # deploy-rs's lib on top of the nixpkgs build of deploy-rs, which is in the binary cache.
  deployLib =
    system:
    withSystem system (
      { pkgs, ... }:
      (pkgs.appendOverlays [
        inputs.deploy-rs.overlays.default
        (_: prev: {
          deploy-rs = {
            inherit (pkgs) deploy-rs;
            inherit (prev.deploy-rs) lib;
          };
        })
      ]).deploy-rs.lib
    );
in
{
  flake.deploy.nodes = lib.mapAttrs (name: nixos: {
    hostname = name;
    profiles.system = {
      user = "root";
      path = (deployLib nixos.pkgs.stdenv.hostPlatform.system).activate.nixos nixos;
    };
  }) self.nixosConfigurations;
}
