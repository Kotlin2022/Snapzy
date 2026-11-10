# Remote-control compatibility (UU Remote / ToDesk / …)

## Symptoms

With UU Remote (or similar agents) running, area capture can look stuck:

- selection crosshair does not follow the pointer
- system cursor disappears
- the overlay feels frozen even though Escape still cancels

Separately, a **local re-sign/reinstall** can make Snapzy’s own permission UI say
“Grant Access” while System Settings already shows Screen Recording / Accessibility
toggled on — menus stay gray, captures show a blank/gray overlay.

## Root causes

### 1. Live passthrough event tap

Live (backdrop-less) screenshot mode installs a consuming `CGEvent` tap and hides
the system cursor. Remote agents inject/relay pointer events on the same path; the
tap starves them and the hide blanks their cursor.

**Fix:** when a known remote helper is running (`UURemote.app/`, ToDesk, Sunlogin,
RustDesk — see `LivePassthroughRemoteControlConflict`), skip live passthrough and
use window-event / polled input instead.

### 2. Inline area-annotate cursor hide + SwiftUI hover

Area-annotate freezes a snapshot, hides the system cursor, and draws a crosshair
from SwiftUI `onContinuousHover` / `DragGesture`. Remote injection often moves the
pointer **without** those AppKit/SwiftUI events, so the drawn crosshair freezes
while the real cursor stays hidden.

**Fix:** under the same conflict detector, keep the system cursor visible and poll
`NSEvent.mouseLocation` / `pressedMouseButtons` at display refresh to drive the
crosshair and selection rect (`InlineAreaAnnotateSession`).

### 3. Local install signing ↔ TCC

Ad-hoc re-signs change the code-directory hash. macOS Screen Recording entries can
stay “on” for the old identity while `CGPreflightScreenCaptureAccess()` is false
for the new binary — Snapzy then reports permission denied.

**Fix when installing a local build:**

1. Prefer signing with a stable Apple Development identity (not ad-hoc).
2. After replace: `tccutil reset ScreenCapture com.local.snapzy` (and Accessibility).
3. Quit Snapzy → remove any stale Snapzy rows in System Settings → relaunch → grant
   again → quit once more so the grant binds to the running binary.

## Code map

| Piece | Role |
|-------|------|
| `LivePassthroughRemoteControlConflict` | Detect helpers via `proc_pidpath` |
| `LivePassthroughInputLogic.shouldUseLivePassthroughInput` | Gate live tap |
| `AreaSelectionController` remote-compat polling | Area overlay under remote agents |
| `InlineAreaAnnotateSession` remote-compat polling | Annotate selecting phase |

## Verify

With UU Remote’s daemon/service running, trigger area capture / area-annotate and
confirm logs:

```text
Live passthrough skipped: remote-control agent conflict …
Inline area annotate: remote-control agent conflict — keeping system cursor, polling pointer
Area selection remote-compat pointer polling active
```
