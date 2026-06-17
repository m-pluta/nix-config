{
  lib,
  pkgs,
  config,
  ...
}:
let
  service = "forgejo-runner";
  cfg = config.homelab.services.${service};
in
{
  options.homelab.services.${service} = {
    enable = lib.mkEnableOption {
      description = "Enable ${service}";
    };
    runnerName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      example = "runner-1";
    };
    forgejoUrl = lib.mkOption {
      type = lib.types.str;
      example = "git.foo.bar";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gitea-runner-default"
      ];
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''
        pkgs.writeText "token.txt" '''
          TOKEN=foobar
        '''
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    virtualisation.podman.enable = true;
    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.default = {
        enable = true;
        url = "https://${cfg.forgejoUrl}";
        name = config.networking.hostName;
        tokenFile = cfg.tokenFile;
        hostPackages = with pkgs; [
          nodejs
          buildah
          fuse-overlayfs
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          wget
        ];
        settings = {
          runner.capacity = 2;
        };
        labels = [
          "nix:docker://git.notthebe.ee/notthebee/nix-ci-builder:latest"
          "debian-latest:docker://node:current-trixie"
          "buildah:docker://quay.io/containers/buildah:latest"
        ];
      };
    };
  };
}
