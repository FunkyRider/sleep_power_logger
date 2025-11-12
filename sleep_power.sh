#!/usr/bin/env bash
# sleep_power.sh
# Usage: sleep_power.sh suspend|resume
#
# Records date/time, event (suspend/resume) and battery energy (from upower)
# and on resume calculates Wh consumed and average wattage while sleeping.
#
# State and temporary files are stored under /tmp by default so nothing is
# written to persistent home directories. Override with STATE_DIR env var.

set -euo pipefail

LOGFILE="/var/log/sleep_power.log"
STATE_DIR="${STATE_DIR:-/tmp/sleep_power}"
STATE_FILE="$STATE_DIR/last_suspend"
WIDTH=7   # width to align event column (length of "suspend" is 7)

usage() {
  cat <<EOF
Usage: $0 suspend|resume
Records date/time, event and battery energy (from upower) to: $LOGFILE
On resume calculates Wh consumed and average wattage during sleep.
State/temporary files are stored in: $STATE_DIR (default /tmp/sleep_power)
No locking is used; atomic writes are performed for the state file.
EOF
}

if [ $# -ne 1 ]; then
  usage
  exit 2
fi

arg="$1"
case "${arg,,}" in
  suspend|resume)
    event="${arg,,}"
    ;;
  *)
    echo "Error: unknown argument '$1'"
    usage
    exit 2
    ;;
esac

NOW_TS="$(date '+%Y-%m-%d %H:%M:%S')"

# get the line containing "energy:" from upower -d
get_energy_line() {
  upower -d 2>/dev/null | grep -m1 'energy:' || true
}

# parse energy number using awk (unit assumed Wh)
# returns "<value>" or empty if no numeric energy found
extract_energy_value_unit() {
  local line="$1"
  if [ -z "$line" ]; then
    printf "%s\n" ""
    return
  fi
  echo "$line" | awk '
    {
      if (match($0, /energy:[[:space:]]*([0-9]+(\.[0-9]+)?)/, a)) {
        print a[1]
      }
    }
  '
}

mkdir -p "$STATE_DIR" 2>/dev/null || true
log_dir="$(dirname "$LOGFILE")"
mkdir -p "$log_dir" 2>/dev/null || true

# Write state file atomically in key=value format (timestamp and numeric value only)
write_state() {
  local ts="$1" energy_value="$2"
  local tmp
  tmp="$(mktemp "/tmp/$(basename "$STATE_FILE").tmp.XXXXXX")"
  {
    printf '%s\n' "SUSPEND_TIMESTAMP=$ts"
    printf '%s\n' "SUSPEND_ENERGY_VALUE=$energy_value"
  } >"$tmp"
  mv -f "$tmp" "$STATE_FILE"
}

# Read state file. Expect key=value lines only (timestamp and numeric value).
read_state() {
  if [ ! -f "$STATE_FILE" ]; then
    return 1
  fi

  SUSPEND_TIMESTAMP=""
  SUSPEND_ENERGY_VALUE=""

  while IFS='=' read -r k v; do
    case "$k" in
      SUSPEND_TIMESTAMP) SUSPEND_TIMESTAMP="$v" ;;
      SUSPEND_ENERGY_VALUE) SUSPEND_ENERGY_VALUE="$v" ;;
      *) ;; # ignore unknown keys
    esac
  done < "$STATE_FILE"

  # validate numeric energy
  if [ -n "${SUSPEND_ENERGY_VALUE:-}" ]; then
    if ! echo "$SUSPEND_ENERGY_VALUE" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
      SUSPEND_ENERGY_VALUE=""
    fi
  fi

  return 0
}

# Main event handling
energy_line="$(get_energy_line)"
read_energy="$(extract_energy_value_unit "$energy_line")"
# unit is assumed Wh
current_energy_val="${read_energy:-}"
current_energy_unit="Wh"

