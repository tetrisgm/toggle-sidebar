// edge-sidebar: shows an app's sidebar while the pointer rests on the left side of its window and hides it again when
// the pointer leaves. It only watches the pointer and window frames (no special permission); the keyboard shortcut is
// sent by BetterTouchTool through named triggers (btt://trigger_named). Config: ~/.config/edge-sidebar.json maps
// bundle identifier -> named trigger (one toggle used for both directions), or -> {"show": trigger, "hide": trigger,
// "activate": false (the trigger does not need the app in front), "collapseNew": true (run "hide" for windows that appear),
// "zone": px (hover area for this app instead of the default)}. Run by LaunchAgent com.shokunin.edge-sidebar.
import Cocoa

let zone: CGFloat = 28       // px inside the window's left edge that count as "there"
let skipTop: CGFloat = 52    // title bar / traffic lights are left alone
let keep: CGFloat = 340      // revealed sidebar stays while the pointer is within this many px of the left edge
let dwell = 0.06, grace = 0.3

let configURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/edge-sidebar.json")
struct Rule { let show: String; let hide: String; let activate: Bool; let collapseNew: Bool; let zone: CGFloat }
var table: [String: Rule] = [:], tableDate = Date.distantPast
func loadTable() {
  guard let d = (try? FileManager.default.attributesOfItem(atPath: configURL.path))?[.modificationDate] as? Date, d != tableDate,
        let data = try? Data(contentsOf: configURL), let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
  table = [:]; tableDate = d
  for (k, v) in j {
    if let s = v as? String { table[k] = Rule(show: s, hide: s, activate: true, collapseNew: false, zone: zone) }
    else if let o = v as? [String: Any], let sh = o["show"] as? String, let hi = o["hide"] as? String {
      table[k] = Rule(show: sh, hide: hi, activate: o["activate"] as? Bool ?? true, collapseNew: o["collapseNew"] as? Bool ?? false, zone: CGFloat(o["zone"] as? Double ?? Double(zone)))
    }
  }
}

struct Hit { let id: Int; let pid: pid_t; let bundle: String; let rect: CGRect }
let minSize = CGSize(width: 500, height: 300)   // smaller windows (popovers, previews, panels) are ignored
func windowAt(_ p: CGPoint) -> Hit? {
  guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
  var small: Hit? = nil
  for w in list {
    guard (w[kCGWindowLayer as String] as? Int) == 0, (w[kCGWindowAlpha as String] as? Double ?? 1) > 0,
          let b = w[kCGWindowBounds as String] as? [String: CGFloat], let x = b["X"], let y = b["Y"], let wd = b["Width"], let h = b["Height"] else { continue }
    let r = CGRect(x: x, y: y, width: wd, height: h)
    guard r.contains(p) else { continue }
    let pid = pid_t(w[kCGWindowOwnerPID as String] as? Int ?? 0)
    let hit = Hit(id: w[kCGWindowNumber as String] as? Int ?? 0, pid: pid, bundle: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "", rect: r)
    // An app's own small windows (tab previews, tooltips, popovers) are looked through to its main window below;
    // a small window of another app on top counts as that app.
    if r.width < minSize.width || r.height < minSize.height { if small == nil { small = hit }; continue }
    if let sm = small, sm.pid != pid { return sm }
    return hit
  }
  return small
}
// The Dock and menu bar are outside every screen's visible frame; the pointer there never counts.
func inVisibleArea(_ p: CGPoint) -> Bool {
  guard let primary = NSScreen.screens.first else { return false }
  let c = CGPoint(x: p.x, y: primary.frame.height - p.y)
  return NSScreen.screens.contains { $0.visibleFrame.contains(c) }
}
func send(_ trigger: String, to pid: pid_t, activate: Bool = true) {
  guard let app = NSRunningApplication(processIdentifier: pid) else { return }
  let front = NSWorkspace.shared.frontmostApplication
  let fire = {
    let c = NSWorkspace.OpenConfiguration(); c.activates = false
    NSWorkspace.shared.open(URL(string: "btt://trigger_named/?trigger_name=" + trigger)!, configuration: c, completionHandler: nil)
  }
  if !activate || front?.processIdentifier == pid { fire(); return }
  app.activate()
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
    fire()
    // Hiding after the pointer moved on to another app: give that app the focus back.
    if let f = front, let now = windowAt(CGEvent(source: nil)?.location ?? .zero), now.pid == f.processIdentifier {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { f.activate() }
    }
  }
}

