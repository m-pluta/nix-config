{
  lib,
  self,
  ...
}:
let
  entries = builtins.attrNames (builtins.readDir ./.);
  hostNames = builtins.filter (dir: builtins.pathExists (./. + "/${dir}/configuration.nix")) entries;

  hostDefaults = {
    system = "x86_64-linux";
    channel = "";
  };

  hostMeta = name:
    hostDefaults // (
      if builtins.pathExists (./. + "/${name}/meta.nix")
      then import (./. + "/${name}/meta.nix")
      else { }
    );

  commonModules = [
    ../../homelab
    ../../misc/email
    ../../misc/tg-notify
    ../../misc/mover
    ../../misc/withings2intervals
    self.inputs.agenix.nixosModules.default
    self.inputs.disko.nixosModules.disko
    self.inputs.disko-zfs.nixosModules.default
    self.inputs.adios-bot.nixosModules.default
    self.inputs.autoaspm.nixosModules.default
    self.inputs.fmatrix.nixosModules.default
    self.inputs.invoiceplane.nixosModules.default
    (./. + "/_common/default.nix")
    ../../users/root
    ../../users/mikey
  ];

  homeManagerCfg = {
    home-manager.useGlobalPkgs = false;
    home-manager.extraSpecialArgs = {
      inherit (self) inputs;
    };
    home-manager.users.mikey.imports = [
      self.inputs.agenix.homeManagerModules.default
      self.inputs.nix-index-database.homeModules.nix-index
      ../../users/mikey/dots.nix
      ../../users/mikey/age.nix
    ];
    home-manager.backupFileExtension = "bak";
    home-manager.useUserPackages = false;
  };
in
{
  flake.nixosConfigurations = lib.genAttrs hostNames (name:
    let
      meta = hostMeta name;
    in
    self.inputs."nixpkgs${meta.channel}".lib.nixosSystem {
      system = meta.system;
      specialArgs = {
        inherit (self) inputs;
        self = {
          nixosModules = self.nixosModules;
        };
      };
      modules = commonModules ++ [
        self.inputs."home-manager${meta.channel}".nixosModules.home-manager
        (./. + "/${name}/configuration.nix")
        homeManagerCfg
      ];
    }
  );
}
