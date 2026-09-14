# Watermark Settings Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist all watermark quick-properties (text, style, opacity, rotation, font size, color) whenever the user changes them, and reuse those values on the next watermark creation across sessions.

**Architecture:** Extend existing `SharedAnnotationParameterDefaults` + `annotationToolProperties` remember pipeline in `AnnotateState`. Add `watermarkText` to shared defaults; ensure selection-path edits also call remember helpers for style/opacity/rotation/font size/text.

**Tech Stack:** Swift / AppKit+SwiftUI annotate editor, `UserDefaults`, XCTest

**Spec:** `docs/superpowers/specs/2026-09-14-watermark-settings-persistence-design.md`

---

## File map

| File | Responsibility |
|------|----------------|
| `Snapzy/Features/Annotate/AnnotateState.swift` | Persist/load watermark text; remember on selection edits |
| `SnapzyTests/Features/Annotate/AnnotateWatermarkTests.swift` | Characterization + new persistence tests |

---

### Task 1: Failing tests for watermark text + selection-path remember

**Files:**
- Modify: `SnapzyTests/Features/Annotate/AnnotateWatermarkTests.swift`

- [x] **Step 1: Append failing tests**

Add these tests at the end of `AnnotateWatermarkTests` (before the closing brace):

```swift
  func testWatermarkTextPersistsAcrossAnnotateStateInstances() {
    let defaults = UserDefaultsFactory.make()
    let firstState = makeAnnotateState(defaults: defaults)
    firstState.activateTool(.watermark)
    firstState.quickWatermarkTextBinding.wrappedValue = "Confidential"

    let reloaded = makeAnnotateState(defaults: defaults)
    XCTAssertEqual(reloaded.watermarkText, "Confidential")
  }

  func testBlankWatermarkTextFallsBackToSnapzyWhenRemembered() {
    let defaults = UserDefaultsFactory.make()
    let state = makeAnnotateState(defaults: defaults)
    state.activateTool(.watermark)
    state.quickWatermarkTextBinding.wrappedValue = "   "

    XCTAssertEqual(state.watermarkText, "Snapzy")

    let reloaded = makeAnnotateState(defaults: defaults)
    XCTAssertEqual(reloaded.watermarkText, "Snapzy")
  }

  func testSelectedWatermarkTextChangeIsRememberedForNextCreate() {
    let defaults = UserDefaultsFactory.make()
    let state = makeAnnotateState(defaults: defaults)
    let annotation = makeWatermarkAnnotation("Snapzy")
    state.annotations = [annotation]
    state.selectedAnnotationId = annotation.id
    state.activateTool(.watermark)

    state.quickWatermarkTextBinding.wrappedValue = "Draft"

    XCTAssertEqual(state.watermarkText, "Draft")
    let reloaded = makeAnnotateState(defaults: defaults)
    XCTAssertEqual(reloaded.watermarkText, "Draft")
  }

  func testSelectedWatermarkStyleOpacityRotationAreRemembered() throws {
    let defaults = UserDefaultsFactory.make()
    let state = makeAnnotateState(defaults: defaults)
    let annotation = makeWatermarkAnnotation()
    state.annotations = [annotation]
    state.selectedAnnotationId = annotation.id
    state.activateTool(.watermark)

    state.setActiveWatermarkStyle(.single)
    state.quickWatermarkOpacityBinding.wrappedValue = 0.55
    state.quickWatermarkRotationBinding.wrappedValue = -8

    let properties = state.annotationCreationProperties(for: .watermark)
    XCTAssertEqual(properties.watermarkStyle, .single)
    XCTAssertEqual(properties.opacity, 0.55, accuracy: 0.0001)
    XCTAssertEqual(properties.rotationDegrees, -8, accuracy: 0.0001)

    let reloaded = makeAnnotateState(defaults: defaults)
    let reloadedProperties = reloaded.annotationCreationProperties(for: .watermark)
    XCTAssertEqual(reloadedProperties.watermarkStyle, .single)
    XCTAssertEqual(reloadedProperties.opacity, 0.55, accuracy: 0.0001)
    XCTAssertEqual(reloadedProperties.rotationDegrees, -8, accuracy: 0.0001)
  }

  func testSelectedWatermarkFontSizeIsRemembered() {
    let defaults = UserDefaultsFactory.make()
    let state = makeAnnotateState(defaults: defaults)
    let annotation = makeWatermarkAnnotation()
    state.annotations = [annotation]
    state.selectedAnnotationId = annotation.id
    state.activateTool(.watermark)

    state.quickTextFontSizeBinding.wrappedValue = 44

    XCTAssertEqual(state.annotationCreationProperties(for: .watermark).fontSize, 44)

    let reloaded = makeAnnotateState(defaults: defaults)
    XCTAssertEqual(reloaded.annotationCreationProperties(for: .watermark).fontSize, 44)
  }
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug \
  -only-testing:SnapzyTests/AnnotateWatermarkTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: new tests FAIL (text not persisted; selection path does not remember).

- [ ] **Step 3: Commit failing tests only**

```bash
git add SnapzyTests/Features/Annotate/AnnotateWatermarkTests.swift
git commit -m "test: cover watermark settings persistence gaps"
```

---

### Task 2: Persist watermark text

**Files:**
- Modify: `Snapzy/Features/Annotate/AnnotateState.swift`

- [ ] **Step 1: Add `watermarkText` to `SharedAnnotationParameterDefaults`**

In the private struct (~line 86):

```swift
  private struct SharedAnnotationParameterDefaults: Codable {
    var strokeWidth: CGFloat?
    var cornerRadius: CGFloat?
    var fontSize: CGFloat?
    var watermarkOpacity: CGFloat?
    var watermarkRotationDegrees: CGFloat?
    var watermarkText: String?
    var spotlightCornerRadius: CGFloat?
    // ... arrow fields unchanged
  }
