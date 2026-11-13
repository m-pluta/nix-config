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
    self.inputs.agenix.nixosModules.default
    self.inputs.disko.nixosModules.disko
    self.inputs.disko-zfs.nixosModules.default
    self.inputs.autoaspm.nixosModules.default
    (./. + "/_common/default.nix")
    ../../users/root
    ../../users/mikey
    ../../users/deploy
  ];

  # Every hostname a host serves, from its routes, so split DNS can point each name at
  # the host that serves it. Hosts read each other's routes, which never depend on DNS.
  splitDnsRecords = {
    homelab.splitDns.records = lib.mkMerge (
      lib.concatMap (
        host:
        lib.mapAttrsToList (
          url: r:
          lib.genAttrs ([ url ] ++ r.serverAliases ++ lib.optional (r.shortcut != null) r.shortcut) (_: host)
        ) self.nixosConfigurations.${host}.config.homelab.ingress.routes
      ) hostNames
    );
  };

  # Every host's Kanidm login clients, so the host running Kanidm can create them all.
  ssoClients = {
    homelab.sso.allClients = lib.mkMerge (
      map (host: self.nixosConfigurations.${host}.config.homelab.sso.clients) hostNames
    );
  };

  homeManagerCfg = {
    home-manager.useGlobalPkgs = false;
    home-manager.useUserPackages = false;
    home-manager.backupFileExtension = "bak";
    home-manager.extraSpecialArgs = {
      inherit (self) inputs;
    };
  };
in
{
  flake.nixosConfigurations = lib.genAttrs hostNames (
    name:
    let
      meta = hostMeta name;
    in
    self.inputs."nixpkgs${meta.channel}".lib.nixosSystem {
      system = meta.system;
      specialArgs = {
        inherit (self) inputs;
        keys = import "${self.inputs.secrets}/keys.nix";
        self = {
          nixosModules = self.nixosModules;
        };
      };
      modules = commonModules ++ [
        self.inputs."home-manager${meta.channel}".nixosModules.home-manager
        (./. + "/${name}/configuration.nix")
        homeManagerCfg
        splitDnsRecords
        ssoClients
      ];
    }
  );
}
