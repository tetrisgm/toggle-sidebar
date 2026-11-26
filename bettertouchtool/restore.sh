#!/bin/zsh
# Adds the triggers of a JSON file (default: triggers.json, the sidebar named triggers) to the running BetterTouchTool.
# Only triggers with the UUIDs in that file are touched: an existing one is replaced, nothing else is changed.
# usage: restore.sh [file.json]      e.g. restore.sh extras.json for the optional gestures
cd ${0:h}
python3 - "${1:-triggers.json}" <<'PY'
import json,subprocess,sys
def osa(cmd,*a):
    r=subprocess.run(['osascript','-e','on run argv','-e','tell application "BetterTouchTool" to '+cmd,'-e','end run']+list(a),capture_output=True,text=True)
    if r.returncode: sys.exit("BetterTouchTool did not answer. Is it running, with external scripting allowed in its settings?\n"+r.stderr.strip())
    return r.stdout.strip()
osa('get_string_variable "BTTActiveAppBundleIdentifier"')
for t in json.load(open(sys.argv[1])):
    osa('delete_trigger (item 1 of argv)',t['BTTUUID'])
    print(osa('add_new_trigger (item 1 of argv)',json.dumps(t)), t.get('BTTTriggerName') or t.get('BTTTriggerTypeDescription') or t.get('BTTGestureNotes') or '')
PY
