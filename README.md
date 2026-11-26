# mac-setup

My Mac's custom input setup: BetterTouchTool gestures and shortcuts, and a small helper that shows an app's sidebar
when the pointer rests on the left side of its window. Private; holds no secrets.

## What it does

| Input | Result |
|---|---|
| 3-finger swipe left / right | Snap the window under the pointer to the left / right half of the screen |
| 3-finger swipe up | Mission Control |
| 3-finger swipe down | Show Desktop (again to bring windows back) |
| 2-finger spread | Maximise the window under the pointer; again to restore. **Not working yet**, see Known issues |
| Home / End | Jump to the top / bottom (sends Cmd+Up / Cmd+Down) |
| Pointer on the left side of a window | That app's sidebar appears; it hides when the pointer moves away |

## Restore on a new Mac

1. Install BetterTouchTool and allow external scripting in its settings.
2. System Settings → Trackpad → More Gestures: turn off Mission Control, App Exposé and "Swipe between full-screen
   applications", so macOS does not also react to the three-finger swipes.
3. `bettertouchtool/restore.sh`: re-adds every trigger in `bettertouchtool/triggers.json`. Safe to re-run.
4. `edge-sidebar/install.sh`: builds the helper into `~/bin`, installs the login job, copies the app list.

## Sidebar helper (`edge-sidebar/`)

BetterTouchTool only has screen-edge triggers, so a helper watches the pointer and window frames instead.

- Shows the sidebar when the pointer rests for 0.12 s on the left 28 px inside a window (title bar and Dock excluded);
  hides it once the pointer is more than 340 px from the window's left side or leaves the window. These numbers are
  the constants at the top of `edge-sidebar.swift`.
- It needs no macOS permission. The key press is sent by BetterTouchTool: the helper opens
  `btt://trigger_named/?trigger_name=sidebar_…`, and that named trigger sends the app's shortcut.
- A window that is not in front is brought to the front for the toggle.
- Runs as LaunchAgent `com.shokunin.edge-sidebar` (`~/bin/edge-sidebar`, errors in `~/Library/Logs/edge-sidebar.log`).

### Add an app

Edit `~/.config/edge-sidebar.json` (read live, no restart): `"bundle.identifier": "named_trigger"`.
Use `{"show": "trigger_a", "hide": "trigger_b"}` instead of one name when showing and hiding are different commands
(Safari); such an app cannot get out of step.

| Named trigger | Sends | Used by |
|---|---|---|
| `safari_tabcol_expand` / `safari_tabcol_collapse` | AppleScript: sets the width of Safari's vertical tab column (expanded with titles / icon-only strip) | Safari |
| `safari_tabcol_toggle` | Same, as one toggle | free to bind to a key or gesture |
| `sidebar_cmd_shift_l` | Cmd+Shift+L | unused (opens Safari's separate sidebar, not the tab column) |
| `safari_tabs_show` / `safari_tabs_hide` | Menu items: Tab Layout → Vertical + Show Sidebar / Hide Sidebar + Tab Layout → Compact | **Not in use.** In Safari 27.3, Hide Sidebar followed by Compact leaves an empty grey column that only quitting Safari clears (2026-11-25) |
| `sidebar_opt_cmd_s` | Opt+Cmd+S | Finder, Notes |
| `sidebar_ctrl_cmd_s` | Ctrl+Cmd+S | Mail, Music, TV, Preview, Reminders, Calendar |
| `sidebar_cmd_b` | Cmd+B | Claude |
| `sidebar_cmd_shift_s` | Cmd+Shift+S | Codex |

An app with a different shortcut needs a new named trigger in BetterTouchTool (trigger type "Named Trigger", one
"Send Keyboard Shortcut" action); add it to `triggers.json` too. Find a bundle identifier with
`osascript -e 'id of app "Name"'`.

### Safari's vertical tab column

Safari has no command or shortcut for collapsing the vertical tab column. The `safari_tabcol_*` triggers run an
AppleScript inside BetterTouchTool (it has the Accessibility permission) that sets the value of `splitter 2 of
splitter group 1` of the front Safari window: 40 collapses to the icon strip (Safari settles at about 52), the saved
width (`~/.config/safari-tabcol-width`, default 210) expands. Sources: `bettertouchtool/scripts/`. They only do
something while Tab Layout is Vertical.

## Known issues

- **The helper toggles blindly.** It cannot see whether a sidebar is open. If you open one by hand, that app runs
  inverted (hides on approach) until you toggle it once more by hand.
- **2-finger spread does nothing.** BetterTouchTool never receives the gesture while "Zoom in or out" is off in
  System Settings → Trackpad → Scroll & Zoom. Options: turn zoom back on (apps like Safari will zoom too), or move
  the toggle to a three-finger tap.
- **Home on the Keychron Q1 HE.** Its top-right key sends nothing a Mac understands; assign Home to it in
  launcher.keychron.com (cable, Chrome). Home on other keyboards works.
- **Mission Control cannot be opened and cancelled in one motion** the way the macOS gesture allows; macOS plays the
  whole animation before accepting the next toggle.

## Changing it

- Gestures: edit in BetterTouchTool, then re-export what changed into `bettertouchtool/triggers.json` (triggers made
  here have UUIDs starting `5A1C`). `triggers.json` is not a full preset: triggers that existed before 2026-11-24
  are not in it.
- `IF` actions in `triggers.json` carry an archived NSPredicate in `BTTIfConditionData`; the format string alone
  always evaluates false. `bettertouchtool/pred.swift` prints the data for a format string.
