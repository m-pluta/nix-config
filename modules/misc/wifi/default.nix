{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.wifi;

  knownNetworks = {
    "ItHurtsWhenIP" = "ext:PSK_DURHAM";
    "loopback" = "ext:PSK_HOTSPOT";
    "VM8776666" = "ext:PSK_MUM";
  };

  indexedNetworks = lib.imap0 (i: ssid: {
    name = ssid;
    value = {
      pskRaw = knownNetworks.${ssid};
      priority = 100 - i;
    };
  }) cfg.ssids;
in
{
  options.wifi = {
    enable = lib.mkEnableOption "WiFi configuration";
    ssids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "SSIDs to connect to, in priority order (first = highest).";
    };

    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${inputs.secrets}/network/wifi.age";
      description = "Path to the agenix-encrypted wifi secrets file.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.wifi.file = cfg.secretsFile;

    networking.wireless = {
      enable = true;
      secretsFile = config.age.secrets.wifi.path;
      networks = builtins.listToAttrs indexedNetworks;
    };
  };
}
