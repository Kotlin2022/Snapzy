# Watermark Settings Persistence Design

**Date:** 2026-09-14  
**Status:** Approved  
**Scope:** Annotate watermark quick-properties defaults remember last-used parameters across sessions.

## Goal

When the user adjusts watermark settings in the annotate quick-properties bar, Snapzy records those values and uses them as the defaults the next time the watermark tool creates a new annotation—including after app relaunch.

## Current Behavior (gaps)

Already persisted across `AnnotateState` instances (UserDefaults):

- Opacity and rotation via `SharedAnnotationParameterDefaults` (`watermarkOpacity`, `watermarkRotationDegrees`) — **only when no watermark is selected**
- Font size via shared `fontSize` — **only when no text/watermark is selected**
- Color via shared primary color — remembered on selection edits when quick-properties sync is on
- Style via `annotationToolProperties[.watermark]` — **only when no watermark is selected** (`setActiveWatermarkStyle` else-branch)

Not persisted:

- `watermarkText` (`@Published`, hard-coded default `"Snapzy"`)
- Style / opacity / rotation / font size when editing a **selected** watermark (selection path updates the item only, does not call remember helpers)

## Requirements

1. Remember **all** of: text, style (single / diagonal / tiled), opacity, rotation, font size, color.
2. Remember whenever the quick-properties bar changes a value, **whether or not** a watermark is selected.
3. Next watermark creation uses the remembered values.
4. Follow existing annotate parameter-memory patterns (no separate preference store).

## Approach

Extend the existing remember pipeline (`SharedAnnotationParameterDefaults` + `annotationToolProperties` + shared primary color). Do not introduce a standalone `WatermarkPreferenceStore`.

## Data Model

### Shared defaults (`PreferencesKeys.annotateParameterDefaults`)

Extend `SharedAnnotationParameterDefaults` with:

```swift
var watermarkText: String?
```

Existing fields continue to hold opacity and rotation:

- `watermarkOpacity`
- `watermarkRotationDegrees`
- `fontSize` (shared with text tool, same as today)

### Tool defaults (`PreferencesKeys.annotateToolParameterDefaults`)

Watermark style continues to live on persisted `AnnotationProperties.watermarkStyle` for `.watermark`.

### Color

Continue using shared primary color (`PreferencesKeys.annotatePrimaryColor`). No watermark-only color key.

### Text sanitization

- Trim whitespace/newlines before persist.
- Empty after trim → store / use `"Snapzy"` (matches `AnnotateAnnotationFactory` empty-text fallback).
- Do not persist a blank string as the lasting default.

### First-run defaults (unchanged)

When nothing is stored: text `"Snapzy"`, style `.diagonal`, opacity `0.22`, rotation `-24°` (diagonal default), font size `36`, color white for watermark base properties / shared color as today.

## Write Path

| Control | Change |
|--------|--------|
| Text (`quickWatermarkTextBinding`) | On set, always update in-memory `watermarkText` and persist into shared defaults (selected or not). When selection exists, still update selected annotations’ text **and** remember. |
| Style (`setActiveWatermarkStyle`) | After updating selected watermarks, also `updateDefaultAnnotationProperties` (style + that style’s default rotation) so next create matches. |
| Opacity / rotation bindings | After a successful selection update, still call `rememberWatermarkOpacity` / `rememberWatermarkRotation`. |
| Font size (`quickTextFontSizeBinding`) | After a successful selection update for text/watermark, still call `rememberAnnotationFontSize`. |
| Color (`quickStrokeColorBinding`) | Keep current behavior (selection + sync already remembers shared color). |

### Style + rotation interaction

Unchanged: choosing a style applies that style’s `defaultRotationDegrees`. That rotation becomes the new remembered rotation.

### Sync toggle

- When `annotateQuickPropertiesSyncEnabled` is off, font size / color keep today’s per-tool independence.
- Watermark-specific fields (text, style, opacity, rotation) always remember against the watermark tool / shared watermark keys regardless of the sync toggle.

## Read Path

1. On `AnnotateState` init / load shared defaults: if `watermarkText` is present (after sanitization), assign `self.watermarkText`.
2. `AnnotateAnnotationFactory` continues to read `state.watermarkText`.
3. `baseAnnotationProperties(for: .watermark)` + `applySharedParameterDefaults` continue to compose style, opacity, rotation, font size, and color for new watermarks.

## Out of Scope

- Configuration import/export schema changes for an explicit watermark-text key (blob under `annotateParameterDefaults` may already round-trip if exporter copies the key wholesale; no new exporter fields required for this feature).
- UI screenshot tests.
- Changing default rotation values per style.

## Testing

Extend `AnnotateWatermarkTests` / `AnnotateCoreTests`:

1. Changing watermark text persists across a new `AnnotateState(defaults:)`; blank/whitespace falls back to `"Snapzy"`.
2. Editing style / opacity / rotation on a **selected** watermark updates `annotationCreationProperties(for: .watermark)` and survives reload from the same `UserDefaults`.
3. Editing font size on a selected watermark updates the next creation default (consistent with shared font memory).
4. Existing no-selection opacity/rotation persistence tests still pass.

## Implementation Touchpoints (expected)

- `Snapzy/Features/Annotate/AnnotateState.swift` — model field, load/persist/sanitize, binding and `setActiveWatermarkStyle` remember paths
- `SnapzyTests/Features/Annotate/AnnotateWatermarkTests.swift` and/or `AnnotateCoreTests.swift` — new cases

## Success Criteria

- Adjust any watermark quick-property → quit/reopen annotate (or new `AnnotateState` with same defaults) → new watermark uses those values.
- Empty text never becomes the lasting default; factory still shows `"Snapzy"`.
- No regression for existing shared stroke/font/arrow memory tests.
