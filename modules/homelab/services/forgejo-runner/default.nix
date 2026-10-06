{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  service = "forgejo-runner";
  hl = config.homelab;
  cfg = hl.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    runnerName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gitea-runner-default"
      ];
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets.forgejo-runner-registration-token.file = "${inputs.secrets}/services/forgejo/runner-registration-token.age";

    virtualisation.podman.enable = true;
    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.default = {
        enable = true;
        url = "https://${hl.services.forgejo.url}";
        name = cfg.runnerName;
        tokenFile = config.age.secrets.forgejo-runner-registration-token.path;
        hostPackages = with pkgs; [
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          nix
          wget
        ];
        settings = {
          runner.capacity = 4;
          # Keep the Nix store across jobs. A named volume is seeded from the
          # image on first use, so image updates need `podman volume rm nix-store`.
          container.options = "--device /dev/fuse -v nix-store:/nix";
        };
        labels = [
          "alpine:docker://alpine:latest"
          "buildah:docker://quay.io/containers/buildah:latest"
          "debian-latest:docker://debian:bookworm"
          "nix:docker://git.mpluta.dev/mikey/nix-ci-builder:latest"
          "native:host"
        ];
      };
    };
  };
}
