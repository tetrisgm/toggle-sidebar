// edge-sidebar: shows an app's sidebar while the pointer rests on the left side of its window and hides it again when
// the pointer leaves. It only watches the pointer and window frames (no special permission); the keyboard shortcut is
// sent by BetterTouchTool through named triggers (btt://trigger_named). Config: ~/.config/edge-sidebar.json maps
// bundle identifier -> named trigger (one toggle used for both directions), or -> {"show": trigger, "hide": trigger}. Run by LaunchAgent com.shokunin.edge-sidebar.
import Cocoa

let zone: CGFloat = 28       // px inside the window's left edge that count as "there"
let skipTop: CGFloat = 52    // title bar / traffic lights are left alone
let keep: CGFloat = 340      // revealed sidebar stays while the pointer is within this many px of the left edge
let dwell = 0.12, grace = 0.25

let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/edge-sidebar.json")
var table: [String: (show: String, hide: String)] = [:], tableDate = Date.distantPast
func loadTable() {
  guard let d = (try? FileManager.default.attributesOfItem(atPath: configURL.path))?[.modificationDate] as? Date, d != tableDate,
        let data = try? Data(contentsOf: configURL), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
  table = [:]; tableDate = d
  for (k, v) in j {
    if let s = v as? String { table[k] = (s, s) }
    else if let o = v as? [String: String], let sh = o["show"], let hi = o["hide"] { table[k] = (sh, hi) }
  }
}

struct Hit { let id: Int; let pid: pid_t; let bundle: String; let rect: CGRect }
func windowAt(_ p: CGPoint) -> Hit? {
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
  for w in list {
    guard (w[kCGWindowLayer as String] as? Int) == 0, (w[kCGWindowAlpha as String] as? Double ?? 1) > 0,
          let b = w[kCGWindowBounds as String] as? [String: CGFloat], let x = b["X"], let y = b["Y"], let wd = b["Width"], let h = b["Height"] else { continue }
    let r = CGRect(x: x, y: y, width: wd, height: h)
    guard r.contains(p) else { continue }
    let pid = pid_t(w[kCGWindowOwnerPID as String] as? Int ?? 0)
    return Hit(id: w[kCGWindowNumber as String] as? Int ?? 0, pid: pid, bundle: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "", rect: r)
  }
  return nil
}
// The Dock and menu bar are outside every screen's visible frame; the pointer there never counts.
func inVisibleArea(_ p: CGPoint) -> Bool {
  guard let primary = NSScreen.screens.first else { return false }
  let c = CGPoint(x: p.x, y: primary.frame.height - p.y)
  return NSScreen.screens.contains { $0.visibleFrame.contains(c) }
}
func send(_ trigger: String, to pid: pid_t) {
  guard let app = NSRunningApplication(processIdentifier: pid) else { return }
  let front = NSWorkspace.shared.frontmostApplication
  let fire = {
    let t = Process(); t.executableURL = URL(fileURLWithPath: "/usr/bin/open"); t.arguments = ["-g", "btt://trigger_named/?trigger_name=" + trigger]; try? t.run()
  }
  if front?.processIdentifier == pid { fire(); return }
  app.activate()
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
    fire()
    // Hiding after the pointer moved on to another app: give that app the focus back.
    if let f = front, let now = windowAt(CGEvent(source: nil)?.location ?? .zero), now.pid == f.processIdentifier {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { f.activate() }
    }
  }
}

var last = CGPoint(x: -1, y: -1)
var candidate: (id: Int, since: Date)? = nil
var revealed: (hit: Hit, hide: String, outSince: Date?)? = nil
loadTable()
Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
  guard let p = CGEvent(source: nil)?.location else { return }
  let moved = p != last; last = p
  if !moved && candidate == nil && revealed?.outSince == nil { return }
  if CGEventSource.buttonState(.combinedSessionState, button: .left) { candidate = nil; return }   // not while dragging
  let hit = windowAt(p)
  if var r = revealed {
    let same = hit?.id == r.hit.id
    let rect = same ? hit!.rect : r.hit.rect
    if same && p.x <= rect.minX + keep { r.outSince = nil; revealed = r; return }
    if r.outSince == nil { r.outSince = Date(); revealed = r; return }
    if Date().timeIntervalSince(r.outSince!) >= grace { revealed = nil; send(r.hide, to: r.hit.pid) }
    return
  }
  loadTable()
  guard let h = hit, let trigger = table[h.bundle], h.rect.width >= 500, h.rect.height >= 300, inVisibleArea(p),
        p.x <= h.rect.minX + zone, p.y >= h.rect.minY + skipTop, p.y <= h.rect.maxY - 8 else { candidate = nil; return }
  if candidate?.id != h.id { candidate = (h.id, Date()); return }
  if Date().timeIntervalSince(candidate!.since) >= dwell { candidate = nil; revealed = (h, trigger.hide, nil); send(trigger.show, to: h.pid) }
}
RunLoop.main.run()
