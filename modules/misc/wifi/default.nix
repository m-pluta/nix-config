{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.wifi;

  # SSID with a curly apostrophe (U+2019), specified by code point so no
  # editor can normalize it to a straight quote. This is the byte sequence
  # the AP actually broadcasts: "Native King\xe2\x80\x99s Wardrobe".
  wardrobe = builtins.fromJSON ''"Native King\u2019s Wardrobe"'';

  knownNetworks = {
    "ItHurtsWhenIP" = "ext:PSK_DURHAM";
    "loopback" = "ext:PSK_HOTSPOT";
    "VM8776666" = "ext:PSK_MUM";
    ${wardrobe} = "ext:PSK_JUMP";
  };

  # Dedupe so a repeated SSID can't produce two network blocks.
  uniqueSsids = lib.unique cfg.ssids;

  indexedNetworks = lib.imap0 (i: ssid: {
    name = ssid;
    value = {
      pskRaw = knownNetworks.${ssid};
      priority = 100 - i;
    };
  }) uniqueSsids;
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
