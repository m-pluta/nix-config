# shellcheck shell=bash
hwmon=${HWMON_ROOT:-/sys/class/hwmon}
failsafe=255

# fan-curves <channel> -s <cpu|drive> -i <seconds> -p <"temp:pwm ...">
channel=$1
shift
while getopts "s:i:p:" opt; do
  case $opt in
    s) source=$OPTARG ;;
    i) interval=$OPTARG ;;
    p) points=$OPTARG ;;
    *) exit 2 ;;
  esac
done

# Print the hwmon directory whose name file matches $1
find_hwmon_dir() {
  local d
  for d in "$hwmon"/hwmon*; do
    if [ "$(cat "$d/name")" = "$1" ]; then
      echo "$d"
      return 0
    fi
  done
  return 1
}

cpu_temp() {
  cat "$(find_hwmon_dir k10temp)/temp1_input"
}

# Print the hottest drive temperature in millidegrees
drive_temp() {
  local d
  for d in "$hwmon"/hwmon*; do
    if [ "$(cat "$d/name")" = drivetemp ]; then
      cat "$d/temp1_input"
    fi
  done | sort -n | tail -1
}

# pwm_for_temp <millidegrees> <"temp:pwm ..."> prints the pwm for that temperature
pwm_for_temp() {
  awk -v t="$1" -v pts="$2" 'BEGIN {
    t /= 1000
    n = split(pts, a, " ")
    for (i = 1; i <= n; i++) { split(a[i], b, ":"); T[i] = b[1]; P[i] = b[2] }
    # Clamp to the first or last point outside the curve
    if (t <= T[1]) { print P[1]; exit }
    if (t >= T[n]) { print P[n]; exit }
    # Find the segment containing t and interpolate linearly inside it
    for (i = 1; i < n; i++)
      if (t <= T[i + 1]) {
        printf "%d\n", P[i] + (P[i + 1] - P[i]) * (t - T[i]) / (T[i + 1] - T[i])
        exit
      }
  }'
}

ctl=$(find_hwmon_dir it8688)

# Give the fan back to the BIOS (enable=2)
release_to_bios() {
  echo 2 > "$ctl/${channel}_enable" || true
}
trap release_to_bios EXIT
# Turn stop signals into a normal exit so the EXIT trap runs
trap 'exit 0' TERM INT

# manual mode, the script now controls this fan
echo 1 > "$ctl/${channel}_enable"

while :; do
  pwm=$failsafe
  t=$("${source}_temp" || true)
  if [ -n "$t" ]; then pwm=$(pwm_for_temp "$t" "$points"); fi
  echo "$pwm" > "$ctl/$channel"
  # Sleep in the background and wait, so a TERM signal interrupts it at once
  sleep "$interval" &
  wait $!
done
