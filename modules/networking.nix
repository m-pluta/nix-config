{ config, ... }:
{
  age.secrets.wifi.file = ../secrets/wifi.age;

  networking.firewall.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # NM and wpa_supplicant are mutually exclusive
  networking.networkmanager.enable = false;
  networking.wireless = {
    enable = true;
    secretsFile = config.age.secrets.wifi.path;
    networks."ItHurtsWhenIP" = {
      pskRaw = "ext:PSK_HOME";
    };
  };
  # Better stability over WiFi
  programs.mosh.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      # AllowUsers = [ "michal" ];
      ClientAliveInterval = 60;
      ClientAliveCountMax = 5;
    };
  };
}
