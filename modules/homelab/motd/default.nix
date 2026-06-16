{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Collect enabled homelab services and their monitored systemd units
  enabledServices = lib.filterAttrs (
    _name: value: value != "enable" && value ? enable && value.enable
  ) config.homelab.services;

  monitoredServices = lib.concatMap (
    name:
    let
      svc = enabledServices.${name};
    in
    if svc ? monitoredServices then svc.monitoredServices else [ name ]
  ) (lib.attrNames enabledServices);

  motd = pkgs.writeShellScriptBin "motd" ''
    #! /usr/bin/env bash

    # Colors
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    BOLD="\e[1m"
    ENDCOLOR="\e[0m"

    # Helper
    function print_info() {
      printf "$BOLD  * %-20s$ENDCOLOR %s\n" "$1" "$2"
    }

    # Welcome
    HOUR=$(date +"%H")
    if [ $HOUR -lt 12 -a $HOUR -ge 0 ]; then
      TIME="morning"
    elif [ $HOUR -lt 17 -a $HOUR -ge 12 ]; then
      TIME="afternoon"
    else
      TIME="evening"
    fi
    printf "$BOLD Good $TIME! Welcome to $(hostname)!$ENDCOLOR\n"
    printf "\n"

    # Network
    ${lib.strings.concatMapStrings (
      iface:
      let
        netdev =
          if iface == "" then ''NETDEV=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")'' else "NETDEV=${iface}";
      in
      ''
        ${netdev}
        print_info "IPv4 $NETDEV" "$(ip -4 addr show $NETDEV | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
      ''
    ) config.homelab.motd.networkInterfaces}

    # System info
    source /etc/os-release
    print_info "Release" "$PRETTY_NAME"
    print_info "Kernel" "$(uname -rs)"
    printf "\n"

    # Resource usage
    LOAD1=$(cat /proc/loadavg | awk {'print $1'})
    LOAD5=$(cat /proc/loadavg | awk {'print $2'})
    LOAD15=$(cat /proc/loadavg | awk {'print $3'})
    MEMORY=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)\n", $3,$2,$3*100 / $2 }')
    uptime=$(cat /proc/uptime | cut -f1 -d.)
    upDays=$((uptime/60/60/24))
    upHours=$((uptime/60/60%24))
    upMins=$((uptime/60%60))
    upSecs=$((uptime%60))
    print_info "CPU usage" "$LOAD1, $LOAD5, $LOAD15 (1, 5, 15 min)"
    print_info "Memory" "$MEMORY"
    print_info "System uptime" "$upDays days $upHours hours $upMins minutes $upSecs seconds"

    # Service status
    printf "\n"
    printf "$BOLD Service status$ENDCOLOR\n"
    PAD=${
      toString (
        2
        + lib.foldl' (
          acc: s:
          let
            len = builtins.stringLength s;
          in
          if len > acc then len else acc
        ) 0 monitoredServices
      )
    }
    function get_service_status() {
      if systemctl is-active --quiet "$1"; then
        printf "$GREEN• $ENDCOLOR%-''${PAD}s $GREEN[active]$ENDCOLOR\n" "$1"
      elif systemctl is-failed --quiet "$1"; then
        printf "$RED• $ENDCOLOR%-''${PAD}s $RED[failed]$ENDCOLOR\n" "$1"
      else
        printf "$YELLOW• $ENDCOLOR%-''${PAD}s $YELLOW[unknown]$ENDCOLOR\n" "$1"
      fi
    }
    ${lib.strings.concatStrings (lib.lists.forEach monitoredServices (x: "get_service_status ${x}\n"))}
  '';
in
{
  options.homelab.motd = {
    enable = lib.mkEnableOption {
      description = "motd Greeting";
    };
    networkInterfaces = lib.mkOption {
      description = "Network interfaces to monitor";
      type = lib.types.listOf lib.types.str;
      default = [ "" ];
    };
  };
  config = lib.mkIf config.homelab.motd.enable {
    environment.systemPackages = [ motd ];
    programs.bash.interactiveShellInit = ''
      ${motd}/bin/motd
    '';
  };
}