```

- [ ] **Step 2: Sanitize + apply on load**

In `sanitizedSharedAnnotationParameterDefaults`, include:

```swift
watermarkText: Self.sanitizedWatermarkText(defaults.watermarkText),
```

Add helpers:

```swift
  private static let defaultWatermarkText = "Snapzy"

  private static func sanitizedWatermarkText(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? defaultWatermarkText : trimmed
  }

  private func rememberWatermarkText(_ text: String) {
    let sanitized = Self.sanitizedWatermarkText(text) ?? Self.defaultWatermarkText
    watermarkText = sanitized
    sharedAnnotationParameterDefaults.watermarkText = sanitized
    persistSharedAnnotationParameterDefaults()
  }
```

In `loadSharedAnnotationParameterDefaults`, after assigning sanitized defaults:

```swift
    if let savedText = sharedAnnotationParameterDefaults.watermarkText {
      watermarkText = savedText
    }
```

- [ ] **Step 3: Wire `quickWatermarkTextBinding` set**

Replace the set body so both paths remember:

```swift
      set: { [weak self] newText in
        guard let self else { return }
        let selected = self.quickSelectionTargets(matching: {
          if case .watermark = $0 { return true }
          return false
        })
        if selected.isEmpty {
          self.rememberWatermarkText(newText)
        } else {
          selected.forEach { self.updateWatermarkText(id: $0.id, text: newText) }
          self.rememberWatermarkText(newText)
        }
      }
```

Note: `updateWatermarkText` currently stores raw text on the annotation. Remember path sanitizes empty → `"Snapzy"`. For selected annotations, after remember, also update annotation text to the sanitized value when blank was entered — call `updateWatermarkText` with the sanitized string from `rememberWatermarkText` by returning the sanitized value or re-reading `self.watermarkText` after remember:

Preferred order for selection path:

```swift
          self.rememberWatermarkText(newText)
          selected.forEach { self.updateWatermarkText(id: $0.id, text: self.watermarkText) }
```

- [ ] **Step 4: Run text-related tests**

```bash
xcodebuild test -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug \
  -only-testing:SnapzyTests/AnnotateWatermarkTests/testWatermarkTextPersistsAcrossAnnotateStateInstances \
  -only-testing:SnapzyTests/AnnotateWatermarkTests/testBlankWatermarkTextFallsBackToSnapzyWhenRemembered \
  -only-testing:SnapzyTests/AnnotateWatermarkTests/testSelectedWatermarkTextChangeIsRememberedForNextCreate \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Snapzy/Features/Annotate/AnnotateState.swift
