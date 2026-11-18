{
  config,
  lib,
  pkgs,
  ...
}:
let
  hl = config.homelab;
  cfg = hl.services.ntfy.failedUnitAlerts;
  host = config.networking.hostName;

  notify = pkgs.writeShellApplication {
    name = "ntfy-failed-unit";
    runtimeInputs = with pkgs; [
      curl
      systemd
    ];
    text = ''
      unit=$1.service
      logs=$(journalctl --unit "$unit" --lines 20 --output cat --no-pager || true)
      curl --fail --silent --show-error --retry 3 --max-time 20 \
        --header "Title: $unit failed on ${host}" \
        --header "Priority: high" \
        --header "Tags: rotating_light,${host}" \
        --data-binary "''${logs:-No logs available}" \
        ${lib.escapeShellArg "https://${hl.services.ntfy.url}/${cfg.topic}"}
    '';
  };

  dropIn = name: text: pkgs.writeTextDir "lib/systemd/system/${name}/10-ntfy-failed-unit.conf" text;
in
{
  # Runs on all hosts, also when the ntfy server is off
  options.homelab.services.ntfy.failedUnitAlerts = {
    enable = lib.mkEnableOption "ntfy messages for failed systemd services";
    topic = lib.mkOption {
      type = lib.types.str;
      default = "homelab";
      description = "ntfy topic that gets the messages.";
    };
  };
  config = lib.mkIf cfg.enable {
    systemd.services."ntfy-failed-unit@" = {
      description = "Send an ntfy message for the failed unit %i";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe notify} %i";
        DynamicUser = true;
        SupplementaryGroups = [ "systemd-journal" ];
      };
    };
    systemd.packages = [
      # All services
      (dropIn "service.d" ''
        [Unit]
        OnFailure=ntfy-failed-unit@%N.service
      '')
      # Not for the ntfy-failed-unit services
      (dropIn "ntfy-failed-unit@.service.d" ''
        [Unit]
        OnFailure=
      '')
    ];
  };
}
