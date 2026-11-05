{
  homelab.mainDomain = "mpluta.dev";
  homelab.cloudflared.accountId = "0d4c80186d7a57bd42349891cb26b929";
  homelab.splitDns.resolverHost = "mikeway";

  homelab.networks = {
    mikeway = {
      lan = {
        v4 = "192.168.100.1";
        subnet = "192.168.100.0/24";
        interface = "br-lan";
      };
      mesh.v4 = "100.67.111.121";
    };
    mikelab = {
      lan = {
        v4 = "192.168.100.10";
        mac = "18:c0:4d:82:21:a4";
        subnet = "192.168.100.0/24";
        interface = "lan0";
      };
      mesh.v4 = "100.120.225.75";
    };
  };
}
