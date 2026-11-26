// spread-maximize: two fingers spreading apart on the trackpad maximises the window under the pointer, or restores it
// if it already fills the screen. The helper decides which from the window and display bounds (CGWindowList, no
// permission needed) and runs BetterTouchTool's named trigger "maximize_on" or "maximize_restore".
// (BTT's IF condition could not compare two variables, so the decision is made here.) Reads raw touches through Apple's
// MultitouchSupport framework, so it works while macOS "Zoom in or out" is off and no app zooms.
// Build: clang -O2 -framework CoreFoundation -framework CoreGraphics -framework ApplicationServices spread-maximize.c -o ~/bin/spread-maximize
// Run by LaunchAgent local.spread-maximize (extras/spread-maximize/install.sh). Log: ~/Library/Logs/spread-maximize.log.
#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct { float x, y; } MTPoint;
typedef struct { MTPoint pos, vel; } MTVector;
typedef struct {
  int frame; double timestamp; int identifier, state, fingerId, handId;
  MTVector normalized; float size; int zero1; float angle, majorAxis, minorAxis;
  MTVector absolute; int zero2[2]; float density;
} MTTouch;
typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef, MTTouch *, int, double, int);

// Tuning (normalized trackpad units: 0..1 across the pad)
static const float SPREAD = 0.22f;      // distance between the two fingers must grow by this much
static const float MOVE   = 0.06f;      // and each finger must itself travel this far, away from the other
static const int   SETTLE = 3;          // frames with both fingers resting before the start position is taken
static const float DRIFT  = 0.12f;      // ...while their midpoint moves less than this (rules out scrolling)
static const double WINDOW = 0.8;       // seconds from two fingers landing in which the spread must happen

static int active = 0, fired = 0, settled = 0; static float d0, mx0, my0, ax0, ay0, bx0, by0; static double t0;

static void note(const char *m) {
  time_t t = time(NULL); char b[32]; strftime(b, sizeof b, "%H:%M:%S", localtime(&t));
  fprintf(stderr, "%s %s\n", b, m); fflush(stderr);
}
// Is the window under the pointer already (nearly) as large as its display? Menu bar and Dock make a maximised
// window a little smaller than the display, hence the 90 % / 85 % margins.
static int pointerWindowIsMaximised(void) {
  CGEventRef e = CGEventCreate(NULL); CGPoint p = CGEventGetLocation(e); CFRelease(e);
  CGDirectDisplayID disp; uint32_t nd = 0;
  if (CGGetDisplaysWithPoint(p, 1, &disp, &nd) != kCGErrorSuccess || nd == 0) return 0;
  CGRect db = CGDisplayBounds(disp);
  CFArrayRef l = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
  int result = 0;
  for (CFIndex i = 0; l && i < CFArrayGetCount(l); i++) {
    CFDictionaryRef w = CFArrayGetValueAtIndex(l, i); int layer = -1; CGRect r;
    CFNumberRef ln = CFDictionaryGetValue(w, kCGWindowLayer); if (ln) CFNumberGetValue(ln, kCFNumberIntType, &layer);
    CFDictionaryRef b = CFDictionaryGetValue(w, kCGWindowBounds);
    if (layer != 0 || !b || !CGRectMakeWithDictionaryRepresentation(b, &r) || !CGRectContainsPoint(r, p)) continue;
    if (r.size.width < 300 || r.size.height < 200) continue;          // tab previews, popovers
    result = r.size.width >= db.size.width * 0.90 && r.size.height >= db.size.height * 0.85;
    break;
  }
  if (l) CFRelease(l);
  return result;
}
static void fire(void) {
  if (pointerWindowIsMaximised()) { note("spread -> restore"); system("/usr/bin/open -g 'btt://trigger_named/?trigger_name=maximize_restore' &"); }
  else { note("spread -> maximize"); system("/usr/bin/open -g 'btt://trigger_named/?trigger_name=maximize_on' &"); }
}
// Only fully landed contacts (state 4). Landing/lifting contacts (3, 5) jump around and made a two-finger tap or
// click for right-click look like a spread.
static int touching(MTTouch *t) { return t->state == 4; }

static int callback(MTDeviceRef dev, MTTouch *touches, int n, double ts, int frame) {
  int k = 0; MTTouch *a = NULL, *b = NULL;
  for (int i = 0; i < n; i++) if (touching(&touches[i])) { k++; if (!a) a = &touches[i]; else if (!b) b = &touches[i]; }
  if (k != 2) { active = 0; fired = 0; settled = 0; return 0; }
  // A pressed button means a click (two-finger click = right click), never a spread.
  if (CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft) ||
      CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight)) { fired = 1; return 0; }
  if (a->identifier > b->identifier) { MTTouch *t = a; a = b; b = t; }   // keep the same finger as "a" every frame
  float dx = a->normalized.pos.x - b->normalized.pos.x, dy = a->normalized.pos.y - b->normalized.pos.y;
  float d = sqrtf(dx * dx + dy * dy);
  float mx = (a->normalized.pos.x + b->normalized.pos.x) / 2, my = (a->normalized.pos.y + b->normalized.pos.y) / 2;
  if (!active) {
    if (++settled < SETTLE) return 0;
    active = 1; fired = 0; d0 = d; mx0 = mx; my0 = my; t0 = ts;
    ax0 = a->normalized.pos.x; ay0 = a->normalized.pos.y; bx0 = b->normalized.pos.x; by0 = b->normalized.pos.y;
    return 0;
  }
  if (fired) return 0;
  float drift = sqrtf((mx - mx0) * (mx - mx0) + (my - my0) * (my - my0));
  if (ts - t0 > WINDOW || drift > DRIFT) { fired = 1; return 0; }        // too slow, or a scroll: ignore this gesture
  float max_ = a->normalized.pos.x - ax0, may = a->normalized.pos.y - ay0, mbx = b->normalized.pos.x - bx0, mby = b->normalized.pos.y - by0;
  float ma = sqrtf(max_ * max_ + may * may), mb = sqrtf(mbx * mbx + mby * mby);
  int apart = (max_ * mbx + may * mby) < 0;                         // the fingers moved in opposite directions
  if (d - d0 > SPREAD && ma > MOVE && mb > MOVE && apart) { fired = 1; fire(); }
  return 0;
}

int main(void) {
  void *h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
  if (!h) { note("cannot load MultitouchSupport"); return 1; }
  CFMutableArrayRef (*list)(void) = dlsym(h, "MTDeviceCreateList");
  void (*reg)(MTDeviceRef, MTContactCallback) = dlsym(h, "MTRegisterContactFrameCallback");
  int (*start)(MTDeviceRef, int) = dlsym(h, "MTDeviceStart");
  if (!list || !reg || !start) { note("MultitouchSupport symbols missing"); return 1; }
  CFMutableArrayRef devs = list(); CFIndex c = devs ? CFArrayGetCount(devs) : 0;
  for (CFIndex i = 0; i < c; i++) { MTDeviceRef d = (MTDeviceRef)CFArrayGetValueAtIndex(devs, i); reg(d, callback); start(d, 0); }
  char m[64]; snprintf(m, sizeof m, "watching %ld trackpad(s)", (long)c); note(m);
  CFRunLoopRun();
}
