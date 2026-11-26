#!/bin/zsh
# Builds the helper, installs the login job (LaunchAgent local.edge-sidebar) and, if missing, the app list.
# Safe to re-run.
set -e; cd ${0:h}
mkdir -p ~/bin ~/.config ~/Library/LaunchAgents ~/Library/Logs
swiftc -O edge-sidebar.swift -o ~/bin/edge-sidebar
[ -f ~/.config/edge-sidebar.json ] || cp edge-sidebar.example.json ~/.config/edge-sidebar.json
P=~/Library/LaunchAgents/local.edge-sidebar.plist
cat > $P <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>local.edge-sidebar</string>
	<key>ProgramArguments</key><array><string>$HOME/bin/edge-sidebar</string></array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>ProcessType</key><string>Interactive</string>
	<key>StandardErrorPath</key><string>$HOME/Library/Logs/edge-sidebar.log</string>
</dict>
</plist>
PLIST
launchctl bootout gui/$(id -u)/local.edge-sidebar 2>/dev/null || true
launchctl bootstrap gui/$(id -u) $P
echo "edge-sidebar running: $(pgrep -x edge-sidebar)"
