{
  lib,
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
  lanSubnet = "192.168.100";

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
      "30-${lanBridge}" = {
        matchConfig.Name = lanBridge;
        address = [ "${lanSubnet}.1/24" ];
        networkConfig.DHCPServer = true;
        dhcpServerConfig.DNS = [
          "1.1.1.1"
          "8.8.8.8"
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
}
