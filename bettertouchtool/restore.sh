#!/bin/zsh
# Re-adds the saved BetterTouchTool triggers (triggers.json) to the running BetterTouchTool.
# Each trigger keeps its fixed UUID: one that already exists is deleted first, so running this twice is safe.
cd ${0:h}
python3 - <<'PY'
import json,subprocess
def osa(cmd,*a): return subprocess.run(['osascript','-e','on run argv','-e','tell application "BetterTouchTool" to '+cmd,'-e','end run']+list(a),capture_output=True,text=True).stdout.strip()
for t in json.load(open('triggers.json')):
    osa('delete_trigger (item 1 of argv)',t['BTTUUID'])
    print(osa('add_new_trigger (item 1 of argv)',json.dumps(t)), t.get('BTTTriggerTypeDescription') or t.get('BTTGestureNotes') or '')
PY
