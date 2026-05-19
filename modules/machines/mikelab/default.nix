{
  self,
  ...
}:
{
  flake.nixosConfigurations.mikelab = self.inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit (self) inputs;
    };
    modules = [
      ../../homelab
      ../../misc/email
      self.inputs.agenix.nixosModules.default
      self.inputs.disko.nixosModules.disko
      self.inputs.disko-zfs.nixosModules.default
      ./configuration.nix
      ./hardware-configuration.nix
      ./disko.nix
      ./users.nix
      ./networking.nix
      ./homelab.nix
    ];
  };
}
