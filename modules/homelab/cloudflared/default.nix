{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.homelab.cloudflared;
in
{
  options.homelab.cloudflared = {
    enable = lib.mkEnableOption "Cloudflare Tunnel ingress for homelab services";
    tunnelId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare Tunnel UUID";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the tunnel credentials JSON file (agenix secret)";
    };
    expose = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Subdomain labels to expose per domain. Empty string for apex.";
      example = {
        "mpluta.dev" = [
          ""
          "www"
          "jellyfin"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.cloudflared-tunnel.file = "${inputs.secrets}/network/cloudflare/tunnel.age";

    services.cloudflared = {
      enable = true;
      tunnels.${cfg.tunnelId} = {
        credentialsFile = cfg.credentialsFile;
        ingress =
          let
            entries = lib.flatten (
              lib.mapAttrsToList (
                domain: labels:
                map (label: {
                  host = if label == "" then domain else "${label}.${domain}";
                  inherit domain;
                }) labels
              ) cfg.expose
            );
          in
          lib.listToAttrs (
            map (
              e:
              lib.nameValuePair e.host {
                service = "https://127.0.0.1:443";
                originRequest = {
                  noTLSVerify = true;
                  originServerName = e.domain;
                };
              }
            ) entries
          );
        default = "http_status:404";
      };
    };
  };
}
