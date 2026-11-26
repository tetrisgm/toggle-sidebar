#!/bin/zsh
# Builds the helper, installs the login job and (if missing) the app list. Safe to re-run.
set -e; cd ${0:h}
swiftc -O edge-sidebar.swift -o ~/bin/edge-sidebar
[ -f ~/.config/edge-sidebar.json ] || cp edge-sidebar.example.json ~/.config/edge-sidebar.json
cp com.shokunin.edge-sidebar.plist ~/Library/LaunchAgents/
launchctl bootout gui/$(id -u)/com.shokunin.edge-sidebar 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.shokunin.edge-sidebar.plist
echo "edge-sidebar running: $(pgrep -x edge-sidebar)"
