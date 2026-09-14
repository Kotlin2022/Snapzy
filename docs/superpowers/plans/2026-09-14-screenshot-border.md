# Screenshot Border Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional outward screenshot border (color / thickness / corner radius) configured in Capture → Screenshot and applied in `ScreenCaptureManager.saveImage` before write.

**Architecture:** Pure `ScreenshotBorderApplier` + `ScreenshotBorderSettings` reading UserDefaults; preferences UI in the screenshot pane; hook at the single save choke point.

**Tech Stack:** Swift, CoreGraphics, SwiftUI preferences, XCTest

**Spec:** `docs/superpowers/specs/2026-09-14-screenshot-border-design.md`

---

### Task 1: Applier + settings (TDD)

**Files:**
- Create: `Snapzy/Services/Capture/ScreenshotBorderSettings.swift`
- Create: `Snapzy/Services/Capture/ScreenshotBorderApplier.swift`
- Create: `SnapzyTests/Services/Capture/ScreenshotBorderApplierTests.swift`
- Modify: `Snapzy/Features/Preferences/Models/PreferencesKeys.swift`

- [ ] Add preference keys
- [ ] Write failing applier tests (identity when disabled; size expands when enabled)
- [ ] Implement settings + applier until green
- [ ] Commit

### Task 2: Wire into saveImage

**Files:**
- Modify: `Snapzy/Services/Capture/ScreenCaptureManager.swift`

- [ ] Before encoding in `saveImage`, apply `ScreenshotBorderApplier.applyIfNeeded`
- [ ] Use `scaleFactor` (fallback 2.0) to convert pt → px
- [ ] Commit

### Task 3: Preferences UI + localization

**Files:**
- Modify: `Snapzy/Features/Preferences/Components/PreferencesCaptureSettingsView.swift`
- Modify: `Snapzy/Shared/Localization/L10n.swift`
- Modify: `Snapzy/Resources/Localization/Features/Capture.xcstrings`

- [ ] Section under Capture → Screenshot: toggle, color picker, width slider, corner radius slider
- [ ] L10n strings (en + zh-Hans/zh-Hant + other locales mirroring pattern)
- [ ] Commit

### Task 4: Verify

- [ ] Run `ScreenshotBorderApplierTests`
- [ ] Smoke: build succeeds
