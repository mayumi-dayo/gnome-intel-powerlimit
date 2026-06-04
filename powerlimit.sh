#!/bin/bash
set -e

CONFIG="${CONFIG:-/etc/throttled.conf}"
SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
KDIALOG_BIN="${KDIALOG_BIN:-kdialog}"
NO_TURBO_PATH="${NO_TURBO_PATH:-/sys/devices/system/cpu/intel_pstate/no_turbo}"

show_notification() {
  local message="$1"

  if [[ -z "$KDIALOG_BIN" ]]; then
    return 0
  fi

  if ! command -v "$KDIALOG_BIN" >/dev/null 2>&1; then
    return 0
  fi

  "$KDIALOG_BIN" --passivepopup "$message" 2
}

set_power_limit() {
  local section="$1"
  local limit="$2"

  awk -v target_section="$section" -v limit="$limit" '
    BEGIN {
      in_target = 0
      saw_pl1 = 0
      saw_pl2 = 0
    }

    /^\[/ {
      if (in_target && !saw_pl1) {
        print "PL1_Tdp_W: " limit
      }
      if (in_target && !saw_pl2) {
        print "PL2_Tdp_W: " limit
      }

      in_target = ($0 == "[" target_section "]")
      saw_pl1 = 0
      saw_pl2 = 0
      print
      next
    }

    {
      if (in_target && $0 ~ /^[[:space:]]*PL1_Tdp_W:/) {
        print "PL1_Tdp_W: " limit
        saw_pl1 = 1
        next
      }
      if (in_target && $0 ~ /^[[:space:]]*PL2_Tdp_W:/) {
        print "PL2_Tdp_W: " limit
        saw_pl2 = 1
        next
      }
      print
    }

    END {
      if (in_target && !saw_pl1) {
        print "PL1_Tdp_W: " limit
      }
      if (in_target && !saw_pl2) {
        print "PL2_Tdp_W: " limit
      }
    }
  ' "$CONFIG" > "$CONFIG.tmp"

  mv "$CONFIG.tmp" "$CONFIG"
}

set_turbo_boost() {
  local no_turbo_value="$1"
  local status_message="$2"

  if [[ ! -w "$NO_TURBO_PATH" ]]; then
    echo "Turbo Boost control is not writable: $NO_TURBO_PATH" >&2
    exit 1
  fi

  printf '%s\n' "$no_turbo_value" > "$NO_TURBO_PATH"

  show_notification "$status_message"
}

case "$1" in
  1)
    ACTION=profile
    LIMIT=3
    ;;
  2)
    ACTION=profile
    LIMIT=6
    ;;
  3)
    ACTION=profile
    LIMIT=12
    ;;
  4)
    ACTION=profile
    LIMIT=15
    ;;
  5)
    ACTION=profile
    LIMIT=20
    ;;
  6)
    ACTION=profile
    LIMIT=25
    ;;
  7)
    ACTION=profile
    LIMIT=30
    ;;
  8)
    ACTION=profile
    LIMIT=35
    ;;
  9)
    ACTION=profile
    LIMIT=40
    ;;
  10)
    ACTION=turbo
    NO_TURBO_VALUE=0
    STATUS_MESSAGE="Turbo Boost enabled"
    ;;
  11)
    ACTION=turbo
    NO_TURBO_VALUE=1
    STATUS_MESSAGE="Turbo Boost disabled"
    ;;
  *)
    exit 1
    ;;
esac

if [[ "$ACTION" == "turbo" ]]; then
  set_turbo_boost "$NO_TURBO_VALUE" "$STATUS_MESSAGE"
  exit 0
fi

if [[ "$ACTION" == "turbo" ]]; then
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing throttled config: $CONFIG" >&2
  exit 1
fi

set_power_limit "AC" "$LIMIT"
set_power_limit "BATTERY" "$LIMIT"

"$SYSTEMCTL_BIN" restart throttled.service

show_notification "Throttled PL1/PL2 profile applied (${LIMIT}W)"