// Events go to stderr (~/Library/Logs/edge-sidebar.log): what fired, and why a pointer near a left edge was ignored.
var lastNote = ""
func note(_ m: String) {
  if m == lastNote { return }; lastNote = m
  let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"
  FileHandle.standardError.write((f.string(from: Date()) + " " + m + "\n").data(using: .utf8)!)
}
let tracePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/edge-sidebar.trace").path
var last = CGPoint(x: -1, y: -1)
var candidate: (id: Int, since: Date)? = nil
var revealed: (hit: Hit, rule: Rule, outSince: Date?)? = nil
loadTable()
Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
  guard let p = CGEvent(source: nil)?.location else { return }
  let moved = p != last; last = p
  if !moved && candidate == nil && revealed?.outSince == nil { return }
  if CGEventSource.buttonState(.combinedSessionState, button: .left) { candidate = nil; return }   // not while dragging
  let hit = windowAt(p)
  // Trace mode: while ~/.config/edge-sidebar.trace exists, log what is under the pointer whenever it is near a left edge.
  if FileManager.default.fileExists(atPath: tracePath), p.x - (hit?.rect.minX ?? -9999) < 400 {
    lastNote = ""; note("trace x=\(Int(p.x)) y=\(Int(p.y)) over \(hit?.bundle ?? "nothing") \(Int(hit?.rect.width ?? 0))x\(Int(hit?.rect.height ?? 0)) left=\(Int(hit?.rect.minX ?? 0)) state=\(revealed != nil ? "revealed" : candidate != nil ? "candidate" : "idle")")
  }
  if var r = revealed {
    if let h = hit, h.id == r.hit.id { r.hit = h }
    let rect = r.hit.rect
    if hit?.pid == r.hit.pid && rect.contains(p) && p.x <= rect.minX + keep { r.outSince = nil; revealed = r; return }
    if r.outSince == nil { r.outSince = Date(); revealed = r; return }
    if Date().timeIntervalSince(r.outSince!) >= grace { revealed = nil; note("hide \(r.hit.bundle) pointer x=\(Int(p.x)) over \(hit?.bundle ?? "nothing")"); send(r.rule.hide, to: r.hit.pid, activate: r.rule.activate) }
    return
  }
  loadTable()
  guard let h = hit, let trigger = table[h.bundle] else { candidate = nil; return }
  guard p.x <= h.rect.minX + trigger.zone else { candidate = nil; return }
  guard h.rect.width >= minSize.width, h.rect.height >= minSize.height, inVisibleArea(p),
        p.y >= h.rect.minY + skipTop, p.y <= h.rect.maxY - 8 else {
    note("ignored \(h.bundle): window \(Int(h.rect.width))x\(Int(h.rect.height)) pointer x=\(Int(p.x)) y=\(Int(p.y)) visible=\(inVisibleArea(p))"); candidate = nil; return }
  if candidate?.id != h.id { candidate = (h.id, Date()); return }
  if Date().timeIntervalSince(candidate!.since) >= dwell { candidate = nil; revealed = (h, trigger, nil); note("show \(h.bundle) pointer x=\(Int(p.x)) y=\(Int(p.y))"); send(trigger.show, to: h.pid, activate: trigger.activate) }
}
// Apps with "collapseNew": windows that appear (and the ones present at start) get the hide trigger once.
var seen = Set<Int>()
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
  loadTable()
  guard table.values.contains(where: { $0.collapseNew }),
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
  var now = Set<Int>(), fire: [pid_t: Rule] = [:]
  for w in list where (w[kCGWindowLayer as String] as? Int) == 0 {
    let id = w[kCGWindowNumber as String] as? Int ?? 0, pid = pid_t(w[kCGWindowOwnerPID as String] as? Int ?? 0)
    guard let b = w[kCGWindowBounds as String] as? [String: CGFloat], (b["Width"] ?? 0) >= minSize.width, (b["Height"] ?? 0) >= minSize.height else { continue }
    now.insert(id)
    if !seen.contains(id), let b = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, let r = table[b], r.collapseNew,
       revealed == nil { fire[pid] = r }
  }
  seen = now
  for (pid, r) in fire { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if revealed == nil { send(r.hide, to: pid, activate: r.activate) } } }
}
RunLoop.main.run()
