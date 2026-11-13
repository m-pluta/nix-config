{
  lib,
  pkgs,
  config,
  inputs,
  keys,
  ...
}:
let
  service = "forgejo-runner";
  hl = config.homelab;
  cfg = hl.services.${service};

  # Names each host serves, from split DNS.
  namesOf = host: lib.attrNames (lib.filterAttrs (_: h: h == host) hl.splitDns.records);
  addressOf = host: hl.networks.${host}.lan.v4;

  # One homelab.conf entry: every name a host serves, at its LAN address.
  sshConfigEntry =
    host: "Host " + toString ([ host ] ++ namesOf host) + "\n  HostName " + addressOf host + "\n";

  # One known_hosts line: every name and address a host's key is known by.
  knownHostsLine =
    host: key:
    lib.concatStringsSep "," (
      [
        host
        (addressOf host)
      ]
      ++ namesOf host
    )
    + " "
    + key
    + "\n";

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
      "${sshConfigDir}/homelab.conf".text = lib.concatMapStrings sshConfigEntry (
        lib.attrNames keys.hosts
      );
      "${sshConfigDir}/known_hosts".text = lib.concatStrings (
        lib.mapAttrsToList knownHostsLine keys.hosts
      );
    };

    # Job containers' conmon scopes, which otherwise hold up shutdown for the default 90s.
    systemd.units."libpod-conmon-.scope" = {
      overrideStrategy = "asDropin";
      text = ''
        [Scope]
        TimeoutStopSec=10s
      '';
    };

    virtualisation.podman.enable = true;
    # Job containers deploy to this host over its own LAN address. Each job gets its own
    # Podman network, so the rule covers every Podman bridge.
    networking.firewall.interfaces."podman+".allowedTCPPorts = [ 22 ];
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
          runner.capacity = 12;
          runner.envs = {
            ATTIC_URL = "https://${hl.services.attic.url}";
            ATTIC_CACHE = hl.services.attic.cache;
            FORGEJO_HOST = hl.services.forgejo.url;
          };
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
