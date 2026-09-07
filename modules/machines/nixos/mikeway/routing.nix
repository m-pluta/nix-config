{
  lib,
  config,
  ...
}:
let
  # Chassis label -> permanent MAC.
  ports = {
    eth0 = "00:f0:4d:02:2d:34";
    eth1 = "00:f0:4d:02:2d:35";
    eth2 = "00:f0:4d:02:2d:36";
    eth3 = "00:f0:4d:02:2d:37";
  };
  wanIf = "eth0";
  lanPorts = lib.attrNames (removeAttrs ports [ wanIf ]);
  lanBridge = "br-lan";
  lanGateway = config.homelab.net.lan;
  mikelabLan = config.homelab.networks.mikelab.lan;

  tvWiredMac = "68:07:0a:75:61:a7";
  # deadnix: skip
  tvWifiMac = "84:3e:1d:62:53:0b";
  cloneWanMac = tvWiredMac; # set to tvWiredMac (or tvWifiMac) to clone onto the WAN port
in
{
  networking.useDHCP = false;
  systemd.network = {
    enable = true;

    netdevs."10-${lanBridge}".netdevConfig = {
      Name = lanBridge;
      Kind = "bridge";
    };

    # Pin + rename each onboard port to its label (also clears them from "en*").
    links =
      let
        routing = lib.mapAttrs' (
          label: mac:
          lib.nameValuePair "10-${label}" {
            matchConfig.PermanentMACAddress = mac;
            linkConfig.Name = label;
          }
        ) ports;

        wanKey = "10-${wanIf}";
        clone = lib.optionalAttrs (cloneWanMac != null) {
          ${wanKey} = lib.recursiveUpdate routing.${wanKey} {
            linkConfig.MACAddress = cloneWanMac;
          };
        };
      in
      routing // clone;

    networks = {
      # WAN port pulls an address over DHCP. ClientIdentifier=mac keys the
      # request on the (cloned) MAC, not networkd's DUID, so the upstream
      # leases us the registered device's address.
      "20-wan" = {
        matchConfig.Name = wanIf;
        networkConfig.DHCP = "yes";
        dhcpV4Config.ClientIdentifier = "mac";
      };

      # Attach the LAN ports to the bridge.
      "20-lan-ports" = {
        matchConfig.Name = lib.concatStringsSep " " lanPorts;
        networkConfig.Bridge = lanBridge;
      };

      # Bridge carries the gateway address + DHCP server (auto-sized /24 pool).
      # DNS = the router itself, so clients use its split-horizon resolver.
      "30-${lanBridge}" = {
        matchConfig.Name = lanBridge;
        address = [ "${lanGateway}/24" ];
        networkConfig.DHCPServer = true;
        dhcpServerConfig.DNS = [ lanGateway ];
        dhcpServerStaticLeases = [
          {
            # mikelab (enp6s0)
            MACAddress = "18:c0:4d:82:21:a4";
            Address = mikelabLan;
          }
        ];
      };

      # Backup uplink: USB tethering.
      "40-wan-tether" = {
        matchConfig.Name = "en*";
        networkConfig.DHCP = "yes";
        dhcpV4Config.RouteMetric = 2048;
      };
    };
  };

  # NAT LAN clients out the WAN port.
  networking.nat = {
    enable = true;
    internalInterfaces = [ lanBridge ];
    externalInterface = wanIf;
  };

  networking.firewall.interfaces.${lanBridge}.allowedUDPPorts = [ 67 ];

  # Force LAN clients' plain DNS (even a hardcoded 8.8.8.8) through the local
  # resolver, so split-horizon applies to devices that ignore the DHCP-supplied
  # DNS server (Chromecasts, some TVs). DoH on 443 can't be caught this way.
  networking.firewall = {
    # Delete-then-add so reloads (every nixos-rebuild switch) stay idempotent
    # instead of stacking duplicate rules.
    extraCommands = ''
      for proto in udp tcp; do
        iptables -t nat -D PREROUTING -i ${lanBridge} -p $proto --dport 53 ! -d ${lanGateway} -j DNAT --to-destination ${lanGateway}:53 2>/dev/null || true
        iptables -t nat -A PREROUTING -i ${lanBridge} -p $proto --dport 53 ! -d ${lanGateway} -j DNAT --to-destination ${lanGateway}:53
      done
    '';
    extraStopCommands = ''
      for proto in udp tcp; do
        iptables -t nat -D PREROUTING -i ${lanBridge} -p $proto --dport 53 ! -d ${lanGateway} -j DNAT --to-destination ${lanGateway}:53 2>/dev/null || true
      done
    '';
  };
}
