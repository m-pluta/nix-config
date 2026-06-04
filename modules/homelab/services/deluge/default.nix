{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "deluge";
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.${service};
  ns = hl.wireguard-netns.namespace;
in
{
  options.homelab.services.${service} = serviceLib.mkServiceOptions {
    port = 8112;
    url = "deluge.${hl.baseDomain}";
    homepage = {
      name = "Deluge";
      description = "Torrent client";
      icon = "deluge.svg";
      category = "Downloads";
    };
    configDir = "/var/lib/deluge";
    monitoredServices = [
      "delugeweb"
      "deluged-proxy"
      "deluged"
    ];
  };
  config = lib.mkIf cfg.enable {
    homelab.wireguard-netns.enable = true;
    services.deluge = {
      enable = true;
      web.enable = true;
    };
    users.users.${service}.extraGroups = [ hl.mediaGroup ];

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    # Route torrent traffic through VPN namespace
    systemd = {
      services.deluged.bindsTo = [ "netns@${ns}.service" ];
      services.deluged.requires = [
        "network-online.target"
        "${ns}.service"
      ];
      # Run deluged inside the VPN namespace — can only reach internet through WireGuard
      services.deluged.serviceConfig.NetworkNamespacePath = [ "/var/run/netns/${ns}" ];
      # deluge-web (host network) talks to deluged (VPN namespace) on port 58846
      # (deluge daemon protocol). This socket + proxy bridge the two networks.
      sockets."deluged-proxy" = {
        enable = true;
        description = "Socket for Proxy to Deluge WebUI";
        listenStreams = [ "58846" ]; # deluge daemon protocol port
        wantedBy = [ "sockets.target" ];
      };
      services."deluged-proxy" = {
        enable = true;
        description = "Proxy to Deluge Daemon in Network Namespace";
        requires = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        after = [
          "deluged.service"
          "deluged-proxy.socket"
        ];
        unitConfig = {
          JoinsNamespaceOf = "deluged.service"; # enter the same VPN namespace as deluged
        };
        serviceConfig = {
          User = config.services.deluge.user;
          Group = config.services.deluge.group;
          # Forward host socket connections to deluged inside the namespace.
          # Proxy exits after 5min idle, socket reactivates it on demand.
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:58846";
          PrivateNetwork = "yes"; # isolate from host network, JoinsNamespaceOf puts it in VPN namespace
        };
      };
    };
  };
}
