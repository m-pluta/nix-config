{
  config,
  lib,
  pkgs,
  ...
}:
let
  service = "motd";
  hl = config.homelab;
  cfg = hl.${service};

  # Collect enabled homelab services and their monitored systemd units
  enabledServices = lib.filterAttrs (
    name: value: name != "enable" && lib.isAttrs value && value.enable or false
  ) hl.services;

  monitoredServices = lib.concatMap (svc: svc.monitoredServices) (lib.attrValues enabledServices);

  motd = pkgs.writeShellScriptBin "motd" ''
    #! /usr/bin/env bash

    # Colors
    RED="\e[31m"
    GREEN="\e[32m"
    YELLOW="\e[33m"
    GREY="\e[90m"
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
    ) cfg.networkInterfaces}

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
    upWeeks=$((uptime/60/60/24/7))
    upDays=$((uptime/60/60/24%7))
    upHours=$((uptime/60/60%24))
    upMins=$((uptime/60%60))
    upSecs=$((uptime%60))
    # Starts at the largest unit that is not 0
    upText=""
    for part in "$upWeeks"w "$upDays"d "$upHours"h "$upMins"m "$upSecs"s; do
      if [ -n "$upText" ] || [ "''${part%?}" -gt 0 ]; then
        upText="$upText $part"
      fi
    done
    upText="''${upText# }"
    upText="''${upText:-0s}"
    print_info "CPU usage" "$LOAD1, $LOAD5, $LOAD15 (1, 5, 15 min)"
    print_info "Memory" "$MEMORY"
    print_info "System uptime" "$upText"

    # GPU status
    # Walks PCI display devices rather than DRM cards, so a GPU whose driver failed to probe still shows up
    GPUS=()
    for dev in /sys/bus/pci/devices/*; do
      [[ $(cat "$dev/class") == 0x03* ]] && GPUS+=("$dev")
    done
    if [ ''${#GPUS[@]} -gt 0 ]; then
      printf "\n"
      printf "$BOLD GPU status$ENDCOLOR\n"
    fi
    for dev in "''${GPUS[@]}"; do
      addr=$(basename "$dev")
      name=$(${pkgs.pciutils}/bin/lspci -vmm -s "$addr" | sed -n 's/^Device:\t//p')
      # Prefer the marketing name in brackets, e.g. "GP104 [GeForce GTX 1070]"
      [[ $name =~ \[(.*)\] ]] && name=''${BASH_REMATCH[1]}
      driver=""
      [ -e "$dev/driver" ] && driver=$(basename "$(readlink "$dev/driver")")
      stats=""
      case "$driver" in
        ${lib.optionalString config.hardware.nvidia.enabled ''
          nvidia)
            IFS=', ' read -r temp util memUsed memTotal power < <(
              ${config.hardware.nvidia.package.bin}/bin/nvidia-smi --id="$addr" \
                --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw \
                --format=csv,noheader,nounits 2>/dev/null
            )
            [ -n "$temp" ] && stats="''${temp}°C, ''${util}%, ''${memUsed}/''${memTotal}MB, ''${power%.*}W"
            ;;
        ''}
        amdgpu)
          hwmon=$(echo "$dev"/hwmon/hwmon*)
          if [ -r "$hwmon/temp1_input" ] && [ -r "$dev/mem_info_vram_total" ]; then
            temp=$(( $(cat "$hwmon/temp1_input") / 1000 ))
            util=$(cat "$dev/gpu_busy_percent")
            memUsed=$(( $(cat "$dev/mem_info_vram_used") / 1048576 ))
            memTotal=$(( $(cat "$dev/mem_info_vram_total") / 1048576 ))
            power=$(cat "$hwmon/power1_average" 2>/dev/null || cat "$hwmon/power1_input" 2>/dev/null)
            stats="''${temp}°C, ''${util}%, ''${memUsed}/''${memTotal}MB''${power:+, $((power / 1000000))W}"
          fi
          ;;
      esac
      if [ -z "$driver" ]; then
        printf "$RED• $ENDCOLOR%s $RED[no driver]$ENDCOLOR\n" "$name"
      else
        printf "$GREEN• $ENDCOLOR%s %s$GREEN[%s]$ENDCOLOR\n" "$name" "''${stats:+($stats) }" "$driver"
      fi
    done

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
        COLOR=$GREEN STATE=active
      elif systemctl is-failed --quiet "$1"; then
        COLOR=$RED STATE=failed
      else
        COLOR=$YELLOW STATE=unknown
      fi
      # The unit name, then its type in grey and brackets, right next to the status
      NAME="''${1%.*}" TYPE="(''${1##*.})"
      printf "$COLOR• $ENDCOLOR%s%*s$GREY%s$ENDCOLOR $COLOR[%s]$ENDCOLOR\n" \
        "$NAME" $((PAD - ''${#NAME} - ''${#TYPE})) "" "$TYPE" "$STATE"
    }
    ${lib.strings.concatStrings (lib.lists.forEach monitoredServices (x: "get_service_status ${x}\n"))}
  '';
in
{
  options.homelab.${service} = {
    enable = lib.mkEnableOption "the login greeting (motd)";
    networkInterfaces = lib.mkOption {
      description = "Network interfaces to monitor";
      type = lib.types.listOf lib.types.str;
      default = [ "" ];
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = map (unit: {
      assertion = config.systemd.units ? ${unit};
      message = "homelab.motd: the unit ${unit} is listed in monitoredServices but does not exist on ${config.networking.hostName}.";
    }) monitoredServices;
    environment.systemPackages = [ motd ];
    programs.bash.interactiveShellInit = ''
      ${motd}/bin/motd
    '';
  };
}
