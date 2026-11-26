#!/bin/zsh
# Removes the helper, its login job and this repo's BetterTouchTool triggers (sidebar and extras). The app list
# ~/.config/edge-sidebar.json and Safari's saved column width are left in place.
cd ${0:h}
launchctl bootout gui/$(id -u)/local.edge-sidebar 2>/dev/null
rm -f ~/Library/LaunchAgents/local.edge-sidebar.plist ~/bin/edge-sidebar
python3 - <<'PY'
import json,subprocess
for f in ('bettertouchtool/triggers.json','bettertouchtool/extras.json'):
    for t in json.load(open(f)):
        subprocess.run(['osascript','-e','on run argv','-e','tell application "BetterTouchTool" to delete_trigger (item 1 of argv)','-e','end run',t['BTTUUID']],capture_output=True)
PY
echo "removed"
