# Agent entry point

This repo owns the Mac's BetterTouchTool (BTT) triggers and the `edge-sidebar` helper. Start with README.md: it lists
every gesture, the restore steps and the known issues. Keep `bettertouchtool/triggers.json` and the README table in
step with what is live in BTT; commit and push after a verified change.

## Working with BetterTouchTool

- Drive it with AppleScript, no UI: `tell application "BetterTouchTool" to` `get_triggers`, `get_trigger "<uuid>"`,
  `add_new_trigger "<json>"`, `update_trigger "<uuid>" json "<json>"`, `delete_trigger "<uuid>"`,
  `execute_assigned_actions_for_trigger "<uuid>"`, `trigger_action "<json>"`, `get_number_variable` / `get_string_variable`.
  Pass JSON as an `osascript` argument (`on run argv`), not inside the script text.
- Trigger and action IDs, JSON fields and variables are documented inside the app:
  `/Applications/BetterTouchTool.app/Contents/Resources/{trigger,action}-definitions.mdx`. Look IDs up there; do not guess.
- Triggers made for this setup use UUIDs starting `5A1C`; keep that prefix so `triggers.json` can be re-exported by it.
- Verify with BTT's log, newest file in `~/Library/Application Support/BetterTouchTool/Logs/`: `performing <action id>`
  per executed action, `NAMED|<name>` for named triggers. No line means the trigger did not fire.

Behaviour the definitions do not make obvious:

- Give every action in a multi-action trigger an explicit `BTTOrder`; without it the stored order is arbitrary.
- `IF Condition` (330) needs `BTTIfConditionData` (archived NSPredicate, see `bettertouchtool/pred.swift`); with only
  the format string it is always false. `IF JavaScript True` (431) hung for 5 s per run here; avoid it.
- Snap/maximise actions act on the focused window: put `204` (bring window under cursor to front) first.
- Keyboard triggers for Home/End/arrows/F-keys need the Fn flag (`BTTShortcutModifierKeys` 8388608).
- "Pinch In/Out" only fire while macOS "Zoom in or out" is on. Thumb-and-two-finger spreads are read as three-finger
  swipes and collide with the swipe triggers.
- BTT has screen-edge triggers but none for window edges; that is why `edge-sidebar` exists.
- A `Run AppleScript (Blocking)` action (172) runs with BTT's Accessibility permission, so `System Events` UI
  scripting works there even though it fails from an agent shell. Fire it with `trigger_action` and have the script
  write its result to a file to read UI state (this is how Safari's tab-column splitter was found).
- `open -g "btt://trigger_named/?trigger_name=X"` runs a named trigger without stealing focus and needs no permission.

## Limits on this Mac

- Agent shells have no Accessibility or Input Monitoring access: `System Events` cannot send keys or read menus, and
  event taps fail. Do not grant these or change other security settings; send keys through BTT instead.
- You cannot perform trackpad gestures or press physical keys. After a change, check the stored trigger and BTT's log,
  say plainly that the gesture itself is untested, and ask the owner to try it.
- A temporary probe (a trigger that shows a HUD, action 254) is the way to learn what a key or gesture really sends.
  Remove probes in the same session.
- Trackpad gestures also set in System Settings → Trackpad fire together with BTT's. Ask before changing a macOS
  setting; the owner turned the conflicting ones off himself.

## edge-sidebar

Constants (zone, dwell, keep distance) are at the top of `edge-sidebar/edge-sidebar.swift`; after editing run
`edge-sidebar/install.sh` (rebuilds, restarts the LaunchAgent). The app list `~/.config/edge-sidebar.json` is read
live; keep `edge-sidebar.example.json` identical to it. The helper toggles blindly (README, Known issues): do not
"fix" an inverted app by changing code.
