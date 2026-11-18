{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  service = "changedetection";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  # Unstable packages with the nixpkgs config of the host
  unstablePkgs = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (config.nixpkgs) config;
  };
in
{
  options.homelab.services.${service} =
    serviceLib.mkServiceOptions {
      port = 8072;
      url = "changes.${hl.mainDomain}";
      configDir = "/var/lib/changedetection-io";
      monitoredServices = [
        "changedetection-io.service"
        "podman-changedetection-browser.service"
      ];
      homepage = {
        name = "changedetection.io";
        description = "Website change alerts";
        icon = "changedetection.png";
        category = "Services";
      };
    }
    // {
      puppetBrowserPort = lib.mkOption {
        type = lib.types.port;
        default = 8073;
        description = "Port on 127.0.0.1 for the Chrome container that fetches pages.";
      };
    };
  config = lib.mkIf cfg.enable {
    services.changedetection-io = {
      enable = true;
      # nixpkgs-unstable until NixOS 26.11
      package = unstablePkgs.changedetection-io;
      listenAddress = "127.0.0.1";
      port = cfg.port;
      baseURL = "https://${cfg.url}";
      behindProxy = true;
    };
    systemd.services.changedetection-io = {
      environment.PLAYWRIGHT_DRIVER_URL = "ws://127.0.0.1:${toString cfg.puppetBrowserPort}";
      wants = [ "podman-changedetection-browser.service" ];
      after = [ "podman-changedetection-browser.service" ];
    };

    virtualisation.oci-containers.containers.changedetection-browser = {
      image = "docker.io/dgtlmoon/sockpuppetbrowser:0.0.5";
      ports = [ "127.0.0.1:${toString cfg.puppetBrowserPort}:3000" ];
      environment = {
        SCREEN_WIDTH = "1920";
        SCREEN_HEIGHT = "1024";
        SCREEN_DEPTH = "16";
        MAX_CONCURRENT_CHROME_PROCESSES = "10";
      };
    };

    homelab.ingress.routes."${cfg.url}" = {
      port = cfg.port;
      shortcut = cfg.shortcut;
    };
  };
}