git commit -m "feat: persist watermark text across annotate sessions"
```

---

### Task 3: Remember style / opacity / rotation / font size on selection edits

**Files:**
- Modify: `Snapzy/Features/Annotate/AnnotateState.swift`

- [ ] **Step 1: Update `setActiveWatermarkStyle`**

Always update tool defaults (style + default rotation), even when selection is non-empty:

```swift
  func setActiveWatermarkStyle(_ style: WatermarkStyle) {
    let rotationDegrees = style.defaultRotationDegrees
    let watermarkAnnotations = selectedWatermarkAnnotations
    if !watermarkAnnotations.isEmpty {
      watermarkAnnotations.forEach {
        updateAnnotationProperties(
          id: $0.id,
          rotationDegrees: rotationDegrees,
          watermarkStyle: style
        )
      }
    }
    updateDefaultAnnotationProperties(
      for: .watermark,
      rotationDegrees: rotationDegrees,
      watermarkStyle: style
    )
    rememberWatermarkRotation(rotationDegrees)
  }
```

(`updateDefaultAnnotationProperties` already persists tool properties; `rememberWatermarkRotation` keeps shared rotation in sync with style switch.)

- [ ] **Step 2: Update opacity / rotation bindings**

In `quickWatermarkOpacityBinding` set, always remember after selection update:

```swift
        let didUpdate = self.updateQuickSelectionProperties(
          opacity: clampedOpacity,
          recordsUndo: true,
          matching: {
            if case .watermark = $0 { return true }
            return false
          }
        )
        self.rememberWatermarkOpacity(clampedOpacity)
        _ = didUpdate
```

Same pattern for `quickWatermarkRotationBinding` with `rememberWatermarkRotation`.

(Simplest: call remember unconditionally; remove the `if !update...` branch.)

- [ ] **Step 3: Update font size binding**

In `quickTextFontSizeBinding` set, always remember:

```swift
        let didUpdate = self.updateQuickSelectionProperties(
          fontSize: clampedSize,
          recordsUndo: true,
          matching: {
            switch $0 {
            case .text, .watermark:
              return true
            default:
              return false
            }
          }
        )
        self.rememberAnnotationFontSize(clampedSize, for: self.quickPropertiesTool)
        _ = didUpdate
```

Or call remember after the if/else regardless.

- [ ] **Step 4: Run watermark tests**

```bash
xcodebuild test -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug \
  -only-testing:SnapzyTests/AnnotateWatermarkTests \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: all PASS

- [ ] **Step 5: Run related core persistence regression**

```bash
xcodebuild test -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug \
  -only-testing:SnapzyTests/AnnotateCoreTests/testSharedParameterDefaultsPersistAcrossAnnotateStateInstances \
  -only-testing:SnapzyTests/AnnotateCoreTests/testQuickPropertiesSyncOffKeepsTextAndWatermarkFontDefaultsIndependent \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: PASS (sync-off font independence still holds for no-selection path)

- [ ] **Step 6: Commit**

```bash
git add Snapzy/Features/Annotate/AnnotateState.swift SnapzyTests/Features/Annotate/AnnotateWatermarkTests.swift
git commit -m "feat: remember watermark defaults when editing selected watermarks"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run full AnnotateWatermark + shared parameter suite**

```bash
xcodebuild test -project Snapzy.xcodeproj -scheme Snapzy -configuration Debug \
  -only-testing:SnapzyTests/AnnotateWatermarkTests \
  -only-testing:SnapzyTests/AnnotateCoreTests/testSharedParameterDefaultsPersistAcrossAnnotateStateInstances \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Expected: PASS

- [ ] **Step 2: Mark plan checkboxes done in this file**

---

## Spec coverage check

| Spec requirement | Task |
|------------------|------|
| Persist text | Task 2 |
| Empty text → Snapzy | Task 1–2 |
| Remember style/opacity/rotation with selection | Task 3 |
| Remember font size with selection | Task 3 |
| Color keep current | No change (already OK) |
| Cross-session via UserDefaults | Tasks 2–3 |
| Tests | Task 1, 4 |
