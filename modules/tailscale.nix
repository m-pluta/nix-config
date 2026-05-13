{ ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "client";
    # "both" lets this box advertise as subnet router or exit node later
    # subnet router = expose your home LAN (router, printer, etc) to tailnet
    # useRoutingFeatures = "both";
  };

  # tailscale routing is asymmetric, strict rpfilter drops legit traffic
  networking.firewall.checkReversePath = "loose";

  # treat tailnet as trusted LAN, ACLs control access instead of port lists
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
