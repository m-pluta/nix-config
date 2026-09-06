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

  hostMeta =
    name:
    hostDefaults
    // (
      if builtins.pathExists (./. + "/${name}/meta.nix") then import (./. + "/${name}/meta.nix") else { }
    );

  commonModules = [
    ../../homelab
    ../../misc/wifi
    ../../misc/mpluta.dev
    self.inputs.agenix.nixosModules.default
    self.inputs.disko.nixosModules.disko
    self.inputs.disko-zfs.nixosModules.default
    self.inputs.autoaspm.nixosModules.default
    (./. + "/_common/default.nix")
    ../../users/root
    ../../users/mikey
  ];

  homeManagerCfg = {
    home-manager.useGlobalPkgs = false;
    home-manager.useUserPackages = false;
    home-manager.backupFileExtension = "bak";
    home-manager.extraSpecialArgs = {
      inherit (self) inputs;
    };
  };
  mkSystem =
    name: extraModules:
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
      modules =
        commonModules
        ++ [
          self.inputs."home-manager${meta.channel}".nixosModules.home-manager
          (./. + "/${name}/configuration.nix")
          homeManagerCfg
        ]
        ++ extraModules;
    };

  # First pass, without route injection, purely to read each host's published
  # ingress routes and LAN address. The front door reads other hosts; no host
  # reads the front door, so there is no evaluation cycle.
  base = lib.genAttrs hostNames (name: mkSystem name [ ]);

  frontDoor = base.${builtins.head hostNames}.config.homelab.ingress.frontDoor;

  remoteRoutesFor =
    fd:
    lib.foldl' (
      acc: name:
      if name == fd then
        acc
      else
        acc
        // lib.mapAttrs (_url: r: {
          lanIP = base.${name}.config.homelab.net.lan;
          inherit (r) port extraConfig serverAliases;
        }) base.${name}.config.homelab.ingress.routes
    ) { } hostNames;
in
{
  flake.nixosConfigurations = lib.genAttrs hostNames (
    name:
    mkSystem name (
      lib.optional (name == frontDoor) {
        homelab.ingress.remoteRoutes = remoteRoutesFor frontDoor;
      }
    )
  );
}
