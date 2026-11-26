#!/bin/zsh
# One-step install: BetterTouchTool triggers, the helper, the login job; then a self-check.
set -e; cd ${0:h}
[ -d /Applications/BetterTouchTool.app ] || { echo "BetterTouchTool is not installed (https://folivora.ai)"; exit 1 }
pgrep -xq BetterTouchTool || { echo "BetterTouchTool is not running; start it and run this again"; exit 1 }
xcrun --find swiftc >/dev/null 2>&1 || { echo "Xcode command line tools are missing: xcode-select --install"; exit 1 }
bettertouchtool/restore.sh
edge-sidebar/install.sh
# Self-check: BetterTouchTool must log a named trigger fired through the URL scheme the helper uses.
open -g "btt://trigger_named/?trigger_name=toggle_sidebar_selfcheck"; sleep 1.5
L=$(ls -t ~/Library/Application\ Support/BetterTouchTool/Logs/*.log 2>/dev/null | head -1)
if [ -n "$L" ] && tail -200 "$L" | grep -q "NAMED|toggle_sidebar_selfcheck"; then echo "OK: BetterTouchTool receives the helper's triggers"
else echo "WARNING: BetterTouchTool did not log the test trigger. Check its settings: external scripting / URL scheme."; fi
pgrep -xq edge-sidebar && echo "OK: helper running" || echo "WARNING: helper is not running; see ~/Library/Logs/edge-sidebar.log"
echo "Now rest the pointer on the left side of a Finder or Safari window to try it."
