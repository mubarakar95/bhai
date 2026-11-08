#!/usr/bin/env bash
# Android wireless debugging helper (Android 11+; phone and computer on the same Wi-Fi).
#
# Phone: Settings > Developer options > Wireless debugging > ON
#   pair    -> tap "Pair device with pairing code", enter the IP:PORT shown there (one-time)
#   connect -> use the IP:PORT on the main Wireless debugging screen (port changes after
#              you toggle the setting or reboot; adb usually auto-reconnects otherwise)
set -euo pipefail

case "${1:-}" in
  pair)
    read -rp "Pairing address (IP:PORT from the pairing dialog): " addr
    adb pair "$addr"
    ;;
  connect)
    read -rp "Device address (IP:PORT from the Wireless debugging screen): " addr
    adb connect "$addr"
    adb devices -l
    ;;
  status)
    adb devices -l
    ;;
  *)
    echo "usage: $0 pair | connect | status" >&2
    exit 1
    ;;
esac
