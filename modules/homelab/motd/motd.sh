# shellcheck shell=bash
# The login greeting. Nix sets:
#   NETWORK_INTERFACES  interfaces to show, separated by spaces. Empty: the default route's.
#   UNITS               systemd units to show, separated by spaces.
#   NVIDIA_SMI          path of nvidia-smi, or empty.

RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
GREY=$'\e[90m'
BOLD=$'\e[1m'
ENDCOLOR=$'\e[0m'

print_info() {
  printf '%s  * %-20s%s %s\n' "$BOLD" "$1" "$ENDCOLOR" "$2"
}

# Welcome
hour=$(date +%-H)
if ((hour < 12)); then
  time_of_day=morning
elif ((hour < 17)); then
  time_of_day=afternoon
else
  time_of_day=evening
fi
printf '%s Good %s! Welcome to %s!%s\n\n' "$BOLD" "$time_of_day" "$(hostname)" "$ENDCOLOR"

# Network
interfaces=$NETWORK_INTERFACES
if [ -z "$interfaces" ]; then
  interfaces=$(ip -o route get 8.8.8.8 | cut -f 5 -d " ")
fi
for netdev in $interfaces; do
  print_info "IPv4 $netdev" "$(ip -4 addr show "$netdev" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')"
done

# System info
# shellcheck source=/dev/null
source /etc/os-release
print_info "Release" "$PRETTY_NAME"
print_info "Kernel" "$(uname -rs)"
printf '\n'

# Resource usage
read -r load1 load5 load15 _ < /proc/loadavg
memory=$(free -m | awk 'NR==2{printf "%s/%sMB (%.2f%%)\n", $3,$2,$3*100 / $2 }')
uptime=$(cut -f1 -d. /proc/uptime)
# Starts at the largest unit that is not 0
up_text=""
for part in $((uptime / 604800))w $((uptime / 86400 % 7))d $((uptime / 3600 % 24))h \
  $((uptime / 60 % 60))m $((uptime % 60))s; do
  if [ -n "$up_text" ] || [ "${part%?}" -gt 0 ]; then
    up_text="$up_text $part"
  fi
done
up_text=${up_text# }
print_info "CPU usage" "$load1, $load5, $load15 (1, 5, 15 min)"
print_info "Memory" "$memory"
print_info "System uptime" "${up_text:-0s}"

# GPU status
# Walks PCI display devices rather than DRM cards, so a GPU whose driver failed to probe still shows up
gpus=()
for dev in /sys/bus/pci/devices/*; do
  [[ $(cat "$dev/class") == 0x03* ]] && gpus+=("$dev")
done
if [ ${#gpus[@]} -gt 0 ]; then
  printf '\n%s GPU status%s\n' "$BOLD" "$ENDCOLOR"
fi
for dev in "${gpus[@]}"; do
  addr=$(basename "$dev")
  name=$(lspci -vmm -s "$addr" | sed -n 's/^Device:\t//p')
  # Prefer the marketing name in brackets, e.g. "GP104 [GeForce GTX 1070]"
  [[ $name =~ \[(.*)\] ]] && name=${BASH_REMATCH[1]}
  driver=""
  [ -e "$dev/driver" ] && driver=$(basename "$(readlink "$dev/driver")")
  stats=""
  case "$driver" in
    nvidia)
      if [ -n "$NVIDIA_SMI" ]; then
        IFS=', ' read -r temp util mem_used mem_total power < <(
          "$NVIDIA_SMI" --id="$addr" \
            --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw \
            --format=csv,noheader,nounits 2>/dev/null
        )
        [ -n "$temp" ] && stats="${temp}°C, ${util}%, ${mem_used}/${mem_total}MB, ${power%.*}W"
      fi
      ;;
    amdgpu)
      hwmons=("$dev"/hwmon/hwmon*)
      hwmon=${hwmons[0]}
      if [ -r "$hwmon/temp1_input" ] && [ -r "$dev/mem_info_vram_total" ]; then
        temp=$(($(cat "$hwmon/temp1_input") / 1000))
        util=$(cat "$dev/gpu_busy_percent")
        mem_used=$(($(cat "$dev/mem_info_vram_used") / 1048576))
        mem_total=$(($(cat "$dev/mem_info_vram_total") / 1048576))
        power=$(cat "$hwmon/power1_average" 2>/dev/null || cat "$hwmon/power1_input" 2>/dev/null)
        stats="${temp}°C, ${util}%, ${mem_used}/${mem_total}MB${power:+, $((power / 1000000))W}"
      fi
      ;;
  esac
  if [ -z "$driver" ]; then
    printf '%s• %s%s %s[no driver]%s\n' "$RED" "$ENDCOLOR" "$name" "$RED" "$ENDCOLOR"
  else
    printf '%s• %s%s %s%s[%s]%s\n' "$GREEN" "$ENDCOLOR" "$name" "${stats:+($stats) }" "$GREEN" "$driver" "$ENDCOLOR"
  fi
done

# Service status
printf '\n%s Service status%s\n' "$BOLD" "$ENDCOLOR"
# Two more than the longest unit name
pad=0
for unit in $UNITS; do
  ((${#unit} > pad)) && pad=${#unit}
done
pad=$((pad + 2))
for unit in $UNITS; do
  if systemctl is-active --quiet "$unit"; then
    color=$GREEN state=active
  elif systemctl is-failed --quiet "$unit"; then
    color=$RED state=failed
  else
    color=$YELLOW state=unknown
  fi
  # The unit name, then its type in grey and brackets, right next to the status
  name=${unit%.*} type="(${unit##*.})"
  printf '%s• %s%s%*s%s%s%s %s[%s]%s\n' "$color" "$ENDCOLOR" "$name" \
    $((pad - ${#name} - ${#type})) "" "$GREY" "$type" "$ENDCOLOR" "$color" "$state" "$ENDCOLOR"
done
