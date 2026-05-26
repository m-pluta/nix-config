{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  homelab = config.homelab;
  cfg = homelab.wireguard-netns;
in
{
  options.homelab.wireguard-netns = {
    enable = lib.mkEnableOption {
      description = "Enable Wireguard client network namespace";
    };
    server = lib.mkOption {
      type = lib.types.str;
      description = "Mullvad WireGuard server name, maps to agenix secret path";
      default = "ch-zrh-wg-001";
    };
    namespace = lib.mkOption {
      type = lib.types.str;
      description = "Network namespace to be created";
      default = "wg_client";
    };
    privateIP = lib.mkOption {
      type = lib.types.str;
      description = "WireGuard interface address assigned by Mullvad";
      default = "10.73.154.115/32";
    };
    dnsIP = lib.mkOption {
      type = lib.types.str;
      description = "DNS server used inside the network namespace";
      default = "10.64.0.1";
    };
    monitoredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        cfg.namespace
      ];
    };
  };
  config = lib.mkIf cfg.enable {
    age.secrets.mullvad-wg.file = "${inputs.secrets}/network/mullvad/${cfg.server}.age";

    # Reusable template that creates an empty network namespace.
    # WireGuard setup happens in the service below that depends on this.
    systemd.services."netns@" = {
      description = "%I network namespace";
      before = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot"; # run script only once, not as a daemon
        RemainAfterExit = true; # stay "active" so dependents can start
        ExecStart = "${pkgs.iproute2}/bin/ip netns add %I";
        ExecStop = "${pkgs.iproute2}/bin/ip netns del %I";
      };
    };
    systemd.services.${cfg.namespace} = {
      description = "${cfg.namespace} network interface";
      bindsTo = [ "netns@${cfg.namespace}.service" ]; # stop if namespace dies
      requires = [ "network-online.target" ]; # WireGuard handshake needs internet
      after = [ "netns@${cfg.namespace}.service" ]; # namespace must exist first
      wantedBy = [ "multi-user.target" ]; # start on boot
      serviceConfig = {
        Type = "oneshot"; # run script only once, not as a daemon
        RemainAfterExit = true; # stay "active" so dependents can start
        ExecStart =
          with pkgs;
          writers.writeBash "wg-up" ''
            set -e
            ${iproute2}/bin/ip link add wg0 type wireguard # create WireGuard interface on host
            ${iproute2}/bin/ip link set wg0 netns ${cfg.namespace} # move into namespace (host can no longer see it)
            ${iproute2}/bin/ip -n ${cfg.namespace} address add ${cfg.privateIP} dev wg0 # assign Mullvad IP
            ${iproute2}/bin/ip netns exec ${cfg.namespace} \
            ${wireguard-tools}/bin/wg setconf wg0 ${config.age.secrets.mullvad-wg.path} # load private key + peer config
            ${iproute2}/bin/ip -n ${cfg.namespace} link set wg0 up # bring up WireGuard
            ${iproute2}/bin/ip -n ${cfg.namespace} link set lo up # loopback needed for socket proxy bridge
            # Set default route to WireGuard. Since this is the only route in the
            # namespace, traffic has nowhere to go if the tunnel drops -> kill switch.
            ${iproute2}/bin/ip -n ${cfg.namespace} route add default dev wg0
          '';
        ExecStop =
          with pkgs;
          writers.writeBash "wg-down" ''
            set -e
            ${iproute2}/bin/ip -n ${cfg.namespace} route del default dev wg0 # remove default route
            ${iproute2}/bin/ip -n ${cfg.namespace} link del wg0 # delete WireGuard interface
          '';
      };
    };

    # Processes in this namespace see this as /etc/resolv.conf
    environment.etc."netns/${cfg.namespace}/resolv.conf".text = "nameserver ${cfg.dnsIP}";
  };
}
