{ config, ... }:

{
  age.secrets.wifi.file = ../secrets/wifi.age;

  networking.networkmanager.enable = false;
  networking.firewall.enable = true;

  networking.wireless = {
    enable = true;
    secretsFile = config.age.secrets.wifi.path;
    networks."ItHurtsWhenIP" = {
      pskRaw = "ext:PSK_HOME";
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
    };
  };
}
