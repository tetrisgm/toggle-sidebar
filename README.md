# toggle-sidebar

![Safari's vertical tab column expanding when the pointer reaches it, and collapsing when it leaves](docs/demo.gif)

**Tired of sidebars hogging your screen all day? Fear no more.**

Sidebars are great for the three seconds you actually need them. The rest of the time they just sit there, eating a
fifth of your window and showing you a list you already know by heart.

toggle-sidebar fixes that. Move your pointer to the left side of a window and the sidebar slides out. Move away and
it's gone. No clicking, no shortcut to remember, no tiny button to hunt for. Your content gets the whole window, and
the sidebar shows up only when you go looking for it.

All it needs is [BetterTouchTool](https://folivora.ai) installed.

## Get it

**The easy way: hand it to your AI coding agent.** Paste this into Claude Code, Codex, or whichever agent you use
on your Mac:

```text
Install toggle-sidebar on this Mac from https://github.com/tetrisgm/toggle-sidebar
Clone it, read AGENTS.md, and follow "Installing it for a user".
```

That's it. The agent clones the repo, checks BetterTouchTool, runs the installer, and asks you to try a hover.

**The manual way: three steps.**

1. Install [BetterTouchTool](https://folivora.ai), open it, and in its settings allow external scripting.
2. Paste this into Terminal:
   ```sh
   git clone https://github.com/tetrisgm/toggle-sidebar && cd toggle-sidebar && ./install.sh
   ```
3. Rest your pointer on the left side of a Finder window. The sidebar should pop out.

For Safari, also choose View → Tab Layout → Vertical. More detail, and how to remove it again, is under
[Install](#install).

| Pointer elsewhere | Pointer on the window's left side |
|---|---|
| ![Safari with the vertical tab column collapsed to icons](docs/safari-collapsed.png) | ![Safari with the tab column expanded](docs/safari-expanded.png) |
| ![Claude with its sidebar hidden](docs/claude-collapsed.png) | ![Claude with its sidebar shown](docs/claude-expanded.png) |

Safari on top, the Claude desktop app below. (The blurry bits are my tabs and chats. Nothing to see there.)

## Apps it covers

The ones I live in. Adding your own takes about a minute (see below).

| App | When the pointer rests on the window's left side | When it moves away |
|---|---|---|
| **Safari** (vertical tabs) | The tab column expands to show tab titles, and each tab shows as you sweep over it | It collapses to the icon-only strip. New windows start collapsed |
| **Finder** | The sidebar (Favourites, Locations, Tags) appears | It hides |
| **Notes** | The folder list appears | It hides |
| **Mail** | The mailbox list appears | It hides |
| **Music**, **TV** | The library sidebar appears | It hides |
| **Preview** | The page / thumbnail sidebar appears | It hides |
| **Reminders** | The list sidebar appears | It hides |
| **Calendar** | The calendar list appears | It hides |
| **Claude** (desktop app) | The conversation sidebar appears | It hides |
| **Codex** (desktop app) | The project / chat sidebar appears | It hides |

**Safari gets special treatment.** With vertical tabs you normally pick between a wide column that eats your page
and a skinny strip of icons you can't read. Now you get both: icons while you browse, full tab titles the moment you
reach for them. Safari has no command for this, so toggle-sidebar sets the column's width directly, which also means
it always ends up in the right state.

Every other app simply gets its own "toggle sidebar" keyboard shortcut, once on the way in and once on the way out
(see Known limits).

It works on whichever window is under the pointer, also when that app is not in front. Windows smaller than
500 × 300, the title bar and the Dock are left alone.

## Install

The details behind [Get it](#get-it). You need a Mac, BetterTouchTool (running, with external scripting allowed in
its settings) and the Xcode command line tools (`xcode-select --install` if `git` or `swiftc` is missing). Then:

```sh
git clone https://github.com/tetrisgm/toggle-sidebar && cd toggle-sidebar && ./install.sh
```

`install.sh` adds the named triggers to BetterTouchTool, builds the helper into `~/bin`, installs it as a login job,
copies the app list to `~/.config/edge-sidebar.json` (kept if you already have one) and runs a self-check.
For Safari, also set View → Tab Layout → Vertical.

It only adds triggers with this repo's own UUIDs (they start `5A1C`); nothing else in your BetterTouchTool setup is
changed. It is safe to re-run, the helper needs no macOS permission of its own, and `./uninstall.sh` removes it all.

Agents: `AGENTS.md` has the install steps, the checks to run and what to ask the user. This whole thing was built
by an agent in one evening, so it is written for one.

## How it works

For the curious. You don't need any of this to use it.

- `edge-sidebar/edge-sidebar.swift` checks the pointer about 25 times a second. When it rests for 0.06 s in the
  left 28 px of a listed app's window (Safari: 56 px, its whole icon strip), it fires that app's "show" trigger.
  When the pointer is more than 340 px from the window's left side, or leaves the window, it fires "hide".
  These numbers are constants at the top of the file.
- A trigger is fired by opening `btt://trigger_named/?trigger_name=…`. The named trigger in BetterTouchTool then
  sends the keyboard shortcut, or for Safari runs an AppleScript.
- An app's own small windows (tab previews, tooltips, popovers) are looked through, so hovering a Safari tab
  does not count as leaving the window.
- The helper runs as LaunchAgent `local.edge-sidebar` and logs each show/hide to `~/Library/Logs/edge-sidebar.log`.
  Create `~/.config/edge-sidebar.trace` to log what is under the pointer; delete it to stop.

### Safari's vertical tab column

The column is an accessibility splitter: `splitter 2 of splitter group 1` of the browser window. Setting its value
to 40 collapses it to the icon strip (Safari settles at about 52); setting it to the saved width expands it
(`~/.config/safari-tabcol-width`, default 210; drag the column wider once and that width is remembered).
The AppleScripts are in `bettertouchtool/scripts/` and run inside BetterTouchTool, which has the Accessibility
permission. They search all of Safari's windows, because a tab preview can be the frontmost one.
`safari_tabcol_toggle` does the same as a single toggle, free to bind to a key or gesture.

![Sweeping the pointer down Safari's tab column, each tab showing as it passes](docs/tab-scrubbing.gif)

**Tab scrubbing** (`"scrubTabs": true`): while the column is open, sweep the pointer down the tabs and each one shows
as you pass over it. Whichever tab you end on stays selected, no click needed.
Row positions come from the `safari_tab_geometry` trigger; the switching uses Safari's own AppleScript, so macOS asks
once whether `edge-sidebar` may control Safari. Sleeping tabs reload when you pass them.

## Add or change an app

Edit `~/.config/edge-sidebar.json`. It is read live; no restart.

```json
{
  "com.apple.finder": "sidebar_opt_cmd_s",
  "com.apple.Safari": { "show": "safari_tabcol_expand", "hide": "safari_tabcol_collapse",
                        "activate": false, "collapseNew": true, "zone": 56 }
}
```

- A plain name is one named trigger used for both directions (a toggle).
- An object gives separate `show` and `hide` triggers. Optional: `activate` (false if the trigger does not need
  the app in front), `collapseNew` (run `hide` for windows that appear), `zone` (hover width in px).
- Find an app's bundle identifier with `osascript -e 'id of app "Name"'`.

Named triggers that ship in `triggers.json`:

| Named trigger | Sends | Used by |
|---|---|---|
| `safari_tabcol_expand` / `safari_tabcol_collapse` / `safari_tabcol_toggle` | AppleScript (column width) | Safari |
| `sidebar_opt_cmd_s` | Opt+Cmd+S | Finder, Notes |
| `sidebar_ctrl_cmd_s` | Ctrl+Cmd+S | Mail, Music, TV, Preview, Reminders, Calendar |
| `sidebar_cmd_b` | Cmd+B | Claude |
| `sidebar_cmd_shift_s` | Cmd+Shift+S | Codex |

An app with another shortcut needs one more named trigger in BetterTouchTool: trigger type "Named Trigger", one
"Send Keyboard Shortcut" action.

## Known limits

It's a hover trick, not magic.

- **Apps other than Safari are toggled blindly.** The helper cannot see whether a sidebar is open. If you open one
  by hand, that app runs inverted (hides on approach) until you toggle it once more by hand.
- **Only the left side.** Right-hand inspectors and sidebars are not covered.
- **Safari: do not switch Tab Layout automatically.** Hiding the sidebar and then switching Vertical → Compact left
  an empty grey column in Safari 27.3 that only quitting Safari cleared.

## Bonus: spread to maximise

Spread two fingers apart on the trackpad and the window under your pointer fills the screen. Spread again and it goes
back to its old size. Like a zoom gesture, but for windows, and no app zooms by accident.

```sh
extras/spread-maximize/install.sh
```

Not part of the main install. It's a tiny helper that reads raw trackpad touches (so macOS "Zoom in or out" can stay
off), checks whether the window under the pointer already fills its display, and asks BetterTouchTool to maximise or
restore it (named triggers `maximize_on` / `maximize_restore`, in `bettertouchtool/spread-maximize.json`).

- Only a real spread counts: both fingers fully landed, each moving away from the other. Scrolling, two-finger taps
  and two-finger clicks (right-click) are ignored.
- Tuning constants (how far, how fast) are at the top of `extras/spread-maximize/spread-maximize.c`; each detected
  spread is logged to `~/Library/Logs/spread-maximize.log`.
- "Restore" goes back to the size before BetterTouchTool last maximised that window.

## Optional extras

`bettertouchtool/extras.json` holds a few unrelated BetterTouchTool triggers from the same setup. They are not
installed by default: `bettertouchtool/restore.sh extras.json` adds them.

| Input | Result |
|---|---|
| 3-finger swipe left / right | Snap the window under the pointer to the left / right half of the screen |
| 3-finger swipe up / down | Mission Control / Show Desktop (turn the macOS three-finger gestures off in System Settings → Trackpad → More Gestures) |
| Home / End | Send Cmd+Up / Cmd+Down |
| 3-finger click | Close the current tab (Cmd+W) |
| 3-finger tap | Middle click (closes the tab under the pointer in Safari, opens links in a new tab) |
| 1-finger tap, top middle of the trackpad | Close the current tab (Cmd+W) |

`IF` actions carry an archived NSPredicate in `BTTIfConditionData`; `bettertouchtool/pred.swift` generates it from a
format string.
