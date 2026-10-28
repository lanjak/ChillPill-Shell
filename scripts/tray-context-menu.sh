#!/bin/sh
# Opens the context menu of the tray item whose Id is $1, at global position $2,$3.
# Quickshell's SystemTrayItem has no ContextMenu call and does not expose the
# item's bus address, so find it through the StatusNotifierWatcher.
W=org.kde.StatusNotifierWatcher
for e in $(busctl --user get-property $W /StatusNotifierWatcher $W RegisteredStatusNotifierItems | tr -d '"' | cut -d' ' -f3-); do
  case "$e" in
    */*) s=${e%%/*}; p=/${e#*/} ;;
    *) s=$e; p=/StatusNotifierItem ;;
  esac
  id=$(busctl --user get-property "$s" "$p" org.kde.StatusNotifierItem Id 2>/dev/null | cut -d'"' -f2)
  [ "$id" = "$1" ] || continue
  busctl --user call "$s" "$p" org.kde.StatusNotifierItem ContextMenu ii "$2" "$3"
  exit
done
