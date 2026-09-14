# Screenshot Border Design

**Date:** 2026-09-14  
**Status:** Approved for implementation  
**Approach:** Unified pre-save image applier (Capture → Screenshot settings)

## Goal

Optionally add an outward border to every screenshot output (area / window / fullscreen / scrolling, etc.) before the file is written, so annotate and post-capture actions see the bordered image. Color, thickness, and corner radius are configured under Capture → Screenshot.

## Requirements

1. Settings live in **Capture → Screenshot** with a master enable toggle + color / thickness / corner radius.
2. Apply to **all screenshot outputs** that go through `ScreenCaptureManager.saveImage` / `saveProcessedImage`.
3. **Outward expand:** output size = content + `2 × thickness`; corner radius clips content; border ring is filled with the chosen color.
4. Apply **immediately on save**, before annotate opens / clipboard / history.

## Non-goals

- Recording frames
- Re-editing border independently inside Annotate after apply (pixels are baked in)
- Configuration import/export for these keys (can follow later)

## Architecture

| Unit | Responsibility |
|------|----------------|
| `ScreenshotBorderSettings` | Read/clamp preference values from `UserDefaults` |
| `ScreenshotBorderApplier` | Pure `CGImage` + settings → bordered `CGImage` (pixel space) |
| `ScreenCaptureManager.saveImage` | Apply border when enabled before encoding |
| `PreferencesCaptureSettingsView` | Screenshot pane UI |

### Geometry (pixel space)

Given content `W×H`, thickness `B`, corner radius `R` (all pixels after `points × scaleFactor`):

1. Output size `(W + 2B) × (H + 2B)`.
2. Fill output with border color.
3. Clip to outer rounded rect of output bounds with radius `R`.
4. Clip to inner rounded rect inset by `B` with radius `max(0, R − B)`, draw the source image.

If disabled or `B ≤ 0`, return the source image unchanged.

### Defaults

- Enabled: `false`
- Color: white
- Thickness: `12` pt (multiplied by capture `scaleFactor`, default `2` if missing → ~24 px on Retina)
- Corner radius: `16` pt

### Preference keys

- `screenshot.borderEnabled`
- `screenshot.borderColor` (archived `NSColor`)
- `screenshot.borderWidth` (`Double` points)
- `screenshot.borderCornerRadius` (`Double` points)

## Testing

- Applier: disabled / zero width → identity size; enabled expands by `2B`; corner path does not crash on large R.
- Settings clamp: width/radius ≥ 0, reasonable upper bound (e.g. 128 pt).
- Optional: `saveProcessedImage` path applies when enabled (integration-light via applier injection if needed).
