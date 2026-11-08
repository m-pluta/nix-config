{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
let
  service = "cloudflared";
  hl = config.homelab;
  cfg = hl.${service};
  credentialsDir = "/run/cloudflared-credentials";
in
{
  options.homelab.${service} = {
    enable = lib.mkEnableOption "Cloudflare Tunnel ingress for homelab services";
    accountId = lib.mkOption {
      type = lib.types.str;
      description = "Cloudflare account ID the tunnels belong to";
    };
    tunnelId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cloudflare Tunnel UUID, known once OpenTofu has created the tunnel. The connector
        only runs when it is set.
      '';
    };
    expose = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      description = "Subdomain labels to expose per domain. Empty string for apex.";
      example = {
        "mpluta.dev" = [
          ""
          "www"
          "git"
        ];
      };
    };
  };

  config = lib.mkIf (cfg.enable && cfg.tunnelId != null) {
    # The tunnel secret, shared with OpenTofu, which sets it on the tunnel.
    age.secrets.cloudflared-tunnel-secret.file = "${inputs.secrets}/infra/cloudflare/tunnels/${config.networking.hostName}.age";

    # Assembles the credentials file cloudflared reads from the account ID, tunnel ID and
    # secret, readable only by root.
    systemd.services.cloudflared-credentials = {
      requiredBy = [ "cloudflared-tunnel-${cfg.tunnelId}.service" ];
      before = [ "cloudflared-tunnel-${cfg.tunnelId}.service" ];
      path = [ pkgs.jq ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = baseNameOf credentialsDir;
        RuntimeDirectoryMode = "0700";
        UMask = "0077";
      };
      script = ''
        jq -n \
          --arg account ${lib.escapeShellArg cfg.accountId} \
          --arg tunnel ${lib.escapeShellArg cfg.tunnelId} \
          --rawfile secret ${config.age.secrets.cloudflared-tunnel-secret.path} \
          '{AccountTag: $account, TunnelID: $tunnel, TunnelSecret: ($secret | rtrimstr("\n"))}' \
          > ${credentialsDir}/credentials.json
      '';
    };

    # Connect to Cloudflare's edge over HTTP/2 instead of QUIC.
    # TODO: remove once QUIC reaches Cloudflare's edge from this network.
    systemd.services."cloudflared-tunnel-${cfg.tunnelId}".environment.TUNNEL_TRANSPORT_PROTOCOL =
      "http2";

    services.cloudflared = {
      enable = true;
      tunnels.${cfg.tunnelId} = {
        credentialsFile = "${credentialsDir}/credentials.json";
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
