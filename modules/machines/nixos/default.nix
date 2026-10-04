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
  # ingress routes and LAN address. The ingress host reads other hosts; no host
  # reads the ingress host, so there is no evaluation cycle.
  base = lib.genAttrs hostNames (name: mkSystem name [ ]);

  ingressHost = base.${builtins.head hostNames}.config.homelab.ingress.ingressHost;

  # Every other host's published routes, aggregated for the ingress host to proxy to.
  remoteRoutes = lib.foldl' (
    acc: name:
    if name == ingressHost then
      acc
    else
      acc
      // lib.mapAttrs (_url: r: {
        lanIP = base.${name}.config.homelab.networks.${name}.lan.v4;
        inherit (r) port extraConfig serverAliases;
      }) base.${name}.config.homelab.ingress.routes
  ) { } hostNames;

  # URL -> hosts declaring it. Merging same-URL routes would silently collapse them
  # into one vhost, so any URL with more than one owner is rejected.
  routeOwners = lib.foldl' (
    acc: name:
    lib.foldl' (a: url: a // { ${url} = (a.${url} or [ ]) ++ [ name ]; }) acc (
      lib.attrNames base.${name}.config.homelab.ingress.routes
    )
  ) { } hostNames;
  duplicateRoutes = lib.filterAttrs (_url: owners: lib.length owners > 1) routeOwners;
in
{
  # Reuse `base` for every host except the ingress host, which alone needs a
  # second evaluation to receive remoteRoutes — avoids re-evaluating the whole
  # fleet just to inject data into the one host that changes. ingressHost may
  # be null (ingress disabled fleet-wide), in which case base is already final.
  flake.nixosConfigurations =
    if ingressHost == null then
      base
    else
      base
      // {
        ${ingressHost} = mkSystem ingressHost [
          {
            homelab.ingress.remoteRoutes = remoteRoutes;
            assertions = [
              {
                assertion = duplicateRoutes == { };
                message =
                  "homelab.ingress route URLs declared on more than one host: "
                  + lib.concatStringsSep ", " (
                    lib.mapAttrsToList (url: owners: "${url} (${lib.concatStringsSep ", " owners})") duplicateRoutes
                  );
              }
            ];
          }
        ];
      };
}
