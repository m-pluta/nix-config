with builtins.getFlake (toString ../.);
let
  lib = import <nixpkgs/lib>;
  hl = hostname: nixosConfigurations.${hostname}.config.homelab;
  enabledHomepageServices =
    let
      services = hostname: builtins.filter (x: x != "enable") (builtins.attrNames (hl hostname).services);
    in
    hostname:
    builtins.filter (x: x != null) (
      builtins.map (
        x:
        if ((hl hostname).services.${x}.enable && (hl hostname).services.${x} ? homepage) then x else null
      ) (services hostname)
    );
  homepageServicesData =
    hostname:
    builtins.map (
      service:
      let
        format = icon: if lib.strings.hasSuffix "svg" icon then "svg" else "png";
        iconlink =
          icon:
          "<img src='https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/${format icon}/${icon}' width=32 height=32>";
        serviceConfig = (hl hostname).services.${service}.homepage;
      in
      "|${iconlink serviceConfig.icon}|${serviceConfig.name}|${serviceConfig.description}|${serviceConfig.category}|"
    ) (enabledHomepageServices hostname);
  hostSection =
    hostname:
    let
      rows = homepageServicesData hostname;
    in
    lib.strings.concatLines (
      [
        "### ${hostname}"
        (hl hostname).description
      ]
      ++ (
        if rows == [ ] then
          [ ]
        else
          [
            "|Icon|Name|Description|Category|"
            "|---|---|---|---|"
            (lib.strings.concatLines rows)
          ]
      )
    );
  homelabHosts = builtins.filter (hostname: (hl hostname).enable) (
    builtins.attrNames nixosConfigurations
  );
in
lib.strings.concatLines (builtins.map hostSection homelabHosts)
