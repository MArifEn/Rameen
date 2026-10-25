#!/usr/bin/env bash
# Clean up the stock Google TV home screen over ADB.
# Run from a computer on the same network as the TV. See README.md.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$DIR/packages.txt"
STATE_FILE="$DIR/.disabled-packages"

usage() {
  cat <<USAGE
Usage: $0 <command> [args]

  pair <ip:port> <code>  Pair with the TV (Wireless debugging, Android 11+ devices)
  connect <ip[:port]>    Connect to the TV (default port 5555)
  status                 Show device info and which listed packages are installed/disabled
  clean [-y]             Disable the packages in packages.txt and tidy the home screen
  restore                Re-enable everything this script disabled
USAGE
}

need_adb() {
  command -v adb >/dev/null || { echo "adb not found. Install Android platform-tools first." >&2; exit 1; }
}

need_device() {
  # Wireless debugging often lists the same TV twice (IP:port and an mDNS name).
  if [[ -z "${ANDROID_SERIAL:-}" ]] && (( $(adb devices | awk 'NR > 1 && $2 == "device"' | wc -l) > 1 )); then
    echo "More than one device is connected:" >&2
    adb devices | awk 'NR > 1 && $2 == "device" { print "  " $1 }' >&2
    echo "Pick one, e.g.: export ANDROID_SERIAL=<ip:port>" >&2
    exit 1
  fi
  if [[ "$(adb get-state 2>/dev/null)" != "device" ]]; then
    echo "No TV connected. Run: $0 connect <tv-ip>" >&2
    exit 1
  fi
}

# </dev/null keeps adb from swallowing the stdin of the loops that call it.
shell() { adb shell "$@" </dev/null | tr -d '\r'; }

listed_packages() { sed -e 's/#.*//' -e 's/[[:space:]]//g' "$PACKAGES_FILE" | grep -v '^$' || true; }

installed() { shell pm list packages "$1" | grep -qx "package:$1"; }

disabled() { shell pm list packages -d "$1" | grep -qx "package:$1"; }

cmd_status() {
  need_device
  echo "Device:  $(shell getprop ro.product.manufacturer) $(shell getprop ro.product.model)"
  echo "Android: $(shell getprop ro.build.version.release)"
  echo "Launcher: $(shell cmd package resolve-activity --brief -c android.intent.category.HOME -a android.intent.action.MAIN | tail -n1)"
  echo
  local pkg
  while read -r pkg; do
    if ! installed "$pkg"; then
      printf '  %-45s not installed\n' "$pkg"
    elif disabled "$pkg"; then
      printf '  %-45s disabled\n' "$pkg"
    else
      printf '  %-45s enabled\n' "$pkg"
    fi
  done < <(listed_packages)
}

cmd_clean() {
  need_device
  local yes="${1:-}" pkg todo=()
  while read -r pkg; do
    if installed "$pkg" && ! disabled "$pkg"; then todo+=("$pkg"); fi
  done < <(listed_packages)

  if ((${#todo[@]} == 0)); then
    echo "Nothing to disable."
  else
    echo "Will disable:"
    printf '  %s\n' "${todo[@]}"
    if [[ "$yes" != "-y" ]]; then
      read -rp "Continue? [y/N] " answer
      [[ "$answer" == [yY]* ]] || { echo "Cancelled."; exit 0; }
    fi
    for pkg in "${todo[@]}"; do
      if shell pm disable-user --user 0 "$pkg" >/dev/null; then
        echo "$pkg" >> "$STATE_FILE"
        echo "  disabled $pkg"
      else
        echo "  could not disable $pkg (skipped)" >&2
      fi
    done
  fi

  # Snappier navigation: halve the UI animation durations.
  shell settings put global window_animation_scale 0.5
  shell settings put global transition_animation_scale 0.5
  shell settings put global animator_duration_scale 0.5

  # Restart the launcher so removed rows disappear.
  shell am force-stop com.google.android.apps.tv.launcherx || true
  shell input keyevent KEYCODE_HOME

  cat <<NOTE

Done. Two things can only be changed on the TV itself:
  * Settings > Accounts & sign-in > (your account) > Apps only mode
      removes the For You/recommendation rows and the sponsored banner.
  * Settings > Accounts & sign-in > (your account) > Your services
      turn off services whose content you don't want on the home screen.
NOTE
}

cmd_restore() {
  need_device
  if [[ ! -s "$STATE_FILE" ]]; then
    echo "Nothing to restore."
    return
  fi
  local pkg
  sort -u "$STATE_FILE" | while read -r pkg; do
    if shell pm enable "$pkg" >/dev/null; then echo "  enabled $pkg"; fi
  done
  rm -f "$STATE_FILE"
  shell settings put global window_animation_scale 1
  shell settings put global transition_animation_scale 1
  shell settings put global animator_duration_scale 1
  shell am force-stop com.google.android.apps.tv.launcherx || true
  shell input keyevent KEYCODE_HOME
}

need_adb
case "${1:-}" in
  pair)    [[ $# -eq 3 ]] || { usage; exit 1; }; adb pair "$2" "$3" ;;
  connect) [[ $# -eq 2 ]] || { usage; exit 1; }; t="$2"; [[ "$t" == *:* ]] || t="$t:5555"; adb connect "$t" ;;
  status)  cmd_status ;;
  clean)   cmd_clean "${2:-}" ;;
  restore) cmd_restore ;;
  *)       usage; exit 1 ;;
esac
