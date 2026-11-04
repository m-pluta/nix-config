{ lib, pkgs, ... }:
let
  # pwm4 and pwm5 (including the AIO pump's) are left on the BIOS curve
  fans = [
    {
      # Drive-bay fans for drives 1-4
      channel = "pwm1";
      source = "drive";
      interval = 10;
      curve = "35:77 50:255";
    }
    {
      # Drive-bay fans for drives 5-8
      channel = "pwm2";
      source = "drive";
      interval = 10;
      curve = "35:77 50:255";
    }
    {
      # Motherboard exhaust fan
      channel = "pwm3";
      source = "cpu";
      interval = 2;
      curve = "45:64 75:255";
    }
  ];

  # Wraps fan-curves.sh as a command and shellchecks it at build time
  fanScript = pkgs.writeShellApplication {
    name = "fan-curves";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
    ];
    text = builtins.readFile ./fan-curves.sh;
  };

  fanService = f: {
    name = "fan-curves-${f.channel}";
    value = {
      description = "Fan curve for ${f.channel}";
      wantedBy = [ "multi-user.target" ];
      # The hwmon sensors must exist first, so wait for kernel modules to load
      after = [ "systemd-modules-load.service" ];
      serviceConfig = {
        ExecStart = "${lib.getExe fanScript} ${
          lib.escapeShellArgs [
            f.channel
            "-s"
            f.source
            "-i"
            (toString f.interval)
            "-p"
            f.curve
          ]
        }";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
in
{
  # Exposes SATA drive temperatures as hwmon sensors
  boot.kernelModules = [ "drivetemp" ];

  systemd.services = lib.listToAttrs (map fanService fans);
}
