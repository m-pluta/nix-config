{
  config,
  lib,
  pkgs,
  ...
}:
let
  serviceLib = import ../lib.nix { inherit lib; };
  hl = config.homelab;
  cfg = hl.services.deluge;
  ns = hl.services.wireguard-netns.namespace;
in
{
  options.homelab.services.deluge = serviceLib.mkServiceOptions {
    port = 8112;
    url = "deluge.${hl.baseDomain}";
    configDir = "/var/lib/deluge";
    monitoredServices = [
      "delugeweb"
      "deluged-proxy"
      "deluged"
    ];
    homepage = {
      name = "Deluge";
      description = "Torrent client";
      icon = "deluge.svg";
      category = "Downloads";
    };
  };
  config = lib.mkIf cfg.enable {
    services.deluge = {
      enable = true;
      user = hl.user;
      group = hl.group;
      web = {
        enable = true;
      };
    };

    services.caddy.virtualHosts."${cfg.url}" = {
      useACMEHost = hl.baseDomain;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

    systemd = lib.mkIf hl.services.wireguard-netns.enable {
      services.deluged.bindsTo = [ "netns@${ns}.service" ];
      services.deluged.requires = [
        "network-online.target"
        "${ns}.service"
      ];
      services.deluged.serviceConfig.NetworkNamespacePath = [ "/var/run/netns/${ns}" ];
      sockets."deluged-proxy" = {
        enable = true;
        description = "Socket for Proxy to Deluge WebUI";
        listenStreams = [ "58846" ];
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
          JoinsNamespaceOf = "deluged.service";
        };
        serviceConfig = {
          User = config.services.deluge.user;
          Group = config.services.deluge.group;
          ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:58846";
          PrivateNetwork = "yes";
        };
      };
    };
  };
}
