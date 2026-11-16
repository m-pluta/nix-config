{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "motd";
  hl = config.homelab;
  cfg = hl.${service};

  # Collect enabled homelab services and their monitored systemd units
  enabledServices = lib.filterAttrs (
    name: value: name != "enable" && lib.isAttrs value && value.enable or false
  ) hl.services;

  monitoredServices = lib.concatMap (svc: svc.monitoredServices) (lib.attrValues enabledServices);

  motd = pkgs.writeShellApplication {
    name = "motd";
    # No errexit, so the other lines still show when one check fails
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      gnused
      hostname
      iproute2
      pciutils
      procps
      systemd
    ];
    runtimeEnv = {
      # "" in networkInterfaces means the interface of the default route
      NETWORK_INTERFACES = lib.concatStringsSep " " (lib.remove "" cfg.networkInterfaces);
      UNITS = lib.concatStringsSep " " monitoredServices;
      NVIDIA_SMI = lib.optionalString config.hardware.nvidia.enabled "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
    };
    text = builtins.readFile ./motd.sh;
  };
in
{
  options.homelab.${service} = {
    enable = lib.mkEnableOption "the login greeting (motd)";
    networkInterfaces = lib.mkOption {
      description = "Network interfaces to monitor";
      type = lib.types.listOf lib.types.str;
      default = [ "" ];
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = map (unit: {
      assertion = config.systemd.units ? ${unit};
      message = "homelab.motd: the unit ${unit} is listed in monitoredServices but does not exist on ${config.networking.hostName}.";
    }) monitoredServices;
    environment.systemPackages = [ motd ];
    programs.bash.interactiveShellInit = ''
      ${motd}/bin/motd
    '';
  };
}
