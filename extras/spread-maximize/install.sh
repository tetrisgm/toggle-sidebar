#!/bin/zsh
# Two-finger spread on the trackpad maximises the window under the pointer, or restores it. Builds the helper into
# ~/bin, installs the login job (LaunchAgent local.spread-maximize) and adds the two BetterTouchTool named triggers
# it calls. Safe to re-run. Needs BetterTouchTool running with external scripting allowed.
set -e; cd ${0:h}
mkdir -p ~/bin ~/Library/LaunchAgents ~/Library/Logs
clang -O2 -framework CoreFoundation -framework CoreGraphics -framework ApplicationServices spread-maximize.c -o ~/bin/spread-maximize
../../bettertouchtool/restore.sh spread-maximize.json
P=~/Library/LaunchAgents/local.spread-maximize.plist
cat > $P <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key><string>local.spread-maximize</string>
	<key>ProgramArguments</key><array><string>$HOME/bin/spread-maximize</string></array>
	<key>RunAtLoad</key><true/>
	<key>KeepAlive</key><true/>
	<key>ProcessType</key><string>Interactive</string>
	<key>StandardErrorPath</key><string>$HOME/Library/Logs/spread-maximize.log</string>
</dict>
</plist>
PLIST
launchctl bootout gui/$(id -u)/local.spread-maximize 2>/dev/null || true
launchctl bootstrap gui/$(id -u) $P
sleep 1; tail -1 ~/Library/Logs/spread-maximize.log