# Right-align numeric Wh value: width 6 with 3 decimals (e.g., " 9.100" or "29.100")
if [ -n "$current_energy_val" ]; then
  current_energy_fmt="$(awk "BEGIN{printf \"%6.3f\", $current_energy_val}")"
  current_energy_display="$(printf '%s %s' "$current_energy_fmt" "$current_energy_unit")"
else
  current_energy_display="N/A"
fi

event_padded="$(printf "%-${WIDTH}s" "$event")"

if [ "$event" = "suspend" ]; then
  # atomic write, no locking
  write_state "$NOW_TS" "$current_energy_val" || true
  printf '%s %s %s\n' "$NOW_TS" "$event_padded" "$current_energy_display" | tee -a "$LOGFILE"
  exit 0
fi

# resume
SUSPEND_TIMESTAMP=""
SUSPEND_ENERGY_VALUE=""

# attempt to read state; if missing or invalid, read_state will fail and we skip metrics
if read_state; then
  : # SUSPEND_* populated
fi

# defaults for computed displays
dt_display="N/A"
hours_fraction=""
hours_2=""
avg_w_display="N/A"
consumed_value_fmt=""
consumed_unit="Wh"

if [ -n "$SUSPEND_TIMESTAMP" ] && [ -n "$SUSPEND_ENERGY_VALUE" ] && [ -n "$current_energy_val" ]; then
  suspend_epoch="$(date -d "$SUSPEND_TIMESTAMP" +%s 2>/dev/null || true)"
  resume_epoch="$(date -d "$NOW_TS" +%s 2>/dev/null || true)"

  if [ -n "$suspend_epoch" ] && [ -n "$resume_epoch" ] && [ "$resume_epoch" -ge "$suspend_epoch" ]; then
    diff_seconds=$((resume_epoch - suspend_epoch))
    hours_only=$((diff_seconds/3600))
    mins_only=$(( (diff_seconds%3600)/60 ))
    secs_only=$(( diff_seconds%60 ))
    dt_display="$(printf "%02d:%02d:%02d" "$hours_only" "$mins_only" "$secs_only")"

    hours_fraction="$(awk "BEGIN{printf \"%.9f\", $diff_seconds/3600}")"
    hours_2="$(awk "BEGIN{printf \"%.2f\", $hours_fraction}")"

    wh_consumed="$(awk "BEGIN{printf \"%.6f\", $SUSPEND_ENERGY_VALUE - $current_energy_val}")"
    consumed_value_fmt="$(awk "BEGIN{printf \"%.3f\", $wh_consumed}")"
    consumed_unit="Wh"

    if [ -n "$hours_fraction" ]; then
      is_small="$(awk "BEGIN{ if ($hours_fraction <= 1e-9) print 1; else print 0 }")"
      if [ "$is_small" -eq 1 ]; then
        avg_w_display="N/A"
      else
        avg_watts="$(awk "BEGIN{printf \"%.3f\", ($wh_consumed)/($hours_fraction)}")"
        avg_w_display="${avg_watts} W"
      fi
    fi
  fi
fi

# Build log output.
# First line: timestamp event energy (energy numeric right-aligned)
# Second indented line: metrics with space after each colon, consumed has space between value and unit,
# and hours shown to 2 decimals. If state file missing, the second line is omitted.
if [ -n "$consumed_value_fmt" ]; then
  # primary line
  printf '%s %s %s\n' "$NOW_TS" "$event_padded" "$current_energy_display" | tee -a "$LOGFILE"
  # metrics line (indented two spaces). Note space between value and unit.
  printf '  consumed: %s %s  dt: %s (%s h)  avg: %s\n' \
    "$consumed_value_fmt" "$consumed_unit" "$dt_display" "$hours_2" "$avg_w_display" | tee -a "$LOGFILE"
else
  printf '%s %s %s\n' "$NOW_TS" "$event_padded" "$current_energy_display" | tee -a "$LOGFILE"
fi

# Clean up state file in /tmp so it won't be reused by accident
if [ -f "$STATE_FILE" ]; then
  rm -f "$STATE_FILE" || true
fi

exit 0
