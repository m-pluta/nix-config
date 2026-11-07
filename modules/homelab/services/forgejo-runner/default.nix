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

  # Where job containers find the homelab hosts' addresses and host keys.
  sshConfigDir = "forgejo-runner/ssh";
  sshMounts = {
    "/etc/${sshConfigDir}/homelab.conf" = "/etc/ssh/ssh_config.d/homelab.conf";
    "/etc/${sshConfigDir}/known_hosts" = "/etc/ssh/ssh_known_hosts";
  };
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

    environment.etc = {
      "${sshConfigDir}/homelab.conf".text = lib.concatStrings (
        lib.mapAttrsToList (host: _: ''
          Host ${host}
            HostName ${hl.networks.${host}.lan.v4}
        '') hl.hostKeys
      );
      "${sshConfigDir}/known_hosts".text = lib.concatStrings (
        lib.mapAttrsToList (host: key: ''
          ${host},${hl.networks.${host}.lan.v4} ${key}
        '') hl.hostKeys
      );
    };

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
          runner.capacity = 8;
          # Keep the Nix store across jobs. A named volume is seeded from the
          # image on first use, so image updates need `podman volume rm nix-store`.
          # The runner drops every volume that is not listed in valid_volumes.
          container = {
            options = lib.concatStringsSep " " (
              [
                "--device /dev/fuse"
                "-v nix-store:/nix"
              ]
              ++ lib.mapAttrsToList (source: target: "-v ${source}:${target}:ro") sshMounts
            );
            valid_volumes = [ "nix-store" ] ++ lib.attrNames sshMounts;
            # Labels point at :latest, so pull every time to pick up new releases.
            force_pull = true;
          };
        };
        labels = [
          "buildah:docker://git.mpluta.dev/mikey/buildah:latest"
          "nix:docker://git.mpluta.dev/mikey/nix:latest"
          "native:host"
        ];
      };
    };
  };
}
