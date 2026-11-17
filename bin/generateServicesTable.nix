with builtins.getFlake (toString ../.);
let
  lib = import <nixpkgs/lib>;
  hl = hostname: nixosConfigurations.${hostname}.config.homelab;
  enabledHomepageServices =
    hostname: lib.attrNames (lib.filterAttrs (_: s: s.enable && s ? homepage) (hl hostname).services);
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
        auth = (hl hostname).services.${service}.auth;
        check = enabled: if enabled then "✓" else "";
      in
      "|${iconlink serviceConfig.icon}|${serviceConfig.name}|${serviceConfig.description}|${serviceConfig.category}|${check auth.oidc.enable}|${check auth.ldap.enable}|"
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
            "|Icon|Name|Description|Category|OIDC|LDAP|"
            "|---|---|---|---|---|---|"
            (lib.strings.concatLines rows)
          ]
      )
    );
  homelabHosts = builtins.filter (hostname: (hl hostname).enable) (
    builtins.attrNames nixosConfigurations
  );
in
lib.strings.concatLines (builtins.map hostSection homelabHosts)
